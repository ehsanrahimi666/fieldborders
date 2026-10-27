# Map layers (edge, cropland or class probabilities)

Map layers (edge, cropland or class probabilities)

## Usage

``` r
fb_plot_maps(maps, layers = names(maps), palette = "magma", max_cells = 250000)
```

## Arguments

- maps:

  A `SpatRaster` with probability layers, such as the output of
  [`fb_tbc_maps()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_tbc_maps.md),
  [`fb_fuse()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_fuse.md)
  or
  [`fb_prue_predict()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_prue_predict.md).

- layers:

  Layers to show (default all).

- palette:

  Viridis palette option (`"magma"`, `"viridis"`, ...).

- max_cells:

  Rasters with more cells are averaged in blocks for display.

## Value

A `ggplot` object with one panel per layer.

## Examples

``` r
maps <- fb_tbc_maps(fb_example_stack("california"), fb_model_pretrained("california"))
fb_plot_maps(maps)

fb_plot_maps(fb_read_probabilities(fb_example_files("brazil")$prue), palette = "viridis")
```
