#' Delineate field objects from edge and cropland maps
#'
#' The object procedure validated with the package: markers are the 4-connected
#' components of `{cropland > t_field and edge < t_edge}` with at least `min_marker`
#' pixels; a marker-controlled watershed on the edge map, within `{cropland > 0.5}`,
#' assigns the remaining cropland pixels; touching objects are separated by one-pixel
#' lines and objects smaller than `min_size` pixels are removed.
#'
#' @param maps A `SpatRaster` with layers `edge` and `cropland` ([fb_tbc_maps()],
#'   [fb_fuse()]) or deep-model probabilities with layers `background`, `field` and
#'   `boundary` (then `edge = P(boundary)` and `cropland = P(field) + P(boundary)`).
#' @param t_edge,t_field Marker thresholds.
#' @param min_size Minimum object size in pixels.
#' @param min_area Optional minimum object area in square metres; overrides `min_size`.
#' @param min_marker Minimum marker size in pixels.
#' @param thresholds Optional list with `t_edge`, `t_field`, `min_size` and optionally
#'   `min_area` (for example the `thresholds` element of a model), used for arguments that
#'   are not given; a `min_area` in the list takes precedence over its `min_size`, so that
#'   the minimum field size does not depend on the pixel size.
#' @return A `SpatRaster` (`field_id`) of field objects, 0 outside fields.
#' @examples
#' s <- fb_example_stack("california")
#' m <- fb_model_pretrained("california")
#' maps <- fb_tbc_maps(s, m)
#' fields <- fb_delineate(maps, thresholds = m$thresholds)
#' fb_plot_fields(fields, s, date = 7)
#' # thresholds can also be given one by one, and the minimum size as an area
#' fields2 <- fb_delineate(maps, t_edge = 0.3, t_field = 0.7, min_area = 5000)
#' @export
fb_delineate <- function(maps, t_edge = NULL, t_field = NULL, min_size = NULL, min_area = NULL, min_marker = 20L,
                         thresholds = NULL) {
  th <- utils::modifyList(list(t_edge = 0.5, t_field = 0.5, min_size = 50L), as.list(thresholds))
  if (is.null(t_edge)) t_edge <- th$t_edge
  if (is.null(t_field)) t_field <- th$t_field
  if (is.null(min_size) && is.null(min_area)) {
    if (!is.null(th$min_area)) min_area <- th$min_area else min_size <- th$min_size
  }
  ef <- map_matrices(maps)
  if (!is.null(min_area)) min_size <- max(1L, round(min_area / mean_cell_area(maps)))
  obj <- objects_from_maps(ef$E, ef$F, t_edge, t_field, as.integer(min_size), as.integer(min_marker))
  from_matrix(obj, maps, "field_id")
}

# Edge and cropland matrices of a map raster (TBC or fused maps, or deep-model probabilities).
map_matrices <- function(maps) {
  nm <- names(maps)
  if (all(c("edge", "cropland") %in% nm)) {
    list(E = as_matrix(maps[["edge"]]), F = as_matrix(maps[["cropland"]]))
  } else if (all(c("field", "boundary") %in% nm)) {
    E <- as_matrix(maps[["boundary"]])
    list(E = E, F = as_matrix(maps[["field"]]) + E)
  } else stop("maps need layers edge and cropland, or field and boundary")
}

objects_from_maps <- function(E, F, t_edge, t_field, min_size = 0L, min_marker = 20L) {
  E[!is.finite(E)] <- 1
  F[!is.finite(F)] <- 0
  mask <- F > 0.5
  mk <- fb_components(F > t_field & E < t_edge & mask)
  if (max(mk) > 0L) {
    sz <- tabulate(mk[mk > 0L], nbins = max(mk))
    small <- which(sz < min_marker)
    if (length(small)) mk[mk %in% small] <- 0L
    mk <- fb_components(mk)
  }
  if (max(mk) == 0L) return(matrix(0L, nrow(E), ncol(E)))
  L0 <- fb_watershed(E, mk, mask, lines = FALSE)
  filter_small(fb_finalise(L0, mask), min_size)
}

filter_small <- function(obj, min_size) {
  if (min_size <= 0L) return(obj)
  C <- fb_components(obj)
  if (max(C) > 0L) {
    s <- tabulate(C[C > 0L], nbins = max(C))
    small <- which(s < min_size)
    if (length(small)) obj[C %in% small] <- 0L
  }
  obj
}

mean_cell_area <- function(r) {
  if (terra::is.lonlat(r)) mean(terra::values(terra::cellSize(r[[1]], unit = "m"), mat = FALSE), na.rm = TRUE)
  else prod(terra::res(r)) * terra::linearUnits(r)^2
}

