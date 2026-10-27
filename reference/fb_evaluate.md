# Object-level accuracy of field delineation

Compares predicted field objects with reference fields using the object
metric of the Fields of The World benchmark. Reference objects are the
4-connected components of field pixels; predicted objects are the
4-connected components of each label. A reference and a predicted object
match when their intersection over union exceeds `iou` (with
`iou >= 0.5` every match is one-to-one). Unmatched predicted objects
with more than half of their pixels unlabelled (class 3) are not counted
as false positives (`obj_fp`); `obj_fp_all` counts all of them.

## Usage

``` r
fb_evaluate(
  reference,
  fields,
  iou = 0.5,
  pixel_area = NA_real_,
  size_breaks_ha = c(0, 1, 5, 20, 50, Inf),
  field = 1L,
  unlabelled = 3L
)
```

## Arguments

- reference:

  Reference classes: a raster from
  [`fb_reference()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_reference.md)
  (its `class` layer is used) or an integer matrix (0 background, 1
  field, 2 boundary, 3 unlabelled).

- fields:

  Predicted objects: a raster from
  [`fb_delineate()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_delineate.md)
  or an integer matrix.

- iou:

  Matching threshold (at least 0.5).

- pixel_area:

  Pixel area in square metres for the size classes; computed from the
  raster when `reference` is a `SpatRaster`.

- size_breaks_ha:

  Breaks of the reference-field size classes in hectares.

- field, unlabelled:

  Class codes.

## Value

A one-row data frame of counts: pixel `tp`, `fp`, `fn`; objects
`obj_tp`, `obj_fp`, `obj_fp_all`, `obj_fn`, `n_pred`; and reference
fields and matches per size class (`ref_s<k>`, `hit_s<k>`). Summarise
with
[`fb_accuracy()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_accuracy.md).

## Examples

``` r
s <- fb_example_stack("california")
f <- fb_example_files("california")
ref <- fb_reference(sf::st_read(f$fields, quiet = TRUE), s)
m <- fb_model_pretrained("california")
fields <- fb_delineate(fb_tbc_maps(s, m), thresholds = m$thresholds)
ev <- fb_evaluate(ref, fields)
ev
#>      tp   fp   fn obj_tp obj_fn obj_fp obj_fp_all n_pred ref_s1 hit_s1 ref_s2
#> 1 26370 2357 1000     10      1      2          2     12      1      0      4
#>   hit_s2 ref_s3 hit_s3 ref_s4 hit_s4 ref_s5 hit_s5
#> 1      4      6      6      0      0      0      0
fb_accuracy(ev)
#>   tiles pixel_precision pixel_recall pixel_iou reference_fields
#> 1     1       0.9179518    0.9634636 0.8870724               11
#>   predicted_fields obj_precision obj_recall    obj_f1 ref_s1 recall_s1 ref_s2
#> 1               12     0.8333333  0.9090909 0.8695652      1         0      4
#>   recall_s2 ref_s3 recall_s3 ref_s4 recall_s4 ref_s5 recall_s5
#> 1         1      6         1      0        NA      0        NA
```
