# Select features from a contrast ranking

Walks down the ranking and keeps a feature unless the absolute Spearman
correlation of its temporal maximum with an already selected feature
exceeds `max_cor`.

## Usage

``` r
fb_select_features(contrast, k = 8L, max_cor = 0.9, n_sub = 100000L, seed = 1L)
```

## Arguments

- contrast:

  An `fb_contrast` object from
  [`fb_rank_contrast()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_rank_contrast.md).

- k:

  Number of features to select.

- max_cor:

  Maximum absolute Spearman correlation between selected features.

- n_sub:

  Number of pairs used for the correlations.

- seed:

  Random seed for the subsample.

## Value

Character vector of selected feature names, in rank order.

## Examples

``` r
s <- fb_example_stack("california")
f <- fb_example_files("california")
ref <- fb_reference(sf::st_read(f$fields, quiet = TRUE), s)
rk <- fb_rank_contrast(s, ref, n_pairs = 1000)
fb_select_features(rk, k = 5)
#> [1] "ND(B05,B08)" "ND(B06,B08)" "ND(B04,B08)" "B08"         "ND(B03,B08)"
```
