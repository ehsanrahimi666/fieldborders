#' Pretrained models
#'
#' Models trained with [fb_train()] and [fb_fit_fusion()] on the reference tiles of the
#' validation, with delineation thresholds tuned on separate tiles of the same regions:
#'
#' * `"general"` (default): fitted on 44 tiles in California (2024) and 31 tiles in
#'   Washington (2024 and 2025) together, thresholds tuned on 22 and 15 further tiles; the
#'   model to use where no local reference fields exist.
#' * `"california"`: fitted on the 44 California tiles, thresholds tuned on 22.
#' * `"ftw"`: fitted on 89 Fields of The World benchmark chips from six countries, using
#'   the four 10 m bands only, thresholds tuned on the California and Washington tiles; in
#'   the validation, a model fitted this way transferred to annual crops but not to
#'   perennial crops.
#'
#' The cropland learner of the `"general"` and `"california"` models was chosen among
#' ridge logistic regression, random forest and gradient-boosted trees by object F1 on the
#' tuning tiles (gradient-boosted trees in both); the `"ftw"` model uses gradient-boosted
#' trees. The models were fitted on Sentinel-2 images resampled to the Fields of The World
#' chip grid (about 5 m); the minimum field size is stored in pixels and as an area
#' (`min_area`, square metres), which [fb_delineate()] uses, so that it keeps its meaning
#' at other pixel sizes. In all models the tuned minimum field size is about 1.1 ha, the
#' largest value of the tuning grid, which suits the large fields of the tuning regions;
#' where fields are smaller, pass a smaller `min_area` to [fb_delineate()]. The fusion
#' models combine TBC with PRUE B3 probabilities from the March and July scenes. The test
#' tiles of the validation were not used to fit or tune any model.
#' @param region Model name.
#' @param type `"tbc"` for the TBC model, `"fusion"` for the fusion with the PRUE B3 model
#'   (not available for `"ftw"`).
#' @return An `fb_model` or `fb_fusion` object.
#' @examples
#' fb_model_pretrained()
#' fb_model_pretrained("california", "fusion")
#' @export
fb_model_pretrained <- function(region = c("general", "california", "ftw"), type = c("tbc", "fusion")) {
  region <- match.arg(region)
  type <- match.arg(type)
  f <- system.file("models", sprintf("%s_%s.rds", region, type), package = "fieldborders")
  if (!nzchar(f)) stop("no pretrained ", type, " model for ", region)
  readRDS(f)
}
