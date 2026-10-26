#' Rank spectral features by their temporal contrast across field borders
#'
#' For pixel pairs centred on reference field boundaries (across pairs: the two ends lie
#' in different fields) and inside fields (within pairs), every candidate feature is
#' summarised by the temporal maximum and mean, over dates clear at both ends, of
#' `log(|f(p) - f(q)| + 1e-4)`. Features are ranked by the area under the ROC curve (AUC)
#' with which the temporal maximum separates across from within pairs, averaged over
#' strata. This extends the class-separability screening of spectral indices (as in the
#' `svid` package) from classes to field borders.
#'
#' @param stacks An `fb_stack` or a list of them (training tiles). For many tiles, list
#'   elements may be functions without arguments that return the stack; each tile is then
#'   loaded only while it is processed.
#' @param references A reference raster from [fb_reference()] or a list of them, one per
#'   stack (or functions returning them).
#' @param features Candidate features from [fb_feature_set()]; by default the bands and
#'   all normalised differences of the first stack's bands.
#' @param strata Optional stratum label per stack; the AUC is averaged over strata.
#' @param n_pairs Maximum number of across and of within pairs per stack.
#' @param seed Random seed for pair sampling.
#' @return An object of class `fb_contrast` with `ranking` (data frame of features with
#'   their AUC, by stratum and averaged) and the pair summaries used by [fb_train()].
#' @examples
#' s <- fb_example_stack("california")
#' f <- fb_example_files("california")
#' ref <- fb_reference(sf::st_read(f$fields, quiet = TRUE), s)
#' rk <- fb_rank_contrast(s, ref, n_pairs = 1000)
#' head(rk$ranking)
#' fb_plot_ranking(rk, n = 15)
#' @export
fb_rank_contrast <- function(stacks, references, features = NULL, strata = NULL, n_pairs = 4000L, seed = 1L) {
  if (inherits(stacks, "fb_stack")) stacks <- list(stacks)
  if (inherits(references, "SpatRaster")) references <- list(references)
  if (length(stacks) != length(references)) stop("one reference raster per stack is needed")
  if (is.null(strata)) strata <- rep("all", length(stacks))
  if (is.null(features)) features <- fb_feature_set(get_item(stacks[[1]])$bands)
  K <- nrow(features)
  rows <- lapply(seq_along(stacks), function(i) {
    s <- get_item(stacks[[i]])
    if (!all(all.vars(str2lang(paste(features$expr, collapse = "+"))) %in% s$bands)) stop("stack ", i, " lacks bands used by the features")
    rv <- reference_values(get_item(references[[i]]))
    pr <- sample_pairs(rv$cls, rv$inst, terra::nrow(s$data), terra::ncol(s$data), n_pairs, seed + i - 1L)
    if (!nrow(pr)) return(NULL)
    uc <- sort(unique(c(pr[, "p"], pr[, "q"])))
    blk <- stack_block(s, cells = uc)                       # only the cells of the sampled pairs
    rm(s, rv)
    ip <- match(pr[, "p"], uc); iq <- match(pr[, "q"], uc)
    n <- nrow(pr)
    tmax <- matrix(-Inf, n, K)
    tsum <- matrix(0, n, K)
    cnt <- integer(n)
    for (m in seq_len(blk$M)) {
      Fm <- feature_matrix(features, blk$X, m, blk$bands, c(ip, iq))
      ok <- blk$C[ip, m] & blk$C[iq, m]
      ld <- log(abs(Fm[seq_len(n), , drop = FALSE] - Fm[n + seq_len(n), , drop = FALSE]) + 1e-4)
      ld[!ok, ] <- NA_real_
      tmax <- pmax(tmax, ifelse(is.na(ld), -Inf, ld))
      tsum <- tsum + ifelse(is.na(ld), 0, ld)
      cnt <- cnt + ok
    }
    tmax[cnt == 0L, ] <- NA_real_
    tmean <- tsum / pmax(cnt, 1L)
    tmean[cnt == 0L, ] <- NA_real_
    rm(blk); gc(verbose = FALSE)
    list(y = pr[, "y"], stratum = rep(strata[i], n), tmax = tmax, tmean = tmean)
  })
  rows <- Filter(Negate(is.null), rows)
  y <- unlist(lapply(rows, `[[`, "y"))
  st <- unlist(lapply(rows, `[[`, "stratum"))
  # bind the per-tile summaries, releasing each part once copied (large training sets)
  TMAX <- do.call(rbind, lapply(rows, `[[`, "tmax"))
  for (i in seq_along(rows)) rows[[i]]$tmax <- NULL
  TMEAN <- do.call(rbind, lapply(rows, `[[`, "tmean"))
  rm(rows)
  colnames(TMAX) <- colnames(TMEAN) <- features$name
  au <- sapply(sort(unique(st)), function(s0) {
    m <- which(st == s0)
    if (length(unique(y[m])) < 2) return(rep(NA_real_, K))
    vapply(seq_len(K), function(j) fb_auc(TMAX[m, j], y[m]), 0)
  })
  au <- matrix(au, nrow = K)
  colnames(au) <- paste0("auc_", sort(unique(st)))
  ranking <- data.frame(feature = features$name, type = features$type, auc = rowMeans(au, na.rm = TRUE), au,
                        check.names = FALSE)
  ord <- order(-ranking$auc)
  ranking <- ranking[ord, , drop = FALSE]
  rownames(ranking) <- NULL
  structure(list(ranking = ranking, features = features, y = y, stratum = st, tmax = TMAX, tmean = TMEAN),
            class = "fb_contrast")
}

