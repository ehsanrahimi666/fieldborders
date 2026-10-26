#' Reference raster from field polygons
#'
#' Rasterizes reference field polygons onto the grid of a stack or raster. Field
#' interiors are class 1, polygon outlines (burnt as one-pixel lines) class 2, and the
#' remaining pixels background (class 0) or, when only some fields are mapped,
#' unlabelled (class 3, ignored in training and in false-positive counts).
#'
#' @param polygons Reference fields as an `sf` object or a `SpatVector` of polygons,
#'   one feature per field.
#' @param template An `fb_stack` or `SpatRaster` defining the grid.
#' @param presence_only `TRUE` when pixels outside the polygons are not known to be
#'   background (for example when only one crop was mapped).
#' @return A `SpatRaster` with layers `class` (0 background, 1 field, 2 boundary,
#'   3 unlabelled) and `field_id` (polygon number, 0 outside fields).
#' @examples
#' f <- fb_example_files("california")
#' s <- fb_example_stack("california")
#' ref <- fb_reference(sf::st_read(f$fields, quiet = TRUE), s)
#' ref
#' terra::freq(ref$class)
#' @export
fb_reference <- function(polygons, template, presence_only = FALSE) {
  g <- if (inherits(template, "fb_stack")) template$data[[1]] else template[[1]]
  v <- if (inherits(polygons, "SpatVector")) polygons else terra::vect(polygons)
  v <- terra::project(v, terra::crs(g))
  v$fb_id <- seq_len(nrow(v))
  inst <- terra::rasterize(v, g, field = "fb_id", background = 0)
  edge <- terra::rasterize(terra::as.lines(v), g, field = 1, background = 0)
  cls <- terra::ifel(inst > 0, 1, if (presence_only) 3 else 0)
  cls <- terra::ifel(edge > 0, 2, cls)
  out <- c(cls, inst)
  names(out) <- c("class", "field_id")
  out
}

# Pixel pairs (x - d, x + d) for the four directions: across pairs straddle a boundary
# pixel between two different fields, within pairs lie inside one field. Up to n_max of
# each class are sampled. Returns a matrix of 1-based cell numbers p, q and the class y.
sample_pairs <- function(cls, inst, nrow, ncol, n_max, seed) {
  r <- rep(seq_len(nrow), each = ncol)
  c <- rep(seq_len(ncol), times = nrow)
  cell <- function(rr, cc) (rr - 1L) * ncol + cc
  out <- list()
  for (d in list(c(0L, 1L), c(1L, 0L), c(1L, 1L), c(1L, -1L))) {
    ok <- r - d[1] >= 1 & r + d[1] <= nrow & c - d[2] >= 1 & c + d[2] <= ncol & c - d[2] <= ncol & c + d[2] >= 1
    x <- which(ok)
    p <- cell(r[x] - d[1], c[x] - d[2])
    q <- cell(r[x] + d[1], c[x] + d[2])
    ends <- cls[p] == 1L & cls[q] == 1L & inst[p] > 0 & inst[q] > 0
    across <- ends & cls[x] == 2L & inst[p] != inst[q]
    within <- ends & cls[x] == 1L & inst[p] == inst[q] & inst[x] == inst[p]
    k <- across | within
    out[[length(out) + 1]] <- cbind(p = p[k], q = q[k], y = as.integer(across[k]))
  }
  pr <- do.call(rbind, out)
  set.seed(seed)
  keep <- unlist(lapply(c(1L, 0L), function(cl) {
    w <- which(pr[, "y"] == cl)
    if (length(w) > n_max) sort(w[sample.int(length(w), n_max)]) else w
  }))
  pr[keep, , drop = FALSE]
}

# Field-interior (1) and background (0) pixels for the cropland model, up to n_max each.
sample_pixels <- function(cls, n_max, seed) {
  set.seed(seed)
  idx <- unlist(lapply(c(1L, 0L), function(cl) {
    w <- which(cls == cl)
    if (length(w) > n_max) sort(w[sample.int(length(w), n_max)]) else w
  }))
  list(cell = idx, y = as.integer(cls[idx] == 1L))
}

# Class and instance vectors (row-major cells) of a reference raster.
reference_values <- function(reference) {
  v <- terra::values(reference, mat = TRUE)
  list(cls = as.integer(v[, 1]), inst = as.integer(v[, 2]))
}
