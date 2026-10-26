#' Connected components
#'
#' Labels connected groups of pixels that share the same positive value.
#'
#' @param x Logical or integer matrix; for integer input, pixels with different positive
#'   values are never joined.
#' @param connectivity 4 or 8.
#' @return Integer matrix of component labels (0 = none).
#' @examples
#' m <- matrix(c(1, 1, 0, 0, 0, 1, 1, 0, 1), 3)
#' fb_components(m > 0)
#' fb_components(m > 0, connectivity = 8)
#' # cropland patches of the Washington example
#' maps <- fb_tbc_maps(fb_example_stack("washington"), fb_model_pretrained())
#' crop <- terra::as.matrix(maps[["cropland"]], wide = TRUE) > 0.5
#' max(fb_components(crop))
#' @export
fb_components <- function(x, connectivity = 4L) {
  storage.mode(x) <- "integer"
  x[is.na(x)] <- 0L
  .cc_label_cpp(x, as.integer(connectivity))
}

#' Marker-controlled watershed
#'
#' Floods `elev` from the markers in order of increasing value (4-connectivity), within
#' `mask`.
#'
#' @param elev Numeric matrix (low values are field interiors, high values boundaries).
#' @param markers Integer matrix of marker labels (0 = none).
#' @param mask Logical matrix of pixels that may be labelled; defaults to all.
#' @param lines If `TRUE`, pixels where basins meet are left unlabelled.
#' @return Integer label matrix (0 = unlabelled).
#' @examples
#' # two basins separated by a ridge in column 10
#' e <- outer(1:20, 1:20, function(i, j) as.numeric(j == 10))
#' mk <- matrix(0L, 20, 20); mk[10, 5] <- 1L; mk[10, 15] <- 2L
#' table(fb_watershed(e, mk))
#' # fields of the Washington example: seeds inside fields, flooding of the edge map
#' maps <- fb_tbc_maps(fb_example_stack("washington"), fb_model_pretrained())
#' E <- terra::as.matrix(maps[["edge"]], wide = TRUE)
#' F <- terra::as.matrix(maps[["cropland"]], wide = TRUE)
#' seeds <- fb_components(F > 0.7 & E < 0.3)
#' ws <- fb_watershed(E, seeds, mask = F > 0.5)
#' length(unique(ws[ws > 0]))
#' @export
fb_watershed <- function(elev, markers, mask = NULL, lines = FALSE) {
  if (is.null(mask)) mask <- matrix(TRUE, nrow(elev), ncol(elev))
  storage.mode(markers) <- "integer"
  markers[is.na(markers)] <- 0L
  mask[is.na(mask)] <- FALSE
  elev[is.na(elev)] <- max(elev, na.rm = TRUE)
  .watershed_cpp(elev, markers, mask, isTRUE(lines))
}

#' Final field objects from a label matrix
#'
#' Keeps labelled pixels flagged in `keep`, closes one-pixel cracks enclosed by a single
#' label, and separates touching objects by a one-pixel line so that every object is a
#' separate 4-connected component.
#'
#' @param labels Integer label matrix.
#' @param keep Logical matrix of pixels that belong to objects.
#' @return Integer label matrix of final objects.
#' @examples
#' lab <- matrix(rep(1:2, each = 50), 10, 10)
#' table(fb_finalise(lab, lab > 0))
#' # watershed basins of the Washington example turned into separate objects
#' maps <- fb_tbc_maps(fb_example_stack("washington"), fb_model_pretrained())
#' E <- terra::as.matrix(maps[["edge"]], wide = TRUE)
#' F <- terra::as.matrix(maps[["cropland"]], wide = TRUE)
#' ws <- fb_watershed(E, fb_components(F > 0.7 & E < 0.3), mask = F > 0.5)
#' obj <- fb_finalise(ws, F > 0.5)
#' max(fb_components(obj))
#' @export
fb_finalise <- function(labels, keep) {
  storage.mode(labels) <- "integer"
  keep[is.na(keep)] <- FALSE
  .finalise_objects_cpp(labels, keep)
}

# matrix (rows north to south) <-> raster helpers
as_matrix <- function(r, k = 1L) {
  matrix(terra::values(r[[k]], mat = FALSE), nrow = terra::nrow(r), ncol = terra::ncol(r), byrow = TRUE)
}
from_matrix <- function(m, template, name) {
  r <- terra::rast(template[[1]])
  terra::values(r) <- as.vector(t(m))
  names(r) <- name
  r
}
