# Reader for the .npz Sentinel-2 tile arrays of the validation pipeline (numpy format, C order),
# used by the data-raw scripts to build fb_stack objects without Python.
read_npy <- function(con, reversed = FALSE) {
  magic <- readBin(con, "raw", 6)
  if (!identical(magic[2:6], charToRaw("NUMPY"))) stop("not an npy file")
  ver <- readBin(con, "integer", 2, size = 1)
  hlen <- if (ver[1] == 1) readBin(con, "integer", 1, size = 2, endian = "little", signed = FALSE)
          else readBin(con, "integer", 1, size = 4, endian = "little")
  header <- rawToChar(readBin(con, "raw", hlen))
  descr <- sub(".*'descr': *'([^']+)'.*", "\\1", header)
  shape <- as.integer(strsplit(gsub("[^0-9,]", "", sub(".*'shape': *\\(([^)]*)\\).*", "\\1", header)), ",")[[1]])
  shape <- shape[!is.na(shape)]
  n <- if (length(shape)) prod(shape) else 1L
  v <- switch(substr(descr, 2, 2),
    u = readBin(con, "integer", n, size = as.integer(substr(descr, 3, 3)), signed = FALSE, endian = "little"),
    i = { s <- as.integer(substr(descr, 3, 3)); if (s == 8) { x <- readBin(con, "integer", 2 * n, size = 4, endian = "little"); x[c(TRUE, FALSE)] } else readBin(con, "integer", n, size = s, endian = "little") },
    f = readBin(con, "double", n, size = as.integer(substr(descr, 3, 3)), endian = "little"),
    b = as.logical(readBin(con, "integer", n, size = 1, signed = FALSE)),
    U = { w <- as.integer(sub("<U", "", descr)); r <- readBin(con, "integer", n * w, size = 4, endian = "little")
          vapply(seq_len(n), function(i) intToUtf8(r[(i - 1) * w + seq_len(w)][r[(i - 1) * w + seq_len(w)] > 0]), "") },
    stop("unsupported dtype ", descr))
  if (length(shape) <= 1) return(v)
  a <- array(v, dim = rev(shape))                         # C order read as reversed dimensions
  if (reversed) a else aperm(a, rev(seq_along(shape)))
}

read_npz <- function(path, reversed = FALSE) {
  d <- tempfile("npz"); dir.create(d)
  on.exit(unlink(d, recursive = TRUE))
  utils::unzip(path, exdir = d)
  out <- list()
  for (f in list.files(d, pattern = "\\.npy$", full.names = TRUE)) {
    con <- file(f, "rb")
    out[[sub("\\.npy$", "", basename(f))]] <- read_npy(con, reversed)
    close(con)
  }
  out
}

# fb_stack of a validation tile (arrays north-up on the FTW grid given by the tile bounds).
npz_stack <- function(npz, west, south, east, north, crs = "EPSG:4326") {
  z <- read_npz(npz, reversed = TRUE)                     # data: W x H x B x M, clear: W x H x M
  W <- dim(z$data)[1]; H <- dim(z$data)[2]; B <- dim(z$data)[3]; M <- dim(z$data)[4]
  tmpl <- terra::rast(nrows = H, ncols = W, xmin = west, xmax = east, ymin = south, ymax = north, crs = crs)
  r <- terra::rast(tmpl, nlyrs = M * B)
  dim(z$data) <- c(H * W, M * B)                          # reshape without copying
  terra::values(r) <- z$data
  z$data <- NULL
  cl <- terra::rast(tmpl, nlyrs = M)
  dim(z$clear) <- c(H * W, M)
  storage.mode(z$clear) <- "integer"
  terra::values(cl) <- z$clear
  out <- fieldborders::fb_stack(r, as.Date(z$dates), as.character(z$bands), cl, scale = 10000)
  rm(z); gc(verbose = FALSE)
  out
}
