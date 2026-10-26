# Pretrained models of the package (inst/models) and verification of the R implementation.
# Models are fitted with fb_train() and fb_fit_fusion() on the fit tiles of the validation regions,
# thresholds are tuned with fb_tune() on the tune tiles, and the California models are evaluated
# once on the California test tiles to compare the R implementation with the validation pipeline.
# Run from the project root:  Rscript release/fieldborders/data-raw/pretrained.R <step>
#   step: california | general | ftw | verify
suppressPackageStartupMessages({ library(terra); library(data.table) })
library(fieldborders)
source("release/fieldborders/data-raw/npz.R")
args <- commandArgs(trailingOnly = TRUE)
step <- args[1]
work <- "data/derived/package_models"
models_dir <- "release/fieldborders/inst/models"
dir.create(work, recursive = TRUE, showWarnings = FALSE)
dir.create(models_dir, recursive = TRUE, showWarnings = FALSE)
roots <- c(ca = "data/derived/phase1c", wa = "data/derived/phase1d/wa")
prue_dir <- c(ca = "data/derived/phase1c/prue_b3/m03_m07")
grid <- list(t_edge = c(0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8), t_field = c(0.3, 0.5, 0.7, 0.9),
             min_size = c(0, 50, 100, 200, 400))
seed <- 20261027L
log_line <- function(...) cat(format(Sys.time(), "%H:%M:%S"), ..., "\n")

index <- function(region) fread(file.path(roots[[region]], "tile_index.csv"))
stack_of <- function(region, r) npz_stack(file.path(roots[[region]], "s2", paste0(r$tile_id, ".npz")), r$west, r$south, r$east, r$north)
ref_of <- function(region, id) {
  r <- rast(file.path(roots[[region]], "tiles", id, c("label_sem.tif", "label_inst.tif")))
  names(r) <- c("class", "field_id")
  r
}

# TBC maps of a model for a set of tiles, cached as GeoTIFFs
maps_for <- function(model, tag, region, ids) {
  d <- file.path(work, "maps", tag); dir.create(d, recursive = TRUE, showWarnings = FALSE)
  ix <- index(region)
  lapply(ids, function(id) {
    f <- file.path(d, paste0(id, ".tif"))
    if (!file.exists(f)) fb_tbc_maps(stack_of(region, ix[tile_id == id]), model, filename = f, threads = 2L)
    rast(f)
  })
}

fit_tbc <- function(regions, tag, learner, n_pixels, num_trees, min_node_size = 10L) {
  f <- file.path(work, paste0(tag, "_tbc_", learner, ".rds"))
  if (file.exists(f)) return(readRDS(f))
  st <- list(); rf <- list(); strata <- character()
  for (rg in regions) {
    ix <- index(rg)[split == "fit"]
    for (k in seq_len(nrow(ix))) {
      st[[length(st) + 1]] <- local({ rg <- rg; r <- ix[k]; function() stack_of(rg, r) })      # loaded when used
      rf[[length(rf) + 1]] <- local({ rg <- rg; id <- ix$tile_id[k]; function() ref_of(rg, id) })
      strata <- c(strata, ix$stratum[k])
    }
  }
  # the feature ranking does not depend on the cropland learner: computed once per model and reused
  fc <- file.path(work, paste0(tag, "_contrast.rds"))
  if (file.exists(fc)) ctr <- readRDS(fc) else {
    ctr <- fb_rank_contrast(st, rf, strata = strata, n_pairs = 4000L, seed = seed)
    saveRDS(ctr, fc)
  }
  log_line(tag, "training on", length(st), "tiles with", learner)
  m <- fb_train(st, rf, strata = strata, contrast = ctr, n_pairs = 4000L, n_pixels = n_pixels, learner = learner,
                num_trees = num_trees, min_node_size = min_node_size, seed = seed, threads = 2L)
  saveRDS(m, f)
  m
}

tune_maps <- function(maps, regions_ids) {
  refs <- unlist(lapply(names(regions_ids), function(rg) lapply(regions_ids[[rg]], function(id) ref_of(rg, id))), recursive = FALSE)
  fb_tune(maps, refs, grid$t_edge, grid$t_field, grid$min_size)
}

# tuned thresholds, with the minimum size also as an area (mean cell area of the tune tiles), so
# that it keeps its meaning on grids of another pixel size
thresholds_of <- function(best, maps) {
  cell <- mean(vapply(maps, function(r) mean(values(cellSize(r[[1]], unit = "m"), mat = FALSE)), 0))
  list(t_edge = best$t_edge, t_field = best$t_field, min_size = as.integer(best$min_size),
       min_area = round(best$min_size * cell))
}