#' @export
print.fb_contrast <- function(x, n = 10, ...) {
  cat("<fb_contrast>", length(x$y), "pairs (", sum(x$y), "across ),", nrow(x$features), "features,",
      length(unique(x$stratum)), "strata\n")
  print(utils::head(x$ranking[, c("feature", "type", "auc")], n), row.names = FALSE, digits = 3)
  invisible(x)
}

#' Select features from a contrast ranking
#'
#' Walks down the ranking and keeps a feature unless the absolute Spearman correlation of
#' its temporal maximum with an already selected feature exceeds `max_cor`.
#'
#' @param contrast An `fb_contrast` object from [fb_rank_contrast()].
#' @param k Number of features to select.
#' @param max_cor Maximum absolute Spearman correlation between selected features.
#' @param n_sub Number of pairs used for the correlations.
#' @param seed Random seed for the subsample.
#' @return Character vector of selected feature names, in rank order.
#' @examples
#' s <- fb_example_stack("california")
#' f <- fb_example_files("california")
#' ref <- fb_reference(sf::st_read(f$fields, quiet = TRUE), s)
#' rk <- fb_rank_contrast(s, ref, n_pairs = 1000)
#' fb_select_features(rk, k = 5)
#' @export
fb_select_features <- function(contrast, k = 8L, max_cor = 0.9, n_sub = 100000L, seed = 1L) {
  stopifnot(inherits(contrast, "fb_contrast"))
  set.seed(seed)
  sub <- if (length(contrast$y) > n_sub) sample.int(length(contrast$y), n_sub) else seq_along(contrast$y)
  R <- apply(contrast$tmax[sub, , drop = FALSE], 2, rank, na.last = "keep")
  chosen <- character()
  for (f in contrast$ranking$feature) {
    if (length(chosen) == k) break
    if (!is.finite(contrast$ranking$auc[contrast$ranking$feature == f])) next
    ok <- TRUE
    for (c0 in chosen) {
      r <- suppressWarnings(stats::cor(R[, f], R[, c0], use = "complete.obs"))
      if (is.finite(r) && abs(r) > max_cor) { ok <- FALSE; break }
    }
    if (ok) chosen <- c(chosen, f)
  }
  chosen
}

