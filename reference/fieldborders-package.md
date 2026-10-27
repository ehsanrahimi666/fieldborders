# fieldborders: agricultural field boundaries from Sentinel-2 time series

The package delineates agricultural fields from image time series with
the temporal boundary contrast (TBC) method and, optionally, fuses its
maps with the class probabilities of deep segmentation models.

## Details

A typical workflow:

1.  build a time-series stack:
    [`fb_s2_monthly()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_s2_monthly.md)
    (download) or
    [`fb_stack()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_stack.md)
    /
    [`fb_read_stack()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_read_stack.md)
    (own data);

2.  get a model:
    [`fb_model_pretrained()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_model_pretrained.md),
    or train one with reference polygons
    ([`fb_reference()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_reference.md),
    [`fb_rank_contrast()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_rank_contrast.md),
    [`fb_train()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_train.md));

3.  compute edge and cropland maps:
    [`fb_tbc_maps()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_tbc_maps.md);
    optionally fuse them with deep-model probabilities
    ([`fb_prue_predict()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_prue_predict.md),
    [`fb_fuse()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_fuse.md));

4.  delineate fields:
    [`fb_delineate()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_delineate.md),
    [`fb_polygons()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_polygons.md),
    or all in one step with
    [`fb_fields()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_fields.md);

5.  assess accuracy:
    [`fb_evaluate()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_evaluate.md),
    [`fb_accuracy()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_accuracy.md),
    [`fb_bootstrap()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_bootstrap.md);

6.  map the results:
    [`fb_plot_rgb()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_plot_rgb.md),
    [`fb_plot_maps()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_plot_maps.md),
    [`fb_plot_fields()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_plot_fields.md).

## See also

Useful links:

- <https://github.com/ehsanrahimi666/fieldborders>

- Report bugs at <https://github.com/ehsanrahimi666/fieldborders/issues>

## Author

**Maintainer**: Ehsan Rahimi <ehsanrahimi666@gmail.com>
([ORCID](https://orcid.org/0000-0002-8401-472X))

Authors:

- Ehsan Rahimi <ehsanrahimi666@gmail.com>
  ([ORCID](https://orcid.org/0000-0002-8401-472X))

- Chuleui Jung