if (step %in% c("california", "general")) {
  regions <- if (step == "california") "ca" else c("ca", "wa")
  tune_ids <- setNames(lapply(regions, function(rg) index(rg)[split == "tune", tile_id]), regions)
  res <- list()
  # cropland learners: ridge logistic regression on up to 5000 pixels per class and tile; a random
  # forest of 100 trees (minimum node size 25) on up to 2000, which keeps the saved model small; and
  # gradient-boosted trees (100 rounds, as the validation pipeline) on up to 10000
  cfg <- list(glm = list(n_pixels = 5000L, num_trees = 100L, min_node_size = 25L),
              ranger = list(n_pixels = 2000L, num_trees = 100L, min_node_size = 25L),
              xgboost = list(n_pixels = 10000L, num_trees = 100L, min_node_size = 25L))
  for (learner in c("glm", "ranger", "xgboost")) {
    m <- fit_tbc(regions, step, learner, n_pixels = cfg[[learner]]$n_pixels, num_trees = cfg[[learner]]$num_trees,
                 min_node_size = cfg[[learner]]$min_node_size)
    mp <- unlist(lapply(regions, function(rg) maps_for(m, paste(step, learner, sep = "_"), rg, tune_ids[[rg]])), recursive = FALSE)
    tn <- tune_maps(mp, tune_ids)
    fwrite(tn, file.path(work, sprintf("%s_tune_%s.csv", step, learner)))
    res[[learner]] <- list(model = m, best = tn[1, ])
    f <- tempfile(fileext = ".rds"); saveRDS(m, f, compress = "xz"); mb <- file.size(f) / 2^20
    res[[learner]]$size_mb <- mb
    log_line(step, learner, "tune F1", round(tn$f1[1], 4), "saved size MB", round(mb, 1))
  }
  # a learner is eligible if its saved model is at most 25 MB (logs/package_models.md)
  ok <- vapply(res, function(x) x$size_mb <= 25, TRUE)
  learner <- names(res)[ok][which.max(vapply(res[ok], function(x) x$best$f1, 0))]
  m <- res[[learner]]$model
  b <- res[[learner]]$best
  mp_best <- unlist(lapply(regions, function(rg) maps_for(m, paste(step, learner, sep = "_"), rg, tune_ids[[rg]])), recursive = FALSE)
  m$thresholds <- thresholds_of(b, mp_best)
  m$tuning <- list(tiles = sum(lengths(tune_ids)), f1 = b$f1, learner_tune_f1 = vapply(res, function(x) x$best$f1, 0),
                   grid = "Fields of The World chip grid, 0.000054054 degrees (about 5 m)")
  name <- if (step == "california") "california" else "general"
  fb_save_model(m, file.path(models_dir, paste0(name, "_tbc.rds")))
  log_line(step, "chosen learner", learner)
  # fusion with PRUE B3
  if (step == "general") prue_dir[["wa"]] <- file.path("data/derived/phase1d/wa/prue_b3",
                                                         sprintf("m%02d_m%02d", 3, 7))
  fit_ids <- setNames(lapply(regions, function(rg) index(rg)[split == "fit", tile_id]), regions)
  tm <- unlist(lapply(regions, function(rg) maps_for(m, paste(step, learner, sep = "_"), rg, fit_ids[[rg]])), recursive = FALSE)
  dl <- unlist(lapply(regions, function(rg) lapply(fit_ids[[rg]], function(id) fb_read_probabilities(file.path(prue_dir[[rg]], paste0(id, ".tif"))))), recursive = FALSE)
  rf <- unlist(lapply(regions, function(rg) lapply(fit_ids[[rg]], function(id) ref_of(rg, id))), recursive = FALSE)
  fu <- fb_fit_fusion(tm, dl, rf, seed = seed)
  tmt <- unlist(lapply(regions, function(rg) maps_for(m, paste(step, learner, sep = "_"), rg, tune_ids[[rg]])), recursive = FALSE)
  dlt <- unlist(lapply(regions, function(rg) lapply(tune_ids[[rg]], function(id) fb_read_probabilities(file.path(prue_dir[[rg]], paste0(id, ".tif"))))), recursive = FALSE)
  fused <- Map(function(a, b) fb_fuse(a, b, fu), tmt, dlt)
  tn <- tune_maps(fused, tune_ids)
  fwrite(tn, file.path(work, sprintf("%s_tune_fusion.csv", step)))
  fu$thresholds <- thresholds_of(tn[1, ], fused)
  fu$tuning <- list(tiles = sum(lengths(tune_ids)), f1 = tn$f1[1], prue_months = c(3L, 7L),
                    grid = "Fields of The World chip grid, 0.000054054 degrees (about 5 m)")
  fb_save_model(fu, file.path(models_dir, paste0(name, "_fusion.rds")))
  log_line(step, "fusion tune F1", round(tn$f1[1], 4))
}

