#' fieldborders: agricultural field boundaries from Sentinel-2 time series
#'
#' The package delineates agricultural fields from image time series with the
#' temporal boundary contrast (TBC) method and, optionally, fuses its maps with the
#' class probabilities of deep segmentation models.
#'
#' A typical workflow:
#' 1. build a time-series stack: [fb_s2_monthly()] (download) or [fb_stack()] /
#'    [fb_read_stack()] (own data);
#' 2. get a model: [fb_model_pretrained()], or train one with reference polygons
#'    ([fb_reference()], [fb_rank_contrast()], [fb_train()]);
#' 3. compute edge and cropland maps: [fb_tbc_maps()]; optionally fuse them with deep-model
#'    probabilities ([fb_prue_predict()], [fb_fuse()]);
#' 4. delineate fields: [fb_delineate()], [fb_polygons()], or all in one step with
#'    [fb_fields()];
#' 5. assess accuracy: [fb_evaluate()], [fb_accuracy()], [fb_bootstrap()];
#' 6. map the results: [fb_plot_rgb()], [fb_plot_maps()], [fb_plot_fields()].
#'
#' @keywords internal
#' @useDynLib fieldborders, .registration = TRUE
#' @importFrom Rcpp sourceCpp
#' @importFrom ranger ranger
#' @importFrom data.table data.table rbindlist := .N .SD
"_PACKAGE"

.datatable.aware <- TRUE

utils::globalVariables(c(".N", ".SD", "N", "x", "y", "value", "red", "green", "blue", "layer",
                         "feature", "auc", "selected", "metric", "estimate", "lo", "hi", "method",
                         "field_id", "class", "size", "recall", "group", "fill", "tp", "fp", "fn"))
