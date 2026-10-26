# Example data of the package (inst/extdata): windows of validation and demonstration tiles with
# their monthly Sentinel-2 scenes and clear masks, PRUE B3 probabilities computed from the window
# with fb_prue_predict(), reference fields where their licence allows redistribution (California)
# and the FTW global field map of the imagery year. Run from the project root:
#   Rscript release/fieldborders/data-raw/examples.R [name ...]
suppressPackageStartupMessages({ library(terra); library(sf); library(data.table) })
library(fieldborders)
source("release/fieldborders/data-raw/npz.R")
out_root <- "release/fieldborders/inst/extdata"
py <- Sys.getenv("FB_PYTHON", "python")   # Python with pyarrow, shapely and fsspec
prue_model <- "data/derived/prue_b3_ccby_torchscript.pt"

# tiles: one tile, or candidate test tiles of a stratum searched for the best window
examples <- list(
  california = list(root = "data/derived/phase1c", tiles = "ca_-4407_1410", size = 192L, months = c(3L, 7L)),
  washington = list(root = "data/derived/phase1d/wa", stratum = "columbia_basin", size = 192L, months = c(3L, 7L)),
  brazil = list(root = "data/derived/phase1d/br", stratum = "tocantins_summer", size = 192L, months = c(9L, 1L),
                criterion = "partial"),     # fields larger than the window: count fields with >= 1500 pixels inside
  moghan = list(root = "data/derived/iran", tiles = "ir_moghan", size = 160L, months = c(3L, 7L), centre = TRUE)
)
selected <- commandArgs(trailingOnly = TRUE)
if (!length(selected)) selected <- names(examples)

# number of reference fields lying entirely inside a window (upper-left cell r, c), or, with
# criterion "partial", number of fields with at least 1500 pixels inside the window
window_fields <- function(inst, r, c, size, criterion = "complete") {
  w <- inst[r:(r + size - 1L), c:(c + size - 1L)]
  if (criterion == "partial") return(sum(tabulate(w[w > 0]) >= 1500L))
  length(setdiff(unique(w[w > 0]), unique(c(w[1, ], w[size, ], w[, 1], w[, size]))))
}

# best window (most complete reference fields) over the candidate tiles, 32-pixel steps
choose_window <- function(root, tiles, size, criterion = "complete") {
  best <- list(n = -1)
  for (id in tiles) {
    r <- rast(file.path(root, "tiles", id, "label_inst.tif"))
    inst <- matrix(values(r, mat = FALSE), nrow(r), ncol(r), byrow = TRUE)
    inst[is.na(inst)] <- 0L
    for (rr in seq(1L, nrow(inst) - size + 1L, by = 32L)) for (cc in seq(1L, ncol(inst) - size + 1L, by = 32L)) {
      k <- window_fields(inst, rr, cc, size, criterion)
      if (k > best$n) best <- list(n = k, tile = id, r = rr, c = cc)
    }
  }
  best
}

window_ext <- function(g, r0, c0, size) {
  rs <- res(g)
  x0 <- xmin(g) + (c0 - 1) * rs[1]; y1 <- ymax(g) - (r0 - 1) * rs[2]
  ext(x0, x0 + size * rs[1], y1 - size * rs[2], y1)
}

wins <- list()
for (nm in selected) {
  ex <- examples[[nm]]
  ix <- fread(file.path(ex$root, "tile_index.csv"))
  if (isTRUE(ex$centre)) {
    sel <- list(tile = ex$tiles, r = (512L - ex$size) %/% 2L + 1L, c = (512L - ex$size) %/% 2L + 1L, n = NA)
  } else {
    cand <- if (!is.null(ex$tiles)) ex$tiles else ix[stratum == ex$stratum & split == "test", tile_id]
    sel <- choose_window(ex$root, cand, ex$size, if (is.null(ex$criterion)) "complete" else ex$criterion)
  }
  ti <- ix[tile_id == sel$tile]
  s <- npz_stack(file.path(ex$root, "s2", paste0(sel$tile, ".npz")), ti$west, ti$south, ti$east, ti$north)
  e <- window_ext(s$data, sel$r, sel$c, ex$size)
  sw <- fb_stack(crop(s$data, e, snap = "near"), s$dates, s$bands, crop(s$clear, e, snap = "near"), s$scale)
  stopifnot(nrow(sw$data) == ex$size, ncol(sw$data) == ex$size)
  d <- file.path(out_root, nm)
  unlink(d, recursive = TRUE); dir.create(d, recursive = TRUE)
  idx <- fb_write_stack(sw, d, prefix = "s2")
  idx$image <- basename(idx$image); idx$clear <- basename(idx$clear)
  write.csv(idx, file.path(d, "index.csv"), row.names = FALSE)
  unlink(file.path(d, "s2_index.csv"))
  # PRUE B3 probabilities of the window itself, as a user obtains them with fb_prue_predict()
  sr <- fb_read_stack(file.path(d, idx$image), bands = sw$bands, dates = as.Date(idx$date),
                      clear = file.path(d, idx$clear), scale = sw$scale)
  p <- fb_prue_predict(sr, months = ex$months, model = prue_model)
  writeRaster(round(p, 4), file.path(d, "prue_b3.tif"), overwrite = TRUE, datatype = "FLT4S",
              gdal = c("COMPRESS=DEFLATE", "PREDICTOR=3"))
  v <- as.vector(e)
  year <- as.integer(format(median(s$dates), "%Y"))
  wins[[nm]] <- data.frame(name = nm, tile = sel$tile, west = v[1], east = v[2], south = v[3], north = v[4],
                           year = year, fields_counted = sel$n, prue_months = paste(ex$months, collapse = ","))
  cat(nm, "tile", sel$tile, "window", sel$r, sel$c, "reference fields counted", sel$n, "\n")
}
wf <- tempfile(fileext = ".csv")
write.csv(do.call(rbind, wins), wf, row.names = FALSE)
vd <- file.path(tempdir(), "example_vectors")
system2(py, c("release/fieldborders/data-raw/example_vectors.py", wf, vd))
for (nm in selected) {
  d <- file.path(out_root, nm)
  fp <- file.path(vd, paste0(nm, "_ftw.csv"))
  if (file.exists(fp)) {
    ftw <- utils::read.csv(fp, stringsAsFactors = FALSE)
    g <- st_sf(polygon = seq_len(nrow(ftw)), geometry = st_as_sfc(ftw$wkt, crs = 4326))
    st_write(st_cast(g, "MULTIPOLYGON"), file.path(d, "ftw_global.gpkg"), quiet = TRUE, delete_dsn = TRUE)
  }
  ff <- file.path(vd, paste0(nm, "_fields.csv"))
  if (file.exists(ff)) {
    fl <- utils::read.csv(ff, colClasses = "character")
    g <- st_sf(crop_code = fl$crop_code, geometry = st_as_sfc(fl$wkt, crs = 4326))
    g <- g[as.numeric(st_area(g)) > 50, ]
    st_write(st_cast(g, "MULTIPOLYGON"), file.path(d, "fields.gpkg"), quiet = TRUE, delete_dsn = TRUE)
  }
  cat(nm, "MB", round(sum(file.size(list.files(d, full.names = TRUE))) / 2^20, 2), "\n")
}
write.csv(do.call(rbind, wins), file.path("data/derived/package_models", paste0("example_windows_", paste(selected, collapse = "_"), ".csv")),
          row.names = FALSE)
