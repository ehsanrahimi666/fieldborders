# Read an image time-series stack from files

Read an image time-series stack from files

## Usage

``` r
fb_read_stack(files, bands, dates = NULL, clear = NULL, scale = 10000)
```

## Arguments

- files:

  One raster file per date, each holding `bands` in order.

- bands:

  Band names in layer order.

- dates:

  Acquisition dates; if `NULL`, they are read from the file names
  (`YYYY-MM-DD` or `YYYYMMDD`).

- clear:

  Optional files with one clear-sky mask per date (1 clear, 0 not
  clear).

- scale:

  Divisor that converts stored values to reflectance.

## Value

An `fb_stack`.

## Examples

``` r
f <- fb_example_files("california")
s <- fb_read_stack(f$images, bands = fb_example_bands(), clear = f$clear)
s
#> <fb_stack> 192 x 192 pixels, 12 dates, 10 bands
#>   dates : 2024-01-29 to 2024-12-04 
#>   bands : B02, B03, B04, B05, B06, B07, B08, B8A, B11, B12 
#>   scale : 10000 
#>   crs   : WGS 84 
#>   clear : 100% 100% 100% 100% 100% 100% 100% 100% 100% 100% 100% 100% 
```
