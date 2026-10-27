# Fit a fusion of TBC maps and deep-model probabilities

Two logistic regressions are fitted on reference pixels: boundary versus
field interior on `logit P(boundary)` of the deep model and
`logit(edge)` of TBC, and field or boundary versus background on
`logit P(field + boundary)` and `logit(cropland)`, each with a ridge
penalty of 1 on the slopes.

## Usage

``` r
fb_fit_fusion(tbc_maps, dl_maps, references, n_pixels = 20000L, seed = 1L)
```

## Arguments

- tbc_maps:

  A `SpatRaster` from
  [`fb_tbc_maps()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_tbc_maps.md),
  or a list of them.

- dl_maps:

  Deep-model probabilities with layers `background`, `field`, `boundary`
  ([`fb_prue_predict()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_prue_predict.md),
  [`fb_read_probabilities()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_read_probabilities.md)),
  or a list of them.

- references:

  Reference rasters from
  [`fb_reference()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_reference.md),
  or a list of them.

- n_pixels:

  Maximum number of pixels per class and tile.

- seed:

  Random seed for the pixel sample.

## Value

An object of class `fb_fusion`.

## Examples

``` r
s <- fb_example_stack("california")
f <- fb_example_files("california")
ref <- fb_reference(sf::st_read(f$fields, quiet = TRUE), s)
tbc <- fb_tbc_maps(s, fb_model_pretrained("california"))
dl <- fb_read_probabilities(f$prue)
fu <- fb_fit_fusion(tbc, dl, ref, n_pixels = 5000)
fu
#> <fb_fusion> logistic fusion of deep-model and TBC maps
#>   boundary: -0.180 + 0.121 logit P(boundary) + 0.597 logit(edge)
#>   field   : -1.643 + 0.218 logit P(field + boundary) + 0.943 logit(cropland)
#>   thresholds: t_edge 0.40, t_field 0.50, min_size 50 pixels
```
