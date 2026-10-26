#' Read deep-model class probabilities
#'
#' Reads a three-layer raster of class probabilities (background, field, boundary), for
#' example written by the Fields of The World tools or by [fb_prue_predict()].
#'
#' @param x A raster file or `SpatRaster` with three layers.
#' @param layers Order of the classes in `x`.
#' @return A `SpatRaster` with layers `background`, `field` and `boundary`.
#' @examples
#' p <- fb_read_probabilities(fb_example_files("california")$prue)
#' p
#' @export
fb_read_probabilities <- function(x, layers = c("background", "field", "boundary")) {
  r <- if (inherits(x, "SpatRaster")) x else terra::rast(x)
  if (terra::nlyr(r) != 3L) stop("a three-layer probability raster is expected")
  names(r) <- layers
  r[[c("background", "field", "boundary")]]
}

#' Download the PRUE deep model for R
#'
#' Downloads the Fields of The World PRUE EfficientNet-B3 model trained on CC-BY data
#' (release v3.1), exported to TorchScript so that it runs with the R `torch` package
#' without Python. The file (about 54 MB) is cached and verified by its MD5 checksum
#' (SHA-256 9bd353b83826e84ab7c55173e9399674c778c729bf25075e2ca2d977ea33e876).
#'
#' @param dir Cache directory.
#' @param url Download address of the TorchScript file (by default the release asset of
#'   the package on GitHub).
#' @param overwrite Download again even if a verified copy exists.
#' @return Path of the model file.
#' @references Kerner, H. et al. (2025) Fields of The World: a machine learning benchmark
#'   dataset for global agricultural field boundary segmentation. Proceedings of the AAAI
#'   Conference on Artificial Intelligence 39, 28151-28159. \doi{10.1609/aaai.v39i27.35034}
#' @examples
#' \dontrun{
#' # downloads about 54 MB once; later calls return the cached file
#' f <- fb_prue_download()
#' f
#' }
#' @export
fb_prue_download <- function(dir = tools::R_user_dir("fieldborders", "cache"), url = prue_url,
                             overwrite = FALSE) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  f <- file.path(dir, basename(url))
  if (!overwrite && file.exists(f) && identical(unname(tools::md5sum(f)), prue_md5)) return(f)
  old <- options(timeout = max(600, getOption("timeout")))
  on.exit(options(old))
  utils::download.file(url, f, mode = "wb", quiet = FALSE)
  if (!identical(unname(tools::md5sum(f)), prue_md5)) {
    unlink(f)
    stop("the downloaded model is incomplete or altered (MD5 checksum differs); try again")
  }
  f
}

# MD5 checksum and download address of the TorchScript export of PRUE EfficientNet-B3 (CC-BY, v3.1)
prue_md5 <- "259cdd3c1fc5c184b7f564c9901f0056"
prue_url <- paste0("https://github.com/ehsanrahimi666/fieldborders/releases/download/v1.0.0/",
                   "prue_b3_ccby_torchscript.pt")

