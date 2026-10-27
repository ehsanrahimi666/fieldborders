# Changelog

## fieldborders 1.0.0

- First public release.
- Temporal boundary contrast (TBC): ranking of spectral features by
  their contrast across field borders
  ([`fb_rank_contrast()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_rank_contrast.md)),
  feature selection, edge and cropland models
  ([`fb_train()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_train.md)),
  edge and cropland maps
  ([`fb_tbc_maps()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_tbc_maps.md)).
- Fusion with deep-model probabilities
  ([`fb_fit_fusion()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_fit_fusion.md),
  [`fb_fuse()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_fuse.md));
  the Fields of The World PRUE B3 model runs in R through torch
  ([`fb_prue_download()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_prue_download.md),
  [`fb_prue_predict()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_prue_predict.md)).
- Field objects and polygons
  ([`fb_delineate()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_delineate.md),
  [`fb_polygons()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_polygons.md),
  [`fb_fields()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_fields.md)),
  threshold tuning
  ([`fb_tune()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_tune.md)).
- Monthly Sentinel-2 time series from a STAC catalogue
  ([`fb_s2_monthly()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_s2_monthly.md)).
- Object-level accuracy compatible with the Fields of The World
  benchmark
  ([`fb_evaluate()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_evaluate.md),
  [`fb_accuracy()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_accuracy.md),
  [`fb_bootstrap()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_bootstrap.md)).
- Pretrained models for California, California and Washington together,
  and the Fields of The World benchmark
  ([`fb_model_pretrained()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_model_pretrained.md)).
- Example data from California, Washington, Brazil and Iran
  ([`fb_example_stack()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_example_files.md)).
- Articles: getting started, training a model, mapping a new area from
  Sentinel-2, a gallery of fields in six farming regions, and the
  validation.