#' Train a temporal boundary contrast (TBC) model
#'
#' Fits the two components of TBC on training tiles with reference fields:
#' * the edge model, a logistic regression of across versus within pairs on the temporal
#'   maximum and mean contrasts of the `k` selected features (standardised; missing
#'   summaries set to the training mean);
#' * the cropland model, gradient-boosted trees (`xgboost`), a probability random forest
#'   (`ranger`) or a logistic regression of field-interior versus background pixels on the
#'   10th, 50th and 90th percentiles and the standard deviation over clear dates of the
#'   bands, NDVI, ND(B08,B11) and ND(B11,B12).
#'
#' The logistic regressions carry a ridge penalty of 1 on the slopes (the default of
#' scikit-learn's `LogisticRegression`), which keeps them finite when the classes are
#' separable.
#'
#' @inheritParams fb_rank_contrast
#' @param contrast Optional result of [fb_rank_contrast()] on the same data (avoids
#'   recomputing the pair summaries).
#' @param k,max_cor Feature selection settings passed to [fb_select_features()].
#' @param n_pixels Maximum number of field and of background pixels per stack for the
#'   cropland model.
#' @param learner Cropland learner: `"xgboost"` (gradient-boosted trees, default, as in the
#'   validation of the method), `"ranger"` (random forest) or `"glm"` (ridge logistic
#'   regression).
#' @param num_trees Number of trees (random forest) or boosting rounds (`xgboost`).
#' @param min_node_size Minimum node size of the random forest; larger values give
#'   smaller models.
#' @param thresholds Default object thresholds stored with the model (see
#'   [fb_delineate()]); tune them with [fb_tune()].
#' @param threads Number of threads for the cropland learner.
#' @return An object of class `fb_model`.
#' @examples
#' s <- fb_example_stack("california")
#' f <- fb_example_files("california")
#' ref <- fb_reference(sf::st_read(f$fields, quiet = TRUE), s)
#' m <- fb_train(s, ref, n_pairs = 1000, n_pixels = 2000, num_trees = 50)
#' m
#' @export
fb_train <- function(stacks, references, features = NULL, strata = NULL, contrast = NULL, k = 8L, max_cor = 0.9,
                     n_pairs = 4000L, n_pixels = 20000L, learner = c("xgboost", "ranger", "glm"), num_trees = 100L,
                     min_node_size = 10L,
                     thresholds = list(t_edge = 0.5, t_field = 0.5, min_size = 50L), seed = 1L, threads = 1L) {
  learner <- match.arg(learner)
  if (inherits(stacks, "fb_stack")) stacks <- list(stacks)
  if (inherits(references, "SpatRaster")) references <- list(references)
  if (is.null(contrast)) contrast <- fb_rank_contrast(stacks, references, features, strata, n_pairs, seed)
  sel <- fb_select_features(contrast, k, max_cor, seed = seed)
  Z <- cbind(contrast$tmax[, sel, drop = FALSE], contrast$tmean[, sel, drop = FALSE])
  mu <- colMeans(Z, na.rm = TRUE)
  for (j in seq_len(ncol(Z))) Z[is.na(Z[, j]), j] <- mu[j]
  sdv <- sqrt(colMeans(sweep(Z, 2, colMeans(Z))^2)) + 1e-12
  Zs <- sweep(sweep(Z, 2, mu), 2, sdv, "/")
  beta <- logistic_ridge(Zs, contrast$y)
  edge_auc <- fb_auc(drop(cbind(1, Zs) %*% beta), contrast$y)
  rm(Z, Zs)

  bands <- get_item(stacks[[1]])$bands
  vars <- cropland_variables(bands)
  pix <- lapply(seq_along(stacks), function(i) {
    rv <- reference_values(get_item(references[[i]]))
    sp <- sample_pixels(rv$cls, n_pixels, seed + i - 1L)
    if (!length(sp$cell)) return(NULL)
    blk <- stack_block(get_item(stacks[[i]]), cells = sp$cell)   # only the sampled cells
    x <- cropland_features(vars, blk)
    rm(blk); gc(verbose = FALSE)
    list(x = x, y = sp$y)
  })
  pix <- Filter(Negate(is.null), pix)
  XP <- do.call(rbind, lapply(pix, `[[`, "x"))
  YP <- unlist(lapply(pix, `[[`, "y"))
  rm(pix); gc(verbose = FALSE)
  crop <- fit_cropland(XP, YP, learner, num_trees, seed, threads, min_node_size)
  structure(list(
    bands = bands,
    features = contrast$features[match(sel, contrast$features$name), c("name", "expr", "type")],
    edge = list(beta = beta[-1], intercept = beta[1], mu = unname(mu), sd = unname(sdv)),
    cropland = crop, cropland_variables = vars,
    thresholds = thresholds,
    ranking = contrast$ranking,
    training = list(stacks = length(stacks), pairs = length(contrast$y), across = sum(contrast$y),
                    pixels = length(YP), field_pixels = sum(YP), edge_auc_in_sample = edge_auc,
                    cropland_auc_in_sample = fb_auc(predict_cropland(crop, XP, threads), YP)),
    version = as.character(utils::packageVersion("fieldborders"))
  ), class = "fb_model")
}

