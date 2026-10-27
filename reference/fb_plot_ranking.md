# Feature ranking by border contrast

Feature ranking by border contrast

## Usage

``` r
fb_plot_ranking(contrast, n = 20, selected = NULL)
```

## Arguments

- contrast:

  An `fb_contrast` object from
  [`fb_rank_contrast()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_rank_contrast.md).

- n:

  Number of top features shown.

- selected:

  Optional names of selected features, highlighted.

## Value

A `ggplot` object.

## Examples

``` r
s <- fb_example_stack("california")
f <- fb_example_files("california")
ref <- fb_reference(sf::st_read(f$fields, quiet = TRUE), s)
rk <- fb_rank_contrast(s, ref, n_pairs = 1000)
fb_plot_ranking(rk, n = 15, selected = fb_select_features(rk, k = 5))
```
