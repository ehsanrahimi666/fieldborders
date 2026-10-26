#' Example data shipped with the package
#'
#' Small Sentinel-2 time series (for each month, the scene with the fewest invalid pixels in
#' the tile that holds the window; ten bands, resampled to the Fields of The World grid of about
#' 5 m, about 1 km across) of four agricultural landscapes, with the output of the PRUE
#' deep model for the same window (`fb_prue_predict()` on the example stack), the Fields of
#' The World global field map of the same year where available, and reference field
#' polygons where their licence allows redistribution:
#'
#' * `"california"`: Colusa County, Sacramento Valley, USA, 2024: rice, orchards and
#'   row crops. Reference fields from the California Department of Water Resources
#'   Statewide Crop Mapping 2024 (CC0-1.0). PRUE months March and July.
#' * `"washington"`: Columbia Basin, Washington, USA: centre-pivot and rectangular
#'   irrigated fields. PRUE months March and July.
#' * `"brazil"`: Tocantins, Brazil, season July 2019 to June 2020: large summer-crop
#'   fields in the Cerrado. PRUE months September and January.
#' * `"moghan"`: Moghan plain, Ardabil, Iran, 2024: narrow strip fields. PRUE months March
#'   and July.
#'
#' The windows lie in tiles that were not used to fit or tune the pretrained models.
#' Contains modified Copernicus Sentinel data 2019, 2020 and 2024. The FTW global
#' field map is licensed CC-BY-4.0 (Fields of The World).
#'
#' @param name Example name, one of `fb_example_names()`.
#' @return `fb_example_files()`: a list with the image and clear-mask files, the dates,
#'   and the paths of the reference fields (`fields`), PRUE probabilities (`prue`) and
#'   FTW map (`ftw`); missing items are `NULL`. `fb_example_stack()`: an `fb_stack`.
#'   `fb_example_bands()`: the band names of the example images. `fb_example_names()`:
#'   the example names.
#' @examples
#' fb_example_names()
#' s <- fb_example_stack("washington")
#' s
#' fb_plot_rgb(s, date = 7)
#' str(fb_example_files("california"))
#' @export
fb_example_files <- function(name = fb_example_names()) {
  name <- match.arg(name)
  d <- system.file("extdata", name, package = "fieldborders")
  if (!nzchar(d)) stop("example data not found")
  idx <- utils::read.csv(file.path(d, "index.csv"), stringsAsFactors = FALSE)
  opt <- function(f) { p <- file.path(d, f); if (file.exists(p)) p else NULL }
  list(images = file.path(d, idx$image), clear = file.path(d, idx$clear), dates = as.Date(idx$date),
       fields = opt("fields.gpkg"), prue = opt("prue_b3.tif"), ftw = opt("ftw_global.gpkg"))
}

#' @rdname fb_example_files
#' @export
fb_example_stack <- function(name = fb_example_names()) {
  f <- fb_example_files(match.arg(name))
  fb_read_stack(f$images, bands = fb_example_bands(), dates = f$dates, clear = f$clear)
}

#' @rdname fb_example_files
#' @export
fb_example_bands <- function() c("B02", "B03", "B04", "B05", "B06", "B07", "B08", "B8A", "B11", "B12")

#' @rdname fb_example_files
#' @export
fb_example_names <- function() c("california", "washington", "brazil", "moghan")
