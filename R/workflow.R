#' Field boundaries in one step
#'
#' Runs the complete workflow on a stack: TBC edge and cropland maps from a model,
#' optional fusion with deep-model probabilities, field objects and polygons.
#'
#' @param stack An `fb_stack`.
#' @param model An `fb_model` (default: the pretrained `"general"` model).
#' @param dl Optional deep-model probabilities (`background`, `field`, `boundary`), for
#'   example from [fb_prue_predict()], on the grid of `stack`.
#' @param fusion An `fb_fusion` model, used when `dl` is given (default: the pretrained
#'   `"general"` fusion).
#' @param thresholds Delineation thresholds; by default those stored with the model (or
#'   the fusion, when `dl` is given).
#' @param polygons Return polygons as well as rasters.
#' @param threads Number of threads for the cropland model.
#' @return A list with `maps` (edge and cropland), `fields` (field objects) and, if
#'   requested, `polygons` (`sf`).
#' @examples
#' s <- fb_example_stack("moghan")
#' res <- fb_fields(s)
#' res$polygons
#' fb_plot_fields(res$fields, s)
#' @export
fb_fields <- function(stack, model = fb_model_pretrained("general"), dl = NULL,
                      fusion = if (is.null(dl)) NULL else fb_model_pretrained("general", "fusion"),
                      thresholds = NULL, polygons = TRUE, threads = 1L) {
  maps <- fb_tbc_maps(stack, model, threads = threads)
  th <- model$thresholds
  if (!is.null(dl)) {
    maps <- fb_fuse(maps, dl, fusion)
    th <- fusion$thresholds
  }
  if (!is.null(thresholds)) th <- utils::modifyList(th, thresholds)
  fields <- fb_delineate(maps, thresholds = th)
  out <- list(maps = maps, fields = fields)
  if (polygons) out$polygons <- fb_polygons(fields, maps)
  out
}
