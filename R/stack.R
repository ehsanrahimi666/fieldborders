#' Image time-series stack
#'
#' Bundles a multi-date, multi-band image with its acquisition dates, band names and
#' per-date clear-sky masks. All other functions of the package take this object.
#'
#' @param x A `SpatRaster` whose layers are the bands of each date, date by date (all
#'   bands of the first date, then all bands of the second date, and so on), or a list
#'   of `SpatRaster`s with one multi-band raster per date.
#' @param dates Acquisition dates, one per date (`Date` or `"YYYY-MM-DD"` strings).
#' @param bands Band names in layer order within each date, for example
#'   `c("B02", "B03", "B04", "B08")`. Sentinel-2 band names are expected by the
#'   pretrained models and the default feature set.
#' @param clear Optional `SpatRaster` with one layer per date: 1 for clear pixels, 0 for
#'   cloud, cloud shadow, snow or no data. `NULL` treats all pixels as clear; pixels with
#'   missing band values are always treated as not clear.
#' @param scale Divisor that converts stored values to surface reflectance (10000 for
#'   Sentinel-2 L2A digital numbers with the offset removed, 1 for reflectance).
#' @return An object of class `fb_stack`: a list with `data` (`SpatRaster`), `clear`
#'   (`SpatRaster` or `NULL`), `dates`, `bands` and `scale`.
#' @seealso [fb_read_stack()], [fb_s2_monthly()], [fb_example_stack()]
#' @examples
#' # two dates of the California example, ten bands each, read with terra
#' f <- fb_example_files("california")
#' r <- terra::rast(f$images[c(3, 7)])
#' s <- fb_stack(r, dates = f$dates[c(3, 7)], bands = fb_example_bands(),
#'               clear = terra::rast(f$clear[c(3, 7)]))
#' s
#' fb_dates(s)
#' @export
fb_stack <- function(x, dates, bands, clear = NULL, scale = 10000) {
  if (is.list(x) && !inherits(x, "SpatRaster")) x <- terra::rast(x)
  if (!inherits(x, "SpatRaster")) stop("x must be a SpatRaster or a list of SpatRasters")
  dates <- as.Date(dates)
  if (anyNA(dates)) stop("dates must be valid dates")
  if (is.unsorted(dates)) stop("dates must be in increasing order (layers date by date)")
  bands <- as.character(bands)
  if (anyDuplicated(bands)) stop("band names must be unique")
  if (terra::nlyr(x) != length(dates) * length(bands)) {
    stop("x has ", terra::nlyr(x), " layers; expected ", length(dates), " dates x ", length(bands), " bands")
  }
  names(x) <- paste(rep(bands, times = length(dates)), rep(format(dates), each = length(bands)), sep = "_")
  if (!is.null(clear)) {
    if (!inherits(clear, "SpatRaster")) stop("clear must be a SpatRaster or NULL")
    if (terra::nlyr(clear) != length(dates)) stop("clear must have one layer per date")
    if (!terra::compareGeom(x, clear, stopOnError = FALSE)) stop("clear must have the grid of x")
    names(clear) <- paste0("clear_", format(dates))
  }
  structure(list(data = x, clear = clear, dates = dates, bands = bands, scale = as.numeric(scale)),
            class = "fb_stack")
}

#' Read an image time-series stack from files
#'
#' @param files One raster file per date, each holding `bands` in order.
#' @param bands Band names in layer order.
#' @param dates Acquisition dates; if `NULL`, they are read from the file names
#'   (`YYYY-MM-DD` or `YYYYMMDD`).
#' @param clear Optional files with one clear-sky mask per date (1 clear, 0 not clear).
#' @param scale Divisor that converts stored values to reflectance.
#' @return An `fb_stack`.
#' @examples
#' f <- fb_example_files("california")
#' s <- fb_read_stack(f$images, bands = fb_example_bands(), clear = f$clear)
#' s
#' @export
fb_read_stack <- function(files, bands, dates = NULL, clear = NULL, scale = 10000) {
  if (is.null(dates)) {
    m <- regmatches(basename(files), regexpr("[0-9]{4}-?[0-9]{2}-?[0-9]{2}", basename(files)))
    if (length(m) != length(files)) stop("dates could not be read from all file names; give dates")
    dates <- as.Date(gsub("^([0-9]{4})-?([0-9]{2})-?([0-9]{2})$", "\\1-\\2-\\3", m))
  }
  o <- order(as.Date(dates))
  x <- terra::rast(lapply(files[o], terra::rast))
  cl <- if (is.null(clear)) NULL else terra::rast(lapply(clear[o], terra::rast))
  fb_stack(x, as.Date(dates)[o], bands, cl, scale)
}

