# Final field objects from a label matrix

Keeps labelled pixels flagged in `keep`, closes one-pixel cracks
enclosed by a single label, and separates touching objects by a
one-pixel line so that every object is a separate 4-connected component.

## Usage

``` r
fb_finalise(labels, keep)
```

## Arguments

- labels:

  Integer label matrix.

- keep:

  Logical matrix of pixels that belong to objects.

## Value

Integer label matrix of final objects.

## Examples

``` r
lab <- matrix(rep(1:2, each = 50), 10, 10)
table(fb_finalise(lab, lab > 0))
#> 
#>  0  1  2 
#> 10 50 40 
# watershed basins of the Washington example turned into separate objects
maps <- fb_tbc_maps(fb_example_stack("washington"), fb_model_pretrained())
E <- terra::as.matrix(maps[["edge"]], wide = TRUE)
F <- terra::as.matrix(maps[["cropland"]], wide = TRUE)
ws <- fb_watershed(E, fb_components(F > 0.7 & E < 0.3), mask = F > 0.5)
obj <- fb_finalise(ws, F > 0.5)
max(fb_components(obj))
#> [1] 73
```
