# Run the PRUE deep model on a stack

Applies the Fields of The World PRUE model to two dates of a stack, as
the model was trained: red, green, blue and near-infrared reflectance of
the earlier date, then of the later date, divided by 0.3, rows ordered
from south to north, 256-pixel windows with a stride of 128 pixels whose
softmax probabilities are averaged. On the 54 California test tiles of
the validation, its probabilities differed from those of the Python
implementation by at most 1.2e-4 (mean absolute difference 7e-8).

## Usage

``` r
fb_prue_predict(
  stack,
  months = c(3, 7),
  model = fb_prue_download(),
  window = 256L,
  stride = 128L,
  device = "cpu"
)
```

## Arguments

- stack:

  An `fb_stack` with bands `B04`, `B03`, `B02`, `B08`.

- months:

  Calendar months of the two input dates, the earlier first in the
  season (for example `c(3, 7)` in the northern hemisphere, `c(9, 1)` in
  the southern). For each month the clearest date of that month is used,
  or of an adjacent month.

- model:

  TorchScript model file from
  [`fb_prue_download()`](https://ehsanrahimi666.github.io/fieldborders/reference/fb_prue_download.md).

- window, stride:

  Window size and stride in pixels.

- device:

  `"cpu"` or `"cuda"`.

## Value

A `SpatRaster` with layers `background`, `field` and `boundary`.

## Details

The model sees each pixel in the context of its window, so probabilities
depend on the surrounding image: areas smaller than a window are padded
by reflection, and the output for a small area can differ from the
output for the same pixels within a larger area. Prefer areas of at
least 256 x 256 pixels (about 1.3 km at 5 m).

## Examples

``` r
# \donttest{
if (requireNamespace("torch", quietly = TRUE) && torch::torch_is_installed()) {
  s <- fb_example_stack("california")
  p <- fb_prue_predict(s, months = c(3, 7))     # downloads the model on first use
  fb_plot_maps(p)
}
# }
```