#' Tune delineation thresholds on reference tiles
#'
#' Evaluates every combination of thresholds on tiles with reference rasters and returns
#' the object-level accuracy of each combination, pooled over tiles, with the best
#' combination first.
#'
#' @param maps A map `SpatRaster` (see [fb_delineate()]) or a list of them.
#' @param references Reference rasters from [fb_reference()], one per map.
#' @param t_edge,t_field,min_size Candidate values.
#' @param iou Intersection-over-union required for a match.
#' @return A data frame with one row per combination: thresholds, object precision,
#'   recall and F1, sorted by decreasing F1.
#' @examples
#' s <- fb_example_stack("california")
#' f <- fb_example_files("california")
#' ref <- fb_reference(sf::st_read(f$fields, quiet = TRUE), s)
#' maps <- fb_tbc_maps(s, fb_model_pretrained("california"))
#' tn <- fb_tune(maps, ref, t_edge = c(0.3, 0.5), t_field = c(0.5, 0.7), min_size = c(0, 50))
#' head(tn)
#' @export
fb_tune <- function(maps, references, t_edge = c(0.2, 0.3, 0.4, 0.5, 0.6), t_field = c(0.5, 0.7, 0.9),
                    min_size = c(0, 50, 100, 200), iou = 0.5) {
  if (inherits(maps, "SpatRaster")) maps <- list(maps)
  if (inherits(references, "SpatRaster")) references <- list(references)
  grid <- expand.grid(t_edge = t_edge, t_field = t_field, stringsAsFactors = FALSE)
  res <- list()
  for (i in seq_along(maps)) {
    sem <- as_matrix(references[[i]][["class"]])
    storage.mode(sem) <- "integer"
    G <- fb_components(sem == 1L)
    ef <- map_matrices(maps[[i]])
    for (g in seq_len(nrow(grid))) {
      o <- objects_from_maps(ef$E, ef$F, grid$t_edge[g], grid$t_field[g], 0L, 20L)
      for (s in min_size) {
        ev <- object_counts(sem, filter_small(o, as.integer(s)), iou = iou, G = G)
        res[[length(res) + 1]] <- data.frame(t_edge = grid$t_edge[g], t_field = grid$t_field[g], min_size = s,
                                             tp = ev$obj_tp, fp = ev$obj_fp, fn = ev$obj_fn)
      }
    }
  }
  d <- data.table::rbindlist(res)
  d <- d[, list(tp = sum(tp), fp = sum(fp), fn = sum(fn)), by = c("t_edge", "t_field", "min_size")]
  d[, `:=`(precision = tp / pmax(tp + fp, 1), recall = tp / pmax(tp + fn, 1), f1 = 2 * tp / pmax(2 * tp + fp + fn, 1))]
  d <- as.data.frame(d[order(-d$f1), ])
  d
}

#' Field polygons from field objects
#'
#' Converts field objects to polygons with their area, perimeter, compactness and,
#' optionally, mean edge and cropland probability.
#'
#' @param fields A `SpatRaster` of field objects from [fb_delineate()].
#' @param maps Optional map `SpatRaster` whose layer means are added per field.
#' @param simplify Simplification tolerance in map units (`0` for none); in geographic
#'   coordinates a value around half a pixel removes the stair steps of pixel edges.
#' @param min_area Minimum polygon area in square metres.
#' @return An `sf` data frame with `field_id`, `area_ha`, `perimeter_m`, `compactness`
#'   (4 pi area / perimeter^2) and map means.
#' @examples
#' s <- fb_example_stack("california")
#' m <- fb_model_pretrained("california")
#' maps <- fb_tbc_maps(s, m)
#' p <- fb_polygons(fb_delineate(maps, thresholds = m$thresholds), maps)
#' head(p)
#' summary(p$area_ha)
#' @export
fb_polygons <- function(fields, maps = NULL, simplify = 0, min_area = 0) {
  v <- terra::as.polygons(fields, dissolve = TRUE)
  v <- v[v$field_id > 0, ]
  p <- sf::st_as_sf(v)
  if (simplify > 0) p <- sf::st_simplify(p, preserveTopology = TRUE, dTolerance = simplify)
  a <- as.numeric(sf::st_area(p))
  per <- as.numeric(sf::st_length(sf::st_cast(sf::st_geometry(p), "MULTILINESTRING")))
  p$area_ha <- a / 1e4
  p$perimeter_m <- per
  p$compactness <- 4 * pi * a / per^2
  if (!is.null(maps)) {
    z <- terra::zonal(maps, fields, fun = "mean", na.rm = TRUE)
    names(z)[1] <- "field_id"
    names(z)[-1] <- paste0("mean_", names(z)[-1])
    p <- merge(p, z, by = "field_id", all.x = TRUE)
  }
  p <- p[p$area_ha * 1e4 >= min_area, ]
  p[order(p$field_id), ]
}
