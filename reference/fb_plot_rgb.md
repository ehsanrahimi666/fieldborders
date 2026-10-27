# True-colour image of one date

True-colour image of one date

## Usage

``` r
fb_plot_rgb(
  stack,
  date = NULL,
  bands = c("B04", "B03", "B02"),
  stretch = c(0.02, 0.98),
  title = NULL,
  max_cells = 1e+06
)
```

## Arguments

- stack:

  An `fb_stack`.

- date:

  Date (or index of the date) to show; by default the date with the most
  clear pixels.

- bands:

  Red, green and blue bands.

- stretch:

  Lower and upper quantiles of the linear stretch (common to the three
  bands).

- title:

  Plot title; by default the date.

- max_cells:

  Images with more cells are averaged in blocks for display.

## Value

A `ggplot` object; `sf` layers can be added with
[`ggplot2::geom_sf()`](https://ggplot2.tidyverse.org/reference/ggsf.html).

## Examples

``` r
fb_plot_rgb(fb_example_stack("california"), date = 7)

# false colour: near infrared, red, green
fb_plot_rgb(fb_example_stack("washington"), date = 7, bands = c("B08", "B04", "B03"))
```
