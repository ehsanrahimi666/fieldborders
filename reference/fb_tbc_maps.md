# Edge and cropland maps from a TBC model

Computes, for every pixel, the edge probability (the maximum over four
directions of the edge-model probability of the pixel pair centred on
it) and the cropland probability. Large rasters are processed in blocks
of rows.

## Usage

``` r
fb_tbc_maps(stack, model, filename = "", block_cells = 100000L, threads = 1L)
```

## Arguments

- stack:

  An `fb_stack` holding the bands of the model.

- model:

  An `fb_model` from
  [`fb_train()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_train.md)
  or
  [`fb_model_pretrained()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_model_pretrained.md).

- filename:

  Optional output GeoTIFF.

- block_cells:

  Approximate number of cells per processing block.

- threads:

  Number of threads for the cropland model.

## Value

A `SpatRaster` with layers `edge` and `cropland`.

## Examples

``` r
s <- fb_example_stack("california")
maps <- fb_tbc_maps(s, fb_model_pretrained("california"))
fb_plot_maps(maps)
```
