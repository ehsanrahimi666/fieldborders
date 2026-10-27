# Field polygons from field objects

Converts field objects to polygons with their area, perimeter,
compactness and, optionally, mean edge and cropland probability.

## Usage

``` r
fb_polygons(fields, maps = NULL, simplify = 0, min_area = 0)
```

## Arguments

- fields:

  A `SpatRaster` of field objects from
  [`fb_delineate()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_delineate.md).

- maps:

  Optional map `SpatRaster` whose layer means are added per field.

- simplify:

  Simplification tolerance in map units (`0` for none); in geographic
  coordinates a value around half a pixel removes the stair steps of
  pixel edges.

- min_area:

  Minimum polygon area in square metres.

## Value

An `sf` data frame with `field_id`, `area_ha`, `perimeter_m`,
`compactness` (4 pi area / perimeter^2) and map means.

## Examples

``` r
s <- fb_example_stack("california")
m <- fb_model_pretrained("california")
maps <- fb_tbc_maps(s, m)
p <- fb_polygons(fb_delineate(maps, thresholds = m$thresholds), maps)
head(p)
#> Simple feature collection with 6 features and 6 fields
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: -121.9666 ymin: 39.03996 xmax: -121.9621 ymax: 39.05034
#> Geodetic CRS:  WGS 84
#>   field_id   area_ha perimeter_m compactness mean_edge mean_cropland
#> 1        1  3.577149   1452.3815   0.2131010 0.3279564     0.7850929
#> 2        2  2.640183   1195.0869   0.2322977 0.5549999     0.8590490
#> 3        3  2.076336   1129.7423   0.2044320 0.4741372     0.8755133
#> 4        4  2.749828    860.8495   0.4662953 0.5484452     0.9355438
#> 5        5 10.479377   1846.0472   0.3864201 0.4605918     0.9127277
#> 6        6 10.962486   1904.7872   0.3796872 0.4467446     0.9246400
#>                         geometry
#> 1 POLYGON ((-121.9666 39.0503...
#> 2 POLYGON ((-121.9666 39.0480...
#> 3 POLYGON ((-121.9666 39.0446...
#> 4 POLYGON ((-121.9657 39.0412...
#> 5 POLYGON ((-121.9651 39.0482...
#> 6 POLYGON ((-121.966 39.04466...
summary(p$area_ha)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>   2.076   2.767   5.775   6.717  10.600  13.768 
```
