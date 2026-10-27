# Reference raster from field polygons

Rasterizes reference field polygons onto the grid of a stack or raster.
Field interiors are class 1, polygon outlines (burnt as one-pixel lines)
class 2, and the remaining pixels background (class 0) or, when only
some fields are mapped, unlabelled (class 3, ignored in training and in
false-positive counts).

## Usage

``` r
fb_reference(polygons, template, presence_only = FALSE)
```

## Arguments

- polygons:

  Reference fields as an `sf` object or a `SpatVector` of polygons, one
  feature per field.

- template:

  An `fb_stack` or `SpatRaster` defining the grid.

- presence_only:

  `TRUE` when pixels outside the polygons are not known to be background
  (for example when only one crop was mapped).

## Value

A `SpatRaster` with layers `class` (0 background, 1 field, 2 boundary, 3
unlabelled) and `field_id` (polygon number, 0 outside fields).

## Examples

``` r
f <- fb_example_files("california")
s <- fb_example_stack("california")
ref <- fb_reference(sf::st_read(f$fields, quiet = TRUE), s)
ref
#> class       : SpatRaster
#> size        : 192, 192, 2  (nrow, ncol, nlyr)
#> resolution  : 5.4054e-05, 5.4054e-05  (x, y)
#> extent      : -121.9666, -121.9562, 39.03996, 39.05034  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
#> source(s)   : memory
#> varnames    : s2_2024-01-29
#>               s2_2024-01-29
#> names       : class, field_id
#> min values  :     0,        0
#> max values  :     2,       10
terra::freq(ref$class)
#>   layer value count
#> 1     1     0  7691
#> 2     1     1 27370
#> 3     1     2  1803
```
