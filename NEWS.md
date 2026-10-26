# fieldborders 1.0.0

* First public release.
* Temporal boundary contrast (TBC): ranking of spectral features by their contrast across
  field borders (`fb_rank_contrast()`), feature selection, edge and cropland models
  (`fb_train()`), edge and cropland maps (`fb_tbc_maps()`).
* Fusion with deep-model probabilities (`fb_fit_fusion()`, `fb_fuse()`); the Fields of The
  World PRUE B3 model runs in R through torch (`fb_prue_download()`, `fb_prue_predict()`).
* Field objects and polygons (`fb_delineate()`, `fb_polygons()`, `fb_fields()`), threshold
  tuning (`fb_tune()`).
* Monthly Sentinel-2 time series from a STAC catalogue (`fb_s2_monthly()`).
* Object-level accuracy compatible with the Fields of The World benchmark
  (`fb_evaluate()`, `fb_accuracy()`, `fb_bootstrap()`).
* Pretrained models for California, California and Washington together, and the Fields of
  The World benchmark (`fb_model_pretrained()`).
* Example data from California, Washington, Brazil and Iran (`fb_example_stack()`).
* Articles: getting started, training a model, mapping a new area from Sentinel-2, a
  gallery of fields in six farming regions, and the validation.
