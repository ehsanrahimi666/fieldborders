# Field objects or polygons over the image

Field objects or polygons over the image

## Usage

``` r
fb_plot_fields(
  fields,
  stack = NULL,
  date = NULL,
  reference = NULL,
  colour = "#FFE14D",
  fill_alpha = 0.25,
  title = NULL
)
```

## Arguments

- fields:

  Field objects (`SpatRaster` from
  [`fb_delineate()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_delineate.md))
  or polygons (`sf`).

- stack:

  Optional `fb_stack` shown in true colour underneath.

- date:

  Date of the background image (see
  [`fb_plot_rgb()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_plot_rgb.md)).

- reference:

  Optional reference polygons (`sf`), drawn as dashed outlines.

- colour:

  Outline colour of the fields.

- fill_alpha:

  Opacity of the field fill (0 for outlines only).

- title:

  Plot title.

## Value

A `ggplot` object.

## Examples

``` r
s <- fb_example_stack("moghan")
m <- fb_model_pretrained()
fields <- fb_delineate(fb_tbc_maps(s, m), thresholds = m$thresholds)
fb_plot_fields(fields, s, date = 7)

# with reference fields (dashed)
s2 <- fb_example_stack("california")
f2 <- fb_delineate(fb_tbc_maps(s2, m), thresholds = m$thresholds)
ref_poly <- sf::st_read(fb_example_files("california")$fields, quiet = TRUE)
fb_plot_fields(f2, s2, date = 7, reference = ref_poly)
```