if (step == "verify") {
  # test tiles of California and Washington (never used to fit or tune the models): the pretrained
  # models of the package, TBC alone and fused with PRUE B3 (months 3 and 7)
  prue_dir[["wa"]] <- "data/derived/phase1d/wa/prue_b3/m03_m07"
  runs <- list(list(model = "california", region = "ca"), list(model = "general", region = "ca"),
               list(model = "general", region = "wa"))
  out <- rbindlist(lapply(runs, function(rn) {
    m <- fb_model_pretrained(rn$model); fu <- fb_model_pretrained(rn$model, "fusion")
    ix <- index(rn$region)[split == "test"]
    mp <- maps_for(m, paste(rn$model, m$cropland$learner, sep = "_"), rn$region, ix$tile_id)
    rbindlist(lapply(seq_len(nrow(ix)), function(k) {
      id <- ix$tile_id[k]; ref <- ref_of(rn$region, id)
      dl <- fb_read_probabilities(file.path(prue_dir[[rn$region]], paste0(id, ".tif")))
      rbind(data.table(model = rn$model, region = rn$region, tile = id, stratum = ix$stratum[k], method = "TBC",
                       fb_evaluate(ref, fb_delineate(mp[[k]], thresholds = m$thresholds))),
            data.table(model = rn$model, region = rn$region, tile = id, stratum = ix$stratum[k], method = "TBC + PRUE B3",
                       fb_evaluate(ref, fb_delineate(fb_fuse(mp[[k]], dl, fu), thresholds = fu$thresholds))))
    }))
  }))
  fwrite(out, file.path(work, "verify_test_counts.csv"))
  acc <- as.data.table(fb_accuracy(out[, !c("tile", "stratum")], by = c("model", "region", "method")))
  # percentile bootstrap interval of object F1 (tiles resampled within strata, B = 2000)
  ci <- rbindlist(lapply(split(out, by = c("model", "region", "method")), function(d) {
    set.seed(seed)
    st <- split(seq_len(nrow(d)), d$stratum)
    f1 <- function(i) { s <- colSums(d[i, .(obj_tp, obj_fp, obj_fn)]); 2 * s[1] / (2 * s[1] + s[2] + s[3]) }
    b <- replicate(2000L, f1(unlist(lapply(st, function(i) i[sample.int(length(i), length(i), TRUE)]))))
    data.table(model = d$model[1], region = d$region[1], method = d$method[1],
               f1_lo = quantile(b, 0.025, names = FALSE), f1_hi = quantile(b, 0.975, names = FALSE))
  }))
  acc <- merge(acc, ci, by = c("model", "region", "method"))
  fwrite(acc, file.path(work, "verify_test_accuracy.csv"))
  print(acc[, .(model, region, method, tiles, reference_fields, obj_precision, obj_recall, obj_f1, f1_lo, f1_hi)])
}

if (step == "ftw") {
  sel <- fread("data/derived/phase1b_s2/selected_chips.csv", colClasses = list(character = "aoi_id"))
  chip_ref <- function(lf) { ref <- rast(lf); ref <- ifel(is.na(ref), 0, ref); names(ref) <- c("class", "field_id"); ref }
  # FTW chips are stored south-up; terra returns rows north-up, so the arrays (file order) are flipped
  chip_stack <- function(f, lf) {
    g <- rast(lf[1])
    z <- read_npz(f, reversed = TRUE)
    W <- dim(z$data)[1]; H <- dim(z$data)[2]; B <- dim(z$data)[3]; M <- dim(z$data)[4]
    r <- rast(g, nlyrs = M * B); values(r) <- matrix(as.numeric(z$data[, H:1, , , drop = FALSE]), H * W, M * B)
    cl <- rast(g, nlyrs = M); values(cl) <- matrix(as.integer(z$clear[, H:1, , drop = FALSE]), H * W, M)
    fb_stack(r, as.Date(z$dates), c("B04", "B03", "B02", "B08"), cl, 10000)
  }
  st <- list(); rf <- list(); strata <- character()
  for (k in seq_len(nrow(sel))) {
    f <- file.path("data/derived/phase1b_s2", sprintf("%s_%s.npz", sel$country[k], sel$aoi_id[k]))
    lf <- file.path("data/raw/ftw", sel$country[k], "label_masks", c("semantic_3class", "instance"), paste0(sel$aoi_id[k], ".tif"))
    if (!file.exists(f) || !all(file.exists(lf))) next
    st[[length(st) + 1]] <- local({ f <- f; lf <- lf; function() chip_stack(f, lf) })   # loaded when used
    rf[[length(rf) + 1]] <- local({ lf <- lf; function() chip_ref(lf) })
    strata <- c(strata, sel$country[k])
  }
  log_line("ftw chips", length(st))
  m <- fb_train(st, rf, strata = strata, n_pairs = 1000L, n_pixels = 5000L, learner = "xgboost", num_trees = 100L,
                seed = seed, threads = 2L)
  regions <- c("ca", "wa")
  tune_ids <- setNames(lapply(regions, function(rg) index(rg)[split == "tune", tile_id]), regions)
  mp <- unlist(lapply(regions, function(rg) maps_for(m, "ftw_xgboost", rg, tune_ids[[rg]])), recursive = FALSE)
  tn <- tune_maps(mp, tune_ids)
  fwrite(tn, file.path(work, "ftw_tune.csv"))
  m$thresholds <- thresholds_of(tn[1, ], mp)
  m$tuning <- list(tiles = sum(lengths(tune_ids)), f1 = tn$f1[1],
                   grid = "Fields of The World chip grid, 0.000054054 degrees (about 5 m)")
  fb_save_model(m, file.path(models_dir, "ftw_tbc.rds"))
  log_line("ftw tune F1", round(tn$f1[1], 4))
}
