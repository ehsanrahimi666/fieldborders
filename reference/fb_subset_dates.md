# Subset a stack by date

Subset a stack by date

## Usage

``` r
fb_subset_dates(x, dates)
```

## Arguments

- x:

  An `fb_stack`.

- dates:

  Dates to keep (`Date` or strings), or a logical or integer index.

## Value

An `fb_stack` with the selected dates.

## Examples

``` r
s <- fb_example_stack("california")
fb_subset_dates(s, format(s$dates) >= "2024-04-01" & format(s$dates) < "2024-10-01")
#> <fb_stack> 192 x 192 pixels, 6 dates, 10 bands
#>   dates : 2024-04-28 to 2024-09-30 
#>   bands : B02, B03, B04, B05, B06, B07, B08, B8A, B11, B12 
#>   scale : 10000 
#>   crs   : WGS 84 
#>   clear : 100% 100% 100% 100% 100% 100% 
```
