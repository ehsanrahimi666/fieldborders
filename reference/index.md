# Package index

## Image time series

Download monthly Sentinel-2 scenes or read your own images.

- [`fb_s2_monthly()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_s2_monthly.md)
  : Monthly Sentinel-2 time series for an area
- [`fb_stack()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_stack.md)
  : Image time-series stack
- [`fb_read_stack()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_read_stack.md)
  : Read an image time-series stack from files
- [`fb_write_stack()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_write_stack.md)
  : Write an image time-series stack to files
- [`fb_dates()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_dates.md)
  : Acquisition dates of a stack
- [`fb_subset_dates()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_subset_dates.md)
  : Subset a stack by date

## Temporal boundary contrast

Rank spectral features by their contrast across field borders, train and
apply models.

- [`fb_feature_set()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_feature_set.md)
  : Candidate spectral features
- [`fb_reference()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_reference.md)
  : Reference raster from field polygons
- [`fb_rank_contrast()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_rank_contrast.md)
  : Rank spectral features by their temporal contrast across field
  borders
- [`fb_select_features()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_select_features.md)
  : Select features from a contrast ranking
- [`fb_train()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_train.md)
  : Train a temporal boundary contrast (TBC) model
- [`fb_tbc_maps()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_tbc_maps.md)
  : Edge and cropland maps from a TBC model
- [`fb_model_pretrained()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_model_pretrained.md)
  : Pretrained models
- [`fb_save_model()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_save_model.md)
  [`fb_load_model()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_save_model.md)
  : Save and load a model

## Deep models and fusion

Run the Fields of The World PRUE model in R and fuse it with TBC.

- [`fb_prue_download()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_prue_download.md)
  : Download the PRUE deep model for R
- [`fb_prue_predict()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_prue_predict.md)
  : Run the PRUE deep model on a stack
- [`fb_read_probabilities()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_read_probabilities.md)
  : Read deep-model class probabilities
- [`fb_fit_fusion()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_fit_fusion.md)
  : Fit a fusion of TBC maps and deep-model probabilities
- [`fb_fuse()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_fuse.md)
  : Fuse TBC maps with deep-model probabilities

## Field objects

From maps to fields and polygons.

- [`fb_fields()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_fields.md)
  : Field boundaries in one step
- [`fb_delineate()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_delineate.md)
  : Delineate field objects from edge and cropland maps
- [`fb_tune()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_tune.md)
  : Tune delineation thresholds on reference tiles
- [`fb_polygons()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_polygons.md)
  : Field polygons from field objects
- [`fb_components()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_components.md)
  : Connected components
- [`fb_watershed()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_watershed.md)
  : Marker-controlled watershed
- [`fb_finalise()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_finalise.md)
  : Final field objects from a label matrix

## Accuracy

Object-level accuracy compatible with the Fields of The World benchmark.

- [`fb_evaluate()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_evaluate.md)
  : Object-level accuracy of field delineation
- [`fb_accuracy()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_accuracy.md)
  : Accuracy metrics from evaluation counts
- [`fb_bootstrap()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_bootstrap.md)
  : Paired bootstrap of accuracy differences between methods
- [`fb_auc()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_auc.md)
  : Area under the ROC curve

## Maps and plots

- [`fb_plot_rgb()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_plot_rgb.md)
  : True-colour image of one date
- [`fb_plot_maps()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_plot_maps.md)
  : Map layers (edge, cropland or class probabilities)
- [`fb_plot_fields()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_plot_fields.md)
  : Field objects or polygons over the image
- [`fb_plot_ranking()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_plot_ranking.md)
  : Feature ranking by border contrast
- [`fb_plot_accuracy()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_plot_accuracy.md)
  : Accuracy of several methods
- [`fb_theme()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_theme.md)
  : Plot theme and colours of the package

## Example data

- [`fb_example_files()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_example_files.md)
  [`fb_example_stack()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_example_files.md)
  [`fb_example_bands()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_example_files.md)
  [`fb_example_names()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_example_files.md)
  : Example data shipped with the package
