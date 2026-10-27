# Tune delineation thresholds on reference tiles

Evaluates every combination of thresholds on tiles with reference
rasters and returns the object-level accuracy of each combination,
pooled over tiles, with the best combination first.

## Usage

``` r
fb_tune(
  maps,
  references,
  t_edge = c(0.2, 0.3, 0.4, 0.5, 0.6),
  t_field = c(0.5, 0.7, 0.9),
  min_size = c(0, 50, 100, 200),
  iou = 0.5
)
```

## Arguments

- maps:

  A map `SpatRaster` (see
  [`fb_delineate()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_delineate.md))
  or a list of them.

- references:

  Reference rasters from
  [`fb_reference()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_reference.md),
  one per map.

- t_edge, t_field, min_size:

  Candidate values.

- iou:

  Intersection-over-union required for a match.

## Value

A data frame with one row per combination: thresholds, object precision,
recall and F1, sorted by decreasing F1.

## Examples

``` r
s <- fb_example_stack("california")
f <- fb_example_files("california")
ref <- fb_reference(sf::st_read(f$fields, quiet = TRUE), s)
maps <- fb_tbc_maps(s, fb_model_pretrained("california"))
tn <- fb_tune(maps, ref, t_edge = c(0.3, 0.5), t_field = c(0.5, 0.7), min_size = c(0, 50))
head(tn)
#>   t_edge t_field min_size tp fp fn precision    recall        f1
#> 1    0.5     0.5       50  9  5  2 0.6428571 0.8181818 0.7200000
#> 2    0.5     0.5        0  9  8  2 0.5294118 0.8181818 0.6428571
#> 3    0.5     0.7       50  9  8  2 0.5294118 0.8181818 0.6428571
#> 4    0.5     0.7        0  9 10  2 0.4736842 0.8181818 0.6000000
#> 5    0.3     0.5       50  8 24  3 0.2500000 0.7272727 0.3720930
#> 6    0.3     0.7       50  8 24  3 0.2500000 0.7272727 0.3720930
```
