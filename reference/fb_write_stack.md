# Write an image time-series stack to files

Writes one GeoTIFF per date (bands in order, unsigned 16-bit when the
stack holds digital numbers), one clear-mask GeoTIFF per date, and an
index table.

## Usage

``` r
fb_write_stack(x, dir, prefix = "s2")
```

## Arguments

- x:

  An `fb_stack`.

- dir:

  Output directory (created if needed).

- prefix:

  File name prefix.

## Value

Invisibly, a data frame with the date and the image and mask paths.

## Examples

``` r
s <- fb_example_stack("california")
d <- file.path(tempdir(), "stack")
idx <- fb_write_stack(s, d)
fb_read_stack(idx$image, bands = s$bands, dates = idx$date, clear = idx$clear)
#> <fb_stack> 192 x 192 pixels, 12 dates, 10 bands
#>   dates : 2024-01-29 to 2024-12-04 
#>   bands : B02, B03, B04, B05, B06, B07, B08, B8A, B11, B12 
#>   scale : 10000 
#>   crs   : WGS 84 
#>   clear : 100% 100% 100% 100% 100% 100% 100% 100% 100% 100% 100% 100% 
```
