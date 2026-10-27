# Monthly Sentinel-2 time series for an area

Searches a STAC catalogue (by default Microsoft Planetary Computer) for
Sentinel-2 Level-2A scenes, keeps per calendar month the scene with the
smallest share of invalid pixels in the area (among the `max_per_month`
scenes with the least scene-level cloud cover) (scene classification
classes 0, 1, 3, 8, 9 and 10: no data, saturated, cloud shadow, medium
and high cloud probability, thin cirrus), skips months with more than
`max_invalid` invalid pixels, and resamples the bands bilinearly (the
scene classification by nearest neighbour) to a common grid. The
radiometric offset of processing baseline 04.00 and later is removed.

## Usage

``` r
fb_s2_monthly(
  aoi,
  start,
  end,
  bands = c("B02", "B03", "B04", "B05", "B06", "B07", "B08", "B8A", "B11", "B12"),
  resolution = 5,
  max_cloud = 60,
  max_invalid = 0.2,
  max_per_month = 4L,
  invalid_classes = c(0, 1, 3, 8, 9, 10),
  stac_url = "https://planetarycomputer.microsoft.com/api/stac/v1",
  collection = "sentinel-2-l2a",
  dir = NULL,
  verbose = TRUE
)
```

## Arguments

- aoi:

  Area of interest: an `sf` or `SpatVector` object, a numeric bounding
  box `c(xmin, ymin, xmax, ymax)` in longitude and latitude, or a
  `SpatRaster` whose grid is used as is.

- start, end:

  First and last date of the period (`"YYYY-MM-DD"`).

- bands:

  Sentinel-2 bands to read.

- resolution:

  Pixel size in metres of the output grid (ignored when `aoi` is a
  `SpatRaster`); the grid uses the UTM zone of the area's centre. The
  pretrained models were developed on Sentinel-2 resampled to about 5 m
  (the Fields of The World chip grid), which is the default.

- max_cloud:

  Upper limit of the scene-level cloud cover (percent) in the search.

- max_invalid:

  Largest share of invalid pixels in the area for a month to be kept.

- max_per_month:

  Number of scenes per month, those with the least scene-level cloud
  cover, whose scene classification is read to find the clearest one.

- invalid_classes:

  Scene classification classes treated as invalid; add 11 to treat snow
  as invalid.

- stac_url, collection:

  STAC API and collection.

- dir:

  Optional directory where the stack is written
  ([`fb_write_stack()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_write_stack.md)).

- verbose:

  Print progress.

## Value

An `fb_stack` of digital numbers (`scale = 10000`) with clear-sky masks;
the scene identifiers are stored in the attribute `"items"`.

## Details

The scene classification misses some clouds, haze and cloud shadows,
which then enter the series as clear pixels; look at the images (for
example with
[`fb_plot_rgb()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_plot_rgb.md)
for every date) and drop affected dates with
[`fb_subset_dates()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_subset_dates.md).
In the southern hemisphere, choose a period that holds the summer
growing season, for example July to June.

## Examples

``` r
if (FALSE) { # \dontrun{
# about 1.6 km x 1.6 km of centre-pivot fields near Jovein, Iran; one scene per month of
# 2024 (needs an internet connection; takes a few minutes)
s <- fb_s2_monthly(c(57.436, 36.606, 57.454, 36.620), "2024-01-01", "2024-12-31")
s
fb_plot_rgb(s, date = 7)
} # }
```
