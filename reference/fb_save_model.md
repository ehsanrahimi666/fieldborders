# Save and load a model

Save and load a model

## Usage

``` r
fb_save_model(model, file)

fb_load_model(file)
```

## Arguments

- model:

  An `fb_model` or `fb_fusion` object.

- file:

  Path of the `.rds` file.

## Value

`fb_save_model()` returns the file path invisibly; `fb_load_model()` the
model.

## Examples

``` r
m <- fb_model_pretrained("california")
f <- tempfile(fileext = ".rds")
fb_save_model(m, f)
fb_load_model(f)
#> <fb_model> temporal boundary contrast
#>   bands            : B02, B03, B04, B05, B06, B07, B08, B8A, B11, B12 
#>   edge features    : ND(B03,B08) | ND(B02,B07) | B02 | ND(B02,B11) | ND(B04,B11) | ND(B03,B11) | ND(B05,B08) | B08 
#>   cropland learner : xgboost 
#>   training         : 44 tiles, 248,301 pairs (72,301 across), 880,000 pixels
#>   in-sample AUC    : edge 0.911, cropland 0.983
#>   thresholds       : t_edge 0.60, t_field 0.30, min_size 400 pixels
```
