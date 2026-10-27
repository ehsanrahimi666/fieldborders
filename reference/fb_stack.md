# Image time-series stack

Bundles a multi-date, multi-band image with its acquisition dates, band
names and per-date clear-sky masks. All other functions of the package
take this object.

## Usage

``` r
fb_stack(x, dates, bands, clear = NULL, scale = 10000)
```

## Arguments

- x:

  A `SpatRaster` whose layers are the bands of each date, date by date
  (all bands of the first date, then all bands of the second date, and
  so on), or a list of `SpatRaster`s with one multi-band raster per
  date.

- dates:

  Acquisition dates, one per date (`Date` or `"YYYY-MM-DD"` strings).

- bands:

  Band names in layer order within each date, for example
  `c("B02", "B03", "B04", "B08")`. Sentinel-2 band names are expected by
  the pretrained models and the default feature set.

- clear:

  Optional `SpatRaster` with one layer per date: 1 for clear pixels, 0
  for cloud, cloud shadow, snow or no data. `NULL` treats all pixels as
  clear; pixels with missing band values are always treated as not
  clear.

- scale:

  Divisor that converts stored values to surface reflectance (10000 for
  Sentinel-2 L2A digital numbers with the offset removed, 1 for
  reflectance).

## Value

An object of class `fb_stack`: a list with `data` (`SpatRaster`),
`clear` (`SpatRaster` or `NULL`), `dates`, `bands` and `scale`.

## See also

[`fb_read_stack()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_read_stack.md),
[`fb_s2_monthly()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_s2_monthly.md),
[`fb_example_stack()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_example_files.md)

## Examples

``` r
# two dates of the California example, ten bands each, read with terra
f <- fb_example_files("california")
r <- terra::rast(f$images[c(3, 7)])
s <- fb_stack(r, dates = f$dates[c(3, 7)], bands = fb_example_bands(),
              clear = terra::rast(f$clear[c(3, 7)]))
s
#> <fb_stack> 192 x 192 pixels, 2 dates, 10 bands
#>   dates : 2024-03-19 to 2024-07-27 
#>   bands : B02, B03, B04, B05, B06, B07, B08, B8A, B11, B12 
#>   scale : 10000 
#>   crs   : WGS 84 
#>   clear : 100% 100% 
fb_dates(s)
#> [1] "2024-03-19" "2024-07-27"
```
