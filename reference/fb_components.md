# Connected components

Labels connected groups of pixels that share the same positive value.

## Usage

``` r
fb_components(x, connectivity = 4L)
```

## Arguments

- x:

  Logical or integer matrix; for integer input, pixels with different
  positive values are never joined.

- connectivity:

  4 or 8.

## Value

Integer matrix of component labels (0 = none).

## Examples

``` r
m <- matrix(c(1, 1, 0, 0, 0, 1, 1, 0, 1), 3)
fb_components(m > 0)
#>      [,1] [,2] [,3]
#> [1,]    1    0    3
#> [2,]    1    0    0
#> [3,]    0    2    2
fb_components(m > 0, connectivity = 8)
#>      [,1] [,2] [,3]
#> [1,]    1    0    2
#> [2,]    1    0    0
#> [3,]    0    1    1
# cropland patches of the Washington example
maps <- fb_tbc_maps(fb_example_stack("washington"), fb_model_pretrained())
crop <- terra::as.matrix(maps[["cropland"]], wide = TRUE) > 0.5
max(fb_components(crop))
#> [1] 27
```
