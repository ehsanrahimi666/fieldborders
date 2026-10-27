# Accuracy metrics from evaluation counts

Pools the counts of
[`fb_evaluate()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_evaluate.md)
over tiles (optionally by group) and computes pixel precision, recall
and IoU and object precision, recall and F1.

## Usage

``` r
fb_accuracy(counts, by = NULL)
```

## Arguments

- counts:

  Data frame of counts, one row per tile, possibly with grouping
  columns.

- by:

  Grouping column names, or `NULL` for one pooled summary.

## Value

A data frame of metrics; `ref_s<k>` gives the number of reference fields
in size class `k` and `recall_s<k>` their recall (`NA` if the class
holds no field).

## Examples

``` r
s <- fb_example_stack("california")
f <- fb_example_files("california")
ref <- fb_reference(sf::st_read(f$fields, quiet = TRUE), s)
# fields from the PRUE probabilities of the example, with the thresholds of the fusion model
dl <- fb_read_probabilities(f$prue)
th <- fb_model_pretrained("california", "fusion")$thresholds
tuned <- fb_delineate(dl, thresholds = th)
unfiltered <- fb_delineate(dl, thresholds = th, min_size = 0)
ev <- rbind(cbind(method = "tuned thresholds", fb_evaluate(ref, tuned)),
            cbind(method = "no size filter", fb_evaluate(ref, unfiltered)))
fb_accuracy(ev, by = "method")
#>             method tiles pixel_precision pixel_recall pixel_iou
#> 1   no size filter     1       0.9211103    0.9820241 0.9058372
#> 2 tuned thresholds     1       0.9252005    0.9820241 0.9097925
#>   reference_fields predicted_fields obj_precision obj_recall    obj_f1 ref_s1
#> 1               11               10         0.700  0.6363636 0.6666667      1
#> 2               11                8         0.875  0.6363636 0.7368421      1
#>   recall_s1 ref_s2 recall_s2 ref_s3 recall_s3 ref_s4 recall_s4 ref_s5 recall_s5
#> 1         0      4         1      6       0.5      0        NA      0        NA
#> 2         0      4         1      6       0.5      0        NA      0        NA
```
