#' Fit a fusion of TBC maps and deep-model probabilities
#'
#' Two logistic regressions are fitted on reference pixels: boundary versus field
#' interior on `logit P(boundary)` of the deep model and `logit(edge)` of TBC, and field
#' or boundary versus background on `logit P(field + boundary)` and `logit(cropland)`,
#' each with a ridge penalty of 1 on the slopes.
#'
#' @param tbc_maps A `SpatRaster` from [fb_tbc_maps()], or a list of them.
#' @param dl_maps Deep-model probabilities with layers `background`, `field`, `boundary`
#'   ([fb_prue_predict()], [fb_read_probabilities()]), or a list of them.
#' @param references Reference rasters from [fb_reference()], or a list of them.
#' @param n_pixels Maximum number of pixels per class and tile.
#' @param seed Random seed for the pixel sample.
#' @return An object of class `fb_fusion`.
#' @examples
#' s <- fb_example_stack("california")
#' f <- fb_example_files("california")
#' ref <- fb_reference(sf::st_read(f$fields, quiet = TRUE), s)
#' tbc <- fb_tbc_maps(s, fb_model_pretrained("california"))
#' dl <- fb_read_probabilities(f$prue)
#' fu <- fb_fit_fusion(tbc, dl, ref, n_pixels = 5000)
#' fu
#' @export
fb_fit_fusion <- function(tbc_maps, dl_maps, references, n_pixels = 20000L, seed = 1L) {
  if (inherits(tbc_maps, "SpatRaster")) tbc_maps <- list(tbc_maps)
  if (inherits(dl_maps, "SpatRaster")) dl_maps <- list(dl_maps)
  if (inherits(references, "SpatRaster")) references <- list(references)
  XB <- YB <- XF <- YF <- list()
  for (i in seq_along(tbc_maps)) {
    M <- terra::values(tbc_maps[[i]], mat = TRUE)
    P <- terra::values(dl_maps[[i]], mat = TRUE)
    cls <- as.integer(terra::values(references[[i]][["class"]], mat = FALSE))
    xb <- cbind(safe_logit(P[, "boundary"]), safe_logit(M[, "edge"]))
    xf <- cbind(safe_logit(P[, "field"] + P[, "boundary"]), safe_logit(M[, "cropland"]))
    set.seed(seed + i - 1L)
    pick <- function(w) if (length(w) > n_pixels) sort(w[sample.int(length(w), n_pixels)]) else w
    b1 <- pick(which(cls == 2L)); b0 <- pick(which(cls == 1L))
    f1 <- pick(which(cls %in% c(1L, 2L))); f0 <- pick(which(cls == 0L))
    XB[[i]] <- xb[c(b1, b0), , drop = FALSE]; YB[[i]] <- rep(1:0, c(length(b1), length(b0)))
    XF[[i]] <- xf[c(f1, f0), , drop = FALSE]; YF[[i]] <- rep(1:0, c(length(f1), length(f0)))
  }
  fit <- function(X, y) logistic_ridge(X, y)
  structure(list(boundary = fit(do.call(rbind, XB), unlist(YB)), field = fit(do.call(rbind, XF), unlist(YF)),
                 n = c(boundary = length(unlist(YB)), field = length(unlist(YF))),
                 thresholds = list(t_edge = 0.4, t_field = 0.5, min_size = 50L),
                 version = as.character(utils::packageVersion("fieldborders"))),
            class = "fb_fusion")
}

#' @export
print.fb_fusion <- function(x, ...) {
  cat("<fb_fusion> logistic fusion of deep-model and TBC maps\n")
  cat(sprintf("  boundary: %.3f + %.3f logit P(boundary) + %.3f logit(edge)\n", x$boundary[1], x$boundary[2], x$boundary[3]))
  cat(sprintf("  field   : %.3f + %.3f logit P(field + boundary) + %.3f logit(cropland)\n", x$field[1], x$field[2], x$field[3]))
  th <- x$thresholds
  cat(sprintf("  thresholds: t_edge %.2f, t_field %.2f, min_size %d pixels\n", th$t_edge, th$t_field, as.integer(th$min_size)))
  invisible(x)
}

#' Fuse TBC maps with deep-model probabilities
#'
#' @param tbc_maps A `SpatRaster` from [fb_tbc_maps()].
#' @param dl_maps Deep-model probabilities (`background`, `field`, `boundary`) on the
#'   same grid.
#' @param fusion An `fb_fusion` object from [fb_fit_fusion()] or
#'   [fb_model_pretrained()].
#' @return A `SpatRaster` with fused `edge` and `cropland` layers, ready for
#'   [fb_delineate()].
#' @examples
#' s <- fb_example_stack("california")
#' f <- fb_example_files("california")
#' tbc <- fb_tbc_maps(s, fb_model_pretrained("california"))
#' fused <- fb_fuse(tbc, fb_read_probabilities(f$prue), fb_model_pretrained("california", "fusion"))
#' fb_plot_maps(fused)
#' @export
fb_fuse <- function(tbc_maps, dl_maps, fusion) {
  stopifnot(inherits(fusion, "fb_fusion"))
  if (!terra::compareGeom(tbc_maps, dl_maps, stopOnError = FALSE)) stop("tbc_maps and dl_maps must share the grid")
  M <- terra::values(tbc_maps, mat = TRUE)
  P <- terra::values(dl_maps, mat = TRUE)
  e <- stats::plogis(fusion$boundary[1] + fusion$boundary[2] * safe_logit(P[, "boundary"]) + fusion$boundary[3] * safe_logit(M[, "edge"]))
  f <- stats::plogis(fusion$field[1] + fusion$field[2] * safe_logit(P[, "field"] + P[, "boundary"]) + fusion$field[3] * safe_logit(M[, "cropland"]))
  r <- terra::rast(tbc_maps, nlyrs = 2)
  terra::values(r) <- cbind(e, f)
  names(r) <- c("edge", "cropland")
  r
}

safe_logit <- function(p) {
  p <- pmin(pmax(p, 1e-6), 1 - 1e-6)
  log(p / (1 - p))
}
