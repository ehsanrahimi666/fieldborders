# Read deep-model class probabilities

Reads a three-layer raster of class probabilities (background, field,
boundary), for example written by the Fields of The World tools or by
[`fb_prue_predict()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_prue_predict.md).

## Usage

``` r
fb_read_probabilities(x, layers = c("background", "field", "boundary"))
```

## Arguments

- x:

  A raster file or `SpatRaster` with three layers.

- layers:

  Order of the classes in `x`.

## Value

A `SpatRaster` with layers `background`, `field` and `boundary`.

## Examples

``` r
p <- fb_read_probabilities(fb_example_files("california")$prue)
p
#> class       : SpatRaster
#> size        : 192, 192, 3  (nrow, ncol, nlyr)
#> resolution  : 5.4054e-05, 5.4054e-05  (x, y)
#> extent      : -121.9666, -121.9562, 39.03996, 39.05034  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
#> source      : prue_b3.tif
#> names       : background, field, boundary
#> min values  :          0,     0,        0
#> max values  :          1,     1,        1
```