#' Run the PRUE deep model on a stack
#'
#' Applies the Fields of The World PRUE model to two dates of a stack, as the model was
#' trained: red, green, blue and near-infrared reflectance of the earlier date, then of
#' the later date, divided by 0.3, rows ordered from south to north, 256-pixel windows
#' with a stride of 128 pixels whose softmax probabilities are averaged. On the 54
#' California test tiles of the validation, its probabilities differed from those of the
#' Python implementation by at most 1.2e-4 (mean absolute difference 7e-8).
#'
#' The model sees each pixel in the context of its window, so probabilities depend on
#' the surrounding image: areas smaller than a window are padded by reflection, and the
#' output for a small area can differ from the output for the same pixels within a larger
#' area. Prefer areas of at least 256 x 256 pixels (about 1.3 km at 5 m).
#'
#' @param stack An `fb_stack` with bands `B04`, `B03`, `B02`, `B08`.
#' @param months Calendar months of the two input dates, the earlier first in the
#'   season (for example `c(3, 7)` in the northern hemisphere, `c(9, 1)` in the southern).
#'   For each month the clearest date of that month is used, or of an adjacent month.
#' @param model TorchScript model file from [fb_prue_download()].
#' @param window,stride Window size and stride in pixels.
#' @param device `"cpu"` or `"cuda"`.
#' @return A `SpatRaster` with layers `background`, `field` and `boundary`.
#' @examples
#' \donttest{
#' if (requireNamespace("torch", quietly = TRUE) && torch::torch_is_installed()) {
#'   s <- fb_example_stack("california")
#'   p <- fb_prue_predict(s, months = c(3, 7))     # downloads the model on first use
#'   fb_plot_maps(p)
#' }
#' }
#' @export
fb_prue_predict <- function(stack, months = c(3, 7), model = fb_prue_download(), window = 256L, stride = 128L,
                            device = "cpu") {
  if (!requireNamespace("torch", quietly = TRUE)) stop("fb_prue_predict needs the torch package")
  stopifnot(inherits(stack, "fb_stack"))
  need <- c("B04", "B03", "B02", "B08")
  if (!all(need %in% stack$bands)) stop("the stack needs bands B04, B03, B02 and B08")
  k <- vapply(months, function(m) pick_date(stack, m), 1L)
  if (anyNA(k) || k[1] == k[2]) stop("no usable dates for months ", paste(months, collapse = ", "))
  nb <- length(stack$bands)
  lay <- unlist(lapply(k, function(i) (i - 1L) * nb + match(need, stack$bands)))
  g <- stack$data[[1]]
  nr <- terra::nrow(g); nc <- terra::ncol(g)
  v <- terra::values(stack$data[[lay]], mat = TRUE) / stack$scale / 0.3
  v[!is.finite(v)] <- 0
  x <- array(0, c(8L, nr, nc))
  for (j in 1:8) x[j, , ] <- matrix(v[, j], nr, nc, byrow = TRUE)[nr:1, , drop = FALSE]   # south-up rows
  ph <- max(0L, window - nr); pw <- max(0L, window - nc)
  if (ph || pw) x <- pad_reflect(x, ph, pw)
  H <- dim(x)[2]; W <- dim(x)[3]
  pos_r <- unique(c(seq(0L, H - window, by = stride), H - window))
  pos_c <- unique(c(seq(0L, W - window, by = stride), W - window))
  net <- torch::jit_load(model)          # traced in inference mode: batch normalisation uses stored statistics
  acc <- array(0, c(3L, H, W)); cnt <- matrix(0, H, W)
  torch::with_no_grad({
    for (i in pos_r) for (j in pos_c) {
      xb <- torch::torch_tensor(array(x[, i + seq_len(window), j + seq_len(window)], c(1L, 8L, window, window)),
                                dtype = torch::torch_float(), device = device)
      p <- as.array(torch::nnf_softmax(net(xb), dim = 2)$cpu())[1, , , ]
      acc[, i + seq_len(window), j + seq_len(window)] <- acc[, i + seq_len(window), j + seq_len(window)] + p
      cnt[i + seq_len(window), j + seq_len(window)] <- cnt[i + seq_len(window), j + seq_len(window)] + 1
    }
  })
  out <- terra::rast(g, nlyrs = 3)
  vals <- sapply(1:3, function(c0) {
    a <- (acc[c0, , ] / cnt)[seq_len(nr), seq_len(nc), drop = FALSE][nr:1, , drop = FALSE]   # back to north-up
    as.vector(t(a))
  })
  terra::values(out) <- vals
  names(out) <- c("background", "field", "boundary")
  out
}

# Index of the clearest date in calendar month m, or in an adjacent month (December and
# January adjacent); NA if none.
pick_date <- function(stack, m) {
  mon <- as.integer(format(stack$dates, "%m"))
  cf <- if (is.null(stack$clear)) rep(1, length(stack$dates)) else terra::global(stack$clear, "mean", na.rm = TRUE)$mean
  for (mm in c(m, (m %% 12) + 1L, ((m - 2L) %% 12) + 1L)) {
    w <- which(mon == mm)
    if (length(w)) return(w[which.max(cf[w])])
  }
  NA_integer_
}

pad_reflect <- function(x, ph, pw) {
  nr <- dim(x)[2]; nc <- dim(x)[3]
  ri <- c(seq_len(nr), if (ph) rev(seq_len(nr))[seq_len(ph)] else integer())
  ci <- c(seq_len(nc), if (pw) rev(seq_len(nc))[seq_len(pw)] else integer())
  ri <- ((ri - 1L) %% nr) + 1L; ci <- ((ci - 1L) %% nc) + 1L
  x[, ri, ci, drop = FALSE]
}
