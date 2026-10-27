# Delineate field objects from edge and cropland maps

The object procedure validated with the package: markers are the
4-connected components of `{cropland > t_field and edge < t_edge}` with
at least `min_marker` pixels; a marker-controlled watershed on the edge
map, within `{cropland > 0.5}`, assigns the remaining cropland pixels;
touching objects are separated by one-pixel lines and objects smaller
than `min_size` pixels are removed.

## Usage

``` r
fb_delineate(
  maps,
  t_edge = NULL,
  t_field = NULL,
  min_size = NULL,
  min_area = NULL,
  min_marker = 20L,
  thresholds = NULL
)
```

## Arguments

- maps:

  A `SpatRaster` with layers `edge` and `cropland`
  ([`fb_tbc_maps()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_tbc_maps.md),
  [`fb_fuse()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_fuse.md))
  or deep-model probabilities with layers `background`, `field` and
  `boundary` (then `edge = P(boundary)` and
  `cropland = P(field) + P(boundary)`).

- t_edge, t_field:

  Marker thresholds.

- min_size:

  Minimum object size in pixels.

- min_area:

  Optional minimum object area in square metres; overrides `min_size`.

- min_marker:

  Minimum marker size in pixels.

- thresholds:

  Optional list with `t_edge`, `t_field`, `min_size` and optionally
  `min_area` (for example the `thresholds` element of a model), used for
  arguments that are not given; a `min_area` in the list takes
  precedence over its `min_size`, so that the minimum field size does
  not depend on the pixel size.

## Value

A `SpatRaster` (`field_id`) of field objects, 0 outside fields.

## Examples

``` r
s <- fb_example_stack("california")
m <- fb_model_pretrained("california")
maps <- fb_tbc_maps(s, m)
fields <- fb_delineate(maps, thresholds = m$thresholds)
fb_plot_fields(fields, s, date = 7)

# thresholds can also be given one by one, and the minimum size as an area
fields2 <- fb_delineate(maps, t_edge = 0.3, t_field = 0.7, min_area = 5000)
```
