# Paired bootstrap of accuracy differences between methods

Tiles are resampled with replacement (within strata, if given); the same
resampled tiles are used for both methods of a comparison.

## Usage

``` r
fb_bootstrap(
  counts,
  comparisons,
  metric = c("obj_f1", "obj_recall", "obj_precision"),
  B = 2000L,
  seed = 1L
)
```

## Arguments

- counts:

  Data frame with columns `tile`, `method`, optionally `stratum`, and
  the count columns of
  [`fb_evaluate()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_evaluate.md).

- comparisons:

  Two-column matrix (or a length-2 vector) of method names; the
  difference is first minus second.

- metric:

  `"obj_f1"`, `"obj_recall"` or `"obj_precision"`.

- B:

  Number of bootstrap resamples.

- seed:

  Random seed.

## Value

A data frame with the observed difference and the 2.5 and 97.5
percentiles of the bootstrap differences.

## Examples

``` r
s <- fb_example_stack("california")
f <- fb_example_files("california")
ref <- fb_reference(sf::st_read(f$fields, quiet = TRUE), s)
m <- fb_model_pretrained("general")
fu <- fb_model_pretrained("general", "fusion")
maps <- fb_tbc_maps(s, m)
fused <- fb_fuse(maps, fb_read_probabilities(f$prue), fu)
fields <- list(TBC = fb_delineate(maps, thresholds = m$thresholds),
               FUSION = fb_delineate(fused, thresholds = fu$thresholds))
# the example window cut into four quarters, standing in for tiles
e <- as.vector(terra::ext(ref)); xm <- mean(e[1:2]); ym <- mean(e[3:4])
quarters <- list(c(e[1], xm, ym, e[4]), c(xm, e[2], ym, e[4]),
                 c(e[1], xm, e[3], ym), c(xm, e[2], e[3], ym))
counts <- do.call(rbind, lapply(seq_along(quarters), function(k) {
  q <- terra::ext(quarters[[k]])
  do.call(rbind, lapply(names(fields), function(nm)
    cbind(tile = k, method = nm, fb_evaluate(terra::crop(ref, q), terra::crop(fields[[nm]], q)))))
}))
fb_bootstrap(counts, c("FUSION", "TBC"), B = 500)
#>     comparison metric difference         lo   hi
#> 1 FUSION - TBC obj_f1  0.1569311 0.07692308 0.25
```
