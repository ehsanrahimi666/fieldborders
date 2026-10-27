# Pretrained models

Models trained with
[`fb_train()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_train.md)
and
[`fb_fit_fusion()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_fit_fusion.md)
on the reference tiles of the validation, with delineation thresholds
tuned on separate tiles of the same regions:

## Usage

``` r
fb_model_pretrained(
  region = c("general", "california", "ftw"),
  type = c("tbc", "fusion")
)
```

## Arguments

- region:

  Model name.

- type:

  `"tbc"` for the TBC model, `"fusion"` for the fusion with the PRUE B3
  model (not available for `"ftw"`).

## Value

An `fb_model` or `fb_fusion` object.

## Details

- `"general"` (default): fitted on 44 tiles in California (2024) and 31
  tiles in Washington (2024 and 2025) together, thresholds tuned on 22
  and 15 further tiles; the model to use where no local reference fields
  exist.

- `"california"`: fitted on the 44 California tiles, thresholds tuned on
  22.

- `"ftw"`: fitted on 89 Fields of The World benchmark chips from six
  countries, using the four 10 m bands only, thresholds tuned on the
  California and Washington tiles; in the validation, a model fitted
  this way transferred to annual crops but not to perennial crops.

The cropland learner of the `"general"` and `"california"` models was
chosen among ridge logistic regression, random forest and
gradient-boosted trees by object F1 on the tuning tiles
(gradient-boosted trees in both); the `"ftw"` model uses
gradient-boosted trees. The models were fitted on Sentinel-2 images
resampled to the Fields of The World chip grid (about 5 m); the minimum
field size is stored in pixels and as an area (`min_area`, square
metres), which
[`fb_delineate()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_delineate.md)
uses, so that it keeps its meaning at other pixel sizes. In all models
the tuned minimum field size is about 1.1 ha, the largest value of the
tuning grid, which suits the large fields of the tuning regions; where
fields are smaller, pass a smaller `min_area` to
[`fb_delineate()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_delineate.md).
The fusion models combine TBC with PRUE B3 probabilities from the March
and July scenes. The test tiles of the validation were not used to fit
or tune any model.

## Examples

``` r
fb_model_pretrained()
#> <fb_model> temporal boundary contrast
#>   bands            : B02, B03, B04, B05, B06, B07, B08, B8A, B11, B12 
#>   edge features    : ND(B03,B08) | ND(B02,B07) | B04 | ND(B04,B11) | ND(B03,B11) | ND(B08,B11) | B08 | ND(B02,B05) 
#>   cropland learner : xgboost 
#>   training         : 75 tiles, 467,670 pairs (167,670 across), 1,470,140 pixels
#>   in-sample AUC    : edge 0.902, cropland 0.968
#>   thresholds       : t_edge 0.60, t_field 0.30, min_size 400 pixels
fb_model_pretrained("california", "fusion")
#> <fb_fusion> logistic fusion of deep-model and TBC maps
#>   boundary: -0.899 + 0.044 logit P(boundary) + 0.978 logit(edge)
#>   field   : -0.230 + 0.095 logit P(field + boundary) + 1.063 logit(cropland)
#>   thresholds: t_edge 0.30, t_field 0.30, min_size 400 pixels
```
