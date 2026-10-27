# Train a temporal boundary contrast (TBC) model

Fits the two components of TBC on training tiles with reference fields:

- the edge model, a logistic regression of across versus within pairs on
  the temporal maximum and mean contrasts of the `k` selected features
  (standardised; missing summaries set to the training mean);

- the cropland model, gradient-boosted trees (`xgboost`), a probability
  random forest (`ranger`) or a logistic regression of field-interior
  versus background pixels on the 10th, 50th and 90th percentiles and
  the standard deviation over clear dates of the bands, NDVI,
  ND(B08,B11) and ND(B11,B12).

## Usage

``` r
fb_train(
  stacks,
  references,
  features = NULL,
  strata = NULL,
  contrast = NULL,
  k = 8L,
  max_cor = 0.9,
  n_pairs = 4000L,
  n_pixels = 20000L,
  learner = c("xgboost", "ranger", "glm"),
  num_trees = 100L,
  min_node_size = 10L,
  thresholds = list(t_edge = 0.5, t_field = 0.5, min_size = 50L),
  seed = 1L,
  threads = 1L
)
```

## Arguments

- stacks:

  An `fb_stack` or a list of them (training tiles). For many tiles, list
  elements may be functions without arguments that return the stack;
  each tile is then loaded only while it is processed.

- references:

  A reference raster from
  [`fb_reference()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_reference.md)
  or a list of them, one per stack (or functions returning them).

- features:

  Candidate features from
  [`fb_feature_set()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_feature_set.md);
  by default the bands and all normalised differences of the first
  stack's bands.

- strata:

  Optional stratum label per stack; the AUC is averaged over strata.

- contrast:

  Optional result of
  [`fb_rank_contrast()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_rank_contrast.md)
  on the same data (avoids recomputing the pair summaries).

- k, max_cor:

  Feature selection settings passed to
  [`fb_select_features()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_select_features.md).

- n_pairs:

  Maximum number of across and of within pairs per stack.

- n_pixels:

  Maximum number of field and of background pixels per stack for the
  cropland model.

- learner:

  Cropland learner: `"xgboost"` (gradient-boosted trees, default, as in
  the validation of the method), `"ranger"` (random forest) or `"glm"`
  (ridge logistic regression).

- num_trees:

  Number of trees (random forest) or boosting rounds (`xgboost`).

- min_node_size:

  Minimum node size of the random forest; larger values give smaller
  models.

- thresholds:

  Default object thresholds stored with the model (see
  [`fb_delineate()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_delineate.md));
  tune them with
  [`fb_tune()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_tune.md).

- seed:

  Random seed for pair sampling.

- threads:

  Number of threads for the cropland learner.

## Value

An object of class `fb_model`.

## Details

The logistic regressions carry a ridge penalty of 1 on the slopes (the
default of scikit-learn's `LogisticRegression`), which keeps them finite
when the classes are separable.

## Examples

``` r
s <- fb_example_stack("california")
f <- fb_example_files("california")
ref <- fb_reference(sf::st_read(f$fields, quiet = TRUE), s)
m <- fb_train(s, ref, n_pairs = 1000, n_pixels = 2000, num_trees = 50)
m
#> <fb_model> temporal boundary contrast
#>   bands            : B02, B03, B04, B05, B06, B07, B08, B8A, B11, B12 
#>   edge features    : ND(B05,B08) | ND(B06,B08) | ND(B04,B08) | B08 | ND(B03,B08) | B04 | ND(B02,B08) | ND(B05,B8A) 
#>   cropland learner : xgboost 
#>   training         : 1 tiles, 1,034 pairs (34 across), 4,000 pixels
#>   in-sample AUC    : edge 0.998, cropland 1.000
#>   thresholds       : t_edge 0.50, t_field 0.50, min_size 50 pixels
```
