# Fuse TBC maps with deep-model probabilities

Fuse TBC maps with deep-model probabilities

## Usage

``` r
fb_fuse(tbc_maps, dl_maps, fusion)
```

## Arguments

- tbc_maps:

  A `SpatRaster` from
  [`fb_tbc_maps()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_tbc_maps.md).

- dl_maps:

  Deep-model probabilities (`background`, `field`, `boundary`) on the
  same grid.

- fusion:

  An `fb_fusion` object from
  [`fb_fit_fusion()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_fit_fusion.md)
  or
  [`fb_model_pretrained()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_model_pretrained.md).

## Value

A `SpatRaster` with fused `edge` and `cropland` layers, ready for
[`fb_delineate()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_delineate.md).

## Examples

``` r
s <- fb_example_stack("california")
f <- fb_example_files("california")
tbc <- fb_tbc_maps(s, fb_model_pretrained("california"))
fused <- fb_fuse(tbc, fb_read_probabilities(f$prue), fb_model_pretrained("california", "fusion"))
fb_plot_maps(fused)
```
