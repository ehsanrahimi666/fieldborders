# Download the PRUE deep model for R

Downloads the Fields of The World PRUE EfficientNet-B3 model trained on
CC-BY data (release v3.1), exported to TorchScript so that it runs with
the R `torch` package without Python. The file (about 54 MB) is cached
and verified by its MD5 checksum (SHA-256
9bd353b83826e84ab7c55173e9399674c778c729bf25075e2ca2d977ea33e876).

## Usage

``` r
fb_prue_download(
  dir = tools::R_user_dir("fieldborders", "cache"),
  url = prue_url,
  overwrite = FALSE
)
```

## Arguments

- dir:

  Cache directory.

- url:

  Download address of the TorchScript file (by default the release asset
  of the package on GitHub).

- overwrite:

  Download again even if a verified copy exists.

## Value

Path of the model file.

## References

Kerner, H. et al. (2025) Fields of The World: a machine learning
benchmark dataset for global agricultural field boundary segmentation.
Proceedings of the AAAI Conference on Artificial Intelligence 39,
28151-28159.
[doi:10.1609/aaai.v39i27.35034](https://doi.org/10.1609/aaai.v39i27.35034)

## Examples

``` r
if (FALSE) { # \dontrun{
# downloads about 54 MB once; later calls return the cached file
f <- fb_prue_download()
f
} # }
```
