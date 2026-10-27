# Area under the ROC curve

Probability that a random positive scores higher than a random negative
(ties count one half), computed from ranks.

## Usage

``` r
fb_auc(score, y)
```

## Arguments

- score:

  Numeric scores.

- y:

  Binary labels (1 positive, 0 negative).

## Value

The AUC, or `NA` if one class is missing.

## Examples

``` r
fb_auc(c(0.1, 0.4, 0.35, 0.8), c(0, 0, 1, 1))
#> [1] 0.75
```