get_item <- function(x) if (is.function(x)) x() else x

fit_cropland <- function(X, y, learner, num_trees, seed, threads = 1L, min_node_size = 10L) {
  mu <- colMeans(X, na.rm = TRUE)
  for (j in which(colSums(!is.finite(X)) > 0)) X[!is.finite(X[, j]), j] <- mu[j]   # only columns with gaps
  if (learner == "ranger") {
    d <- data.frame(X, check.names = FALSE)
    d$.y <- factor(y, levels = c(0, 1))
    m <- ranger::ranger(dependent.variable.name = ".y", data = d, num.trees = num_trees, probability = TRUE,
                        min.node.size = min_node_size, seed = seed, num.threads = threads, write.forest = TRUE)
    list(learner = "ranger", model = m, mu = mu, names = colnames(X))
  } else if (learner == "xgboost") {
    # gradient-boosted trees grown leaf-wise (at most 31 leaves, learning rate 0.1), as the
    # histogram gradient boosting of the validation pipeline
    d <- xgboost::xgb.DMatrix(X, label = y, nthread = threads)
    params <- list(objective = "binary:logistic", eta = 0.1, max_depth = 0L, max_leaves = 31L,
                   grow_policy = "lossguide", tree_method = "hist", nthread = threads, seed = seed)
    m <- xgboost::xgb.train(params = params, data = d, nrounds = num_trees, verbose = 0)
    list(learner = "xgboost", model = xgboost::xgb.save.raw(m), mu = mu, names = colnames(X))
  } else {
    sdv <- apply(X, 2, stats::sd) + 1e-12
    Xs <- sweep(sweep(X, 2, mu), 2, sdv, "/")
    list(learner = "glm", beta = logistic_ridge(Xs, y), mu = mu, sd = sdv, names = colnames(X))
  }
}

predict_cropland <- function(crop, X, threads = 1L) {
  for (j in which(colSums(!is.finite(X)) > 0)) X[!is.finite(X[, j]), j] <- crop$mu[j]
  if (crop$learner == "ranger") {
    d <- data.frame(X, check.names = FALSE)
    names(d) <- crop$names
    stats::predict(crop$model, d, num.threads = threads)$predictions[, "1"]
  } else if (crop$learner == "xgboost") {
    b <- xgboost::xgb.load.raw(crop$model)
    b <- xgboost::`xgb.model.parameters<-`(b, list(nthread = threads))
    colnames(X) <- crop$names
    stats::predict(b, X)
  } else {
    Xs <- sweep(sweep(X, 2, crop$mu), 2, crop$sd, "/")
    stats::plogis(drop(cbind(1, Xs) %*% crop$beta))
  }
}