#' Write an image time-series stack to files
#'
#' Writes one GeoTIFF per date (bands in order, unsigned 16-bit when the stack holds
#' digital numbers), one clear-mask GeoTIFF per date, and an index table.
#'
#' @param x An `fb_stack`.
#' @param dir Output directory (created if needed).
#' @param prefix File name prefix.
#' @return Invisibly, a data frame with the date and the image and mask paths.
#' @examples
#' s <- fb_example_stack("california")
#' d <- file.path(tempdir(), "stack")
#' idx <- fb_write_stack(s, d)
#' fb_read_stack(idx$image, bands = s$bands, dates = idx$date, clear = idx$clear)
#' @export
fb_write_stack <- function(x, dir, prefix = "s2") {
  stopifnot(inherits(x, "fb_stack"))
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  nb <- length(x$bands)
  dt <- if (x$scale > 1) "INT2U" else "FLT4S"
  idx <- data.frame(date = format(x$dates), image = NA_character_, clear = NA_character_)
  for (k in seq_along(x$dates)) {
    f <- file.path(dir, sprintf("%s_%s.tif", prefix, format(x$dates[k])))
    terra::writeRaster(x$data[[((k - 1) * nb + 1):(k * nb)]], f, overwrite = TRUE, datatype = dt,
                       gdal = c("COMPRESS=DEFLATE", "PREDICTOR=2"))
    idx$image[k] <- f
    cl <- if (is.null(x$clear)) terra::init(x$data[[1]], 1) else x$clear[[k]]
    fc <- file.path(dir, sprintf("%s_%s_clear.tif", prefix, format(x$dates[k])))
    terra::writeRaster(cl, fc, overwrite = TRUE, datatype = "INT1U", gdal = "COMPRESS=DEFLATE")
    idx$clear[k] <- fc
  }
  utils::write.csv(idx, file.path(dir, paste0(prefix, "_index.csv")), row.names = FALSE)
  invisible(idx)
}

#' Acquisition dates of a stack
#'
#' @param x An `fb_stack`.
#' @return A `Date` vector.
#' @examples
#' fb_dates(fb_example_stack("california"))
#' @export
fb_dates <- function(x) {
  stopifnot(inherits(x, "fb_stack"))
  x$dates
}

#' Subset a stack by date
#'
#' @param x An `fb_stack`.
#' @param dates Dates to keep (`Date` or strings), or a logical or integer index.
#' @return An `fb_stack` with the selected dates.
#' @examples
#' s <- fb_example_stack("california")
#' fb_subset_dates(s, format(s$dates) >= "2024-04-01" & format(s$dates) < "2024-10-01")
#' @export
fb_subset_dates <- function(x, dates) {
  stopifnot(inherits(x, "fb_stack"))
  k <- if (is.logical(dates)) which(dates) else if (is.numeric(dates)) as.integer(dates) else match(as.Date(dates), x$dates)
  k <- k[!is.na(k)]
  if (!length(k)) stop("no dates selected")
  nb <- length(x$bands)
  lay <- unlist(lapply(k, function(i) ((i - 1) * nb + 1):(i * nb)))
  fb_stack(x$data[[lay]], x$dates[k], x$bands, if (is.null(x$clear)) NULL else x$clear[[k]], x$scale)
}

#' @export
print.fb_stack <- function(x, ...) {
  r <- x$data
  cat("<fb_stack>", terra::nrow(r), "x", terra::ncol(r), "pixels,", length(x$dates), "dates,",
      length(x$bands), "bands\n")
  cat("  dates :", paste(format(range(x$dates)), collapse = " to "), "\n")
  cat("  bands :", paste(x$bands, collapse = ", "), "\n")
  cat("  scale :", x$scale, "\n")
  cat("  crs   :", terra::crs(r, describe = TRUE)$name, "\n")
  if (!is.null(x$clear)) {
    cf <- terra::global(x$clear, "mean", na.rm = TRUE)$mean
    cat("  clear :", paste(sprintf("%.0f%%", 100 * cf), collapse = " "), "\n")
  }
  invisible(x)
}

# Values of a block of rows, or of the given cells only: reflectance matrix (cells x
# dates*bands, dates outer) and clear matrix (cells x dates).
stack_block <- function(x, row = 1L, nrows = terra::nrow(x$data), cells = NULL) {
  M <- length(x$dates)
  nb <- length(x$bands)
  if (is.null(cells)) {
    X <- terra::values(x$data, row = row, nrows = nrows, mat = TRUE) / x$scale
    C <- if (is.null(x$clear)) matrix(TRUE, nrow(X), M)
         else terra::values(x$clear, row = row, nrows = nrows, mat = TRUE) > 0.5
  } else {
    X <- unname(as.matrix(terra::extract(x$data, cells))) / x$scale
    C <- if (is.null(x$clear)) matrix(TRUE, nrow(X), M)
         else unname(as.matrix(terra::extract(x$clear, cells))) > 0.5
  }
  C[is.na(C)] <- FALSE
  for (m in seq_len(M)) {
    bad <- rowSums(!is.finite(X[, ((m - 1) * nb + 1):(m * nb), drop = FALSE])) > 0
    C[bad, m] <- FALSE
  }
  list(X = X, C = C, nrow = if (is.null(cells)) nrows else NA_integer_, ncol = terra::ncol(x$data), M = M,
       bands = x$bands)
}
