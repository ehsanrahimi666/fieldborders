#' Monthly Sentinel-2 time series for an area
#'
#' Searches a STAC catalogue (by default Microsoft Planetary Computer) for Sentinel-2
#' Level-2A scenes, keeps per calendar month the scene with the smallest share of invalid
#' pixels in the area (among the `max_per_month` scenes with the least scene-level cloud
#' cover) (scene classification classes 0, 1, 3, 8, 9 and 10: no data,
#' saturated, cloud shadow, medium and high cloud probability, thin cirrus), skips months
#' with more than `max_invalid` invalid pixels, and resamples the bands bilinearly (the
#' scene classification by nearest neighbour) to a common grid. The radiometric offset of
#' processing baseline 04.00 and later is removed.
#'
#' The scene classification misses some clouds, haze and cloud shadows, which then enter
#' the series as clear pixels; look at the images (for example with [fb_plot_rgb()] for
#' every date) and drop affected dates with [fb_subset_dates()]. In the southern
#' hemisphere, choose a period that holds the summer growing season, for example July to
#' June.
#'
#' @param aoi Area of interest: an `sf` or `SpatVector` object, a numeric bounding box
#'   `c(xmin, ymin, xmax, ymax)` in longitude and latitude, or a `SpatRaster` whose grid
#'   is used as is.
#' @param start,end First and last date of the period (`"YYYY-MM-DD"`).
#' @param bands Sentinel-2 bands to read.
#' @param resolution Pixel size in metres of the output grid (ignored when `aoi` is a
#'   `SpatRaster`); the grid uses the UTM zone of the area's centre. The pretrained models
#'   were developed on Sentinel-2 resampled to about 5 m (the Fields of The World chip
#'   grid), which is the default.
#' @param max_per_month Number of scenes per month, those with the least scene-level cloud
#'   cover, whose scene classification is read to find the clearest one.
#' @param max_cloud Upper limit of the scene-level cloud cover (percent) in the search.
#' @param max_invalid Largest share of invalid pixels in the area for a month to be kept.
#' @param invalid_classes Scene classification classes treated as invalid; add 11 to treat
#'   snow as invalid.
#' @param stac_url,collection STAC API and collection.
#' @param dir Optional directory where the stack is written ([fb_write_stack()]).
#' @param verbose Print progress.
#' @return An `fb_stack` of digital numbers (`scale = 10000`) with clear-sky masks; the
#'   scene identifiers are stored in the attribute `"items"`.
#' @examples
#' \dontrun{
#' # about 1.6 km x 1.6 km of centre-pivot fields near Jovein, Iran; one scene per month of
#' # 2024 (needs an internet connection; takes a few minutes)
#' s <- fb_s2_monthly(c(57.436, 36.606, 57.454, 36.620), "2024-01-01", "2024-12-31")
#' s
#' fb_plot_rgb(s, date = 7)
#' }
#' @export
fb_s2_monthly <- function(aoi, start, end, bands = c("B02", "B03", "B04", "B05", "B06", "B07", "B08", "B8A", "B11", "B12"),
                          resolution = 5, max_cloud = 60, max_invalid = 0.2, max_per_month = 4L,
                          invalid_classes = c(0, 1, 3, 8, 9, 10),
                          stac_url = "https://planetarycomputer.microsoft.com/api/stac/v1",
                          collection = "sentinel-2-l2a", dir = NULL, verbose = TRUE) {
  if (!requireNamespace("rstac", quietly = TRUE)) stop("fb_s2_monthly needs the rstac package")
  grid <- s2_grid(aoi, resolution)
  bb <- as.vector(terra::ext(terra::project(terra::as.polygons(terra::ext(grid), crs = terra::crs(grid)), "EPSG:4326")))
  bbox <- bb[c(1, 3, 2, 4)]
  q <- rstac::stac_search(rstac::stac(stac_url), collections = collection, bbox = bbox,
                          datetime = paste0(start, "/", end), limit = 500)
  q <- rstac::ext_query(q, "eo:cloud_cover" < max_cloud)
  items <- with_retries(rstac::items_fetch(rstac::post_request(q)), "catalogue search")
  if (grepl("planetarycomputer", stac_url)) {
    items <- with_retries(rstac::items_sign(items, rstac::sign_planetary_computer()), "signing the scene addresses")
  }
  feats <- items$features
  if (!length(feats)) stop("no scenes found")
  cc <- vapply(feats, function(f) as.numeric(f$properties[["eo:cloud_cover"]] %||% 0), 0)
  mo <- substr(vapply(feats, function(f) f$properties$datetime, ""), 1, 7)
  keep_cand <- unlist(lapply(split(seq_along(feats), mo), function(w) w[order(cc[w])][seq_len(min(length(w), max_per_month))]))
  feats <- feats[sort(keep_cand)]
  if (verbose) message(length(feats), " scenes found; reading scene classifications")
  scl <- lapply(feats, function(f) warp_asset(f$assets$SCL$href, grid, "near"))
  inv <- vapply(scl, function(r) {
    v <- terra::values(r, mat = FALSE)
    mean(is.na(v) | v %in% invalid_classes)
  }, 0)
  dt <- as.Date(substr(vapply(feats, function(f) f$properties$datetime, ""), 1, 10))
  mon <- format(dt, "%Y-%m")
  keep <- integer()
  for (m in unique(mon)) {
    w <- which(mon == m & inv <= max_invalid)
    if (length(w)) keep <- c(keep, w[which.min(inv[w])])
  }
  keep <- keep[order(dt[keep])]
  if (!length(keep)) stop("no month with at most ", max_invalid * 100, " % invalid pixels")
  if (verbose) message(length(keep), " months kept; reading ", length(bands), " bands")
  layers <- list(); clear <- list()
  for (k in keep) {
    f <- feats[[k]]
    pb <- suppressWarnings(as.numeric(f$properties[["s2:processing_baseline"]]))
    off <- if (is.finite(pb) && pb >= 4) 1000 else 0
    r <- terra::rast(lapply(bands, function(b) warp_asset(f$assets[[b]]$href, grid, "bilinear")))
    r <- terra::clamp(r - off, lower = 0, values = TRUE)
    layers[[length(layers) + 1]] <- round(r)
    s <- scl[[k]]
    clear[[length(clear) + 1]] <- terra::ifel(is.na(s) | s %in% invalid_classes, 0, 1)
  }
  st <- fb_stack(terra::rast(layers), dt[keep], bands, terra::rast(clear), scale = 10000)
  attr(st, "items") <- vapply(feats[keep], function(f) f$id, "")
  if (!is.null(dir)) fb_write_stack(st, dir)
  st
}