#' @export
print.fb_model <- function(x, ...) {
  cat("<fb_model> temporal boundary contrast\n")
  cat("  bands            :", paste(x$bands, collapse = ", "), "\n")
  cat("  edge features    :", paste(x$features$name, collapse = " | "), "\n")
  cat("  cropland learner :", x$cropland$learner, "\n")
  tr <- x$training
  if (!is.null(tr$pairs)) {
    cat(sprintf("  training         : %s tiles, %s pairs (%s across), %s pixels\n", tr$stacks,
                format(tr$pairs, big.mark = ","), format(tr$across, big.mark = ","), format(tr$pixels, big.mark = ",")))
    cat(sprintf("  in-sample AUC    : edge %.3f, cropland %.3f\n", tr$edge_auc_in_sample, tr$cropland_auc_in_sample))
  }
  th <- x$thresholds
  cat(sprintf("  thresholds       : t_edge %.2f, t_field %.2f, min_size %d pixels\n", th$t_edge, th$t_field, as.integer(th$min_size)))
  invisible(x)
}

#' Edge and cropland maps from a TBC model
#'
#' Computes, for every pixel, the edge probability (the maximum over four directions of
#' the edge-model probability of the pixel pair centred on it) and the cropland
#' probability. Large rasters are processed in blocks of rows.
#'
#' @param stack An `fb_stack` holding the bands of the model.
#' @param model An `fb_model` from [fb_train()] or [fb_model_pretrained()].
#' @param filename Optional output GeoTIFF.
#' @param block_cells Approximate number of cells per processing block.
#' @param threads Number of threads for the cropland model.
#' @return A `SpatRaster` with layers `edge` and `cropland`.
#' @examples
#' s <- fb_example_stack("california")
#' maps <- fb_tbc_maps(s, fb_model_pretrained("california"))
#' fb_plot_maps(maps)
#' @export
fb_tbc_maps <- function(stack, model, filename = "", block_cells = 100000L, threads = 1L) {
  stopifnot(inherits(stack, "fb_stack"), inherits(model, "fb_model"))
  miss <- setdiff(model$bands, stack$bands)
  if (length(miss)) stop("the stack lacks bands used by the model: ", paste(miss, collapse = ", "))
  g <- stack$data[[1]]
  nr <- terra::nrow(g); nc <- terra::ncol(g)
  step <- max(8L, floor(block_cells / nc))
  E <- numeric(nr * nc); Fp <- numeric(nr * nc)
  K <- nrow(model$features)
  for (r0 in seq(1L, nr, by = step)) {
    r1 <- min(nr, r0 + step - 1L)
    a <- max(1L, r0 - 1L); b <- min(nr, r1 + 1L)
    blk <- stack_block(stack, a, b - a + 1L)
    Fm <- do.call(cbind, lapply(seq_len(blk$M), function(m) feature_matrix(model$features, blk$X, m, blk$bands)))
    e <- .edge_map_cpp(t(Fm), t(blk$C), blk$nrow, nc, K, model$edge$beta, model$edge$intercept, model$edge$mu,
                       model$edge$sd, 1e-4)
    keep <- ((r0 - a) * nc + 1L):((r1 - a + 1L) * nc)
    out <- ((r0 - 1L) * nc + 1L):(r1 * nc)
    E[out] <- e[keep]
    cf <- cropland_features(model$cropland_variables, blk, keep)
    Fp[out] <- predict_cropland(model$cropland, cf, threads)
  }
  r <- terra::rast(g, nlyrs = 2)
  terra::values(r) <- cbind(E, Fp)
  names(r) <- c("edge", "cropland")
  if (nzchar(filename)) r <- terra::writeRaster(r, filename, overwrite = TRUE)
  r
}

#' Save and load a model
#'
#' @param model An `fb_model` or `fb_fusion` object.
#' @param file Path of the `.rds` file.
#' @return `fb_save_model()` returns the file path invisibly; `fb_load_model()` the model.
#' @examples
#' m <- fb_model_pretrained("california")
#' f <- tempfile(fileext = ".rds")
#' fb_save_model(m, f)
#' fb_load_model(f)
#' @export
fb_save_model <- function(model, file) {
  saveRDS(model, file, compress = "xz")
  invisible(file)
}

#' @rdname fb_save_model
#' @export
fb_load_model <- function(file) {
  m <- readRDS(file)
  if (!inherits(m, c("fb_model", "fb_fusion"))) stop("not a fieldborders model")
  m
}
