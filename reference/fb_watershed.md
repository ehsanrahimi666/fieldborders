# Marker-controlled watershed

Floods `elev` from the markers in order of increasing value
(4-connectivity), within `mask`.

## Usage

``` r
fb_watershed(elev, markers, mask = NULL, lines = FALSE)
```

## Arguments

- elev:

  Numeric matrix (low values are field interiors, high values
  boundaries).

- markers:

  Integer matrix of marker labels (0 = none).

- mask:

  Logical matrix of pixels that may be labelled; defaults to all.

- lines:

  If `TRUE`, pixels where basins meet are left unlabelled.

## Value

Integer label matrix (0 = unlabelled).

## Examples

``` r
# two basins separated by a ridge in column 10
e <- outer(1:20, 1:20, function(i, j) as.numeric(j == 10))
mk <- matrix(0L, 20, 20); mk[10, 5] <- 1L; mk[10, 15] <- 2L
table(fb_watershed(e, mk))
#> 
#>   1   2 
#> 200 200 
# fields of the Washington example: seeds inside fields, flooding of the edge map
maps <- fb_tbc_maps(fb_example_stack("washington"), fb_model_pretrained())
E <- terra::as.matrix(maps[["edge"]], wide = TRUE)
F <- terra::as.matrix(maps[["cropland"]], wide = TRUE)
seeds <- fb_components(F > 0.7 & E < 0.3)
ws <- fb_watershed(E, seeds, mask = F > 0.5)
length(unique(ws[ws > 0]))
#> [1] 73
```