`%||%` <- function(a, b) if (is.null(a)) b else a

s2_grid <- function(aoi, resolution) {
  if (inherits(aoi, "SpatRaster")) return(terra::rast(aoi[[1]]))
  if (is.numeric(aoi)) {
    v <- terra::vect(terra::ext(aoi[c(1, 3, 2, 4)]), crs = "EPSG:4326")
  } else v <- if (inherits(aoi, "SpatVector")) aoi else terra::vect(aoi)
  v <- terra::project(v, "EPSG:4326")
  ctr <- terra::geom(terra::centroids(terra::as.polygons(terra::ext(v), crs = "EPSG:4326")))[1, c("x", "y")]
  epsg <- (if (ctr[["y"]] >= 0) 32600 else 32700) + floor((ctr[["x"]] + 180) / 6) + 1
  e <- terra::ext(terra::project(v, paste0("EPSG:", epsg)))
  e <- terra::ext(floor(e[1] / resolution) * resolution, ceiling(e[2] / resolution) * resolution,
                  floor(e[3] / resolution) * resolution, ceiling(e[4] / resolution) * resolution)
  terra::rast(e, resolution = resolution, crs = paste0("EPSG:", epsg))
}

warp_asset <- function(href, grid, method) {
  with_retries({
    src <- terra::rast(paste0("/vsicurl/", href))
    terra::project(src, grid, method = method)
  }, "reading an image")
}

# Evaluates expr up to `attempts` times, waiting longer after each failure (network requests).
with_retries <- function(expr, what, attempts = 3L) {
  ex <- substitute(expr); env <- parent.frame()
  for (k in seq_len(attempts)) {
    res <- tryCatch(eval(ex, env), error = function(e) e)
    if (!inherits(res, "error")) return(res)
    if (k < attempts) Sys.sleep(5 * k)
  }
  stop(what, " failed after ", attempts, " attempts: ", conditionMessage(res), call. = FALSE)
}
