# The 1.6 km box with the largest share of vegetated pixels (NDVI > 0.3) in one month, within a search
# area (lon/lat bounding box), used to place gallery boxes on farmland (data-raw/vignette_gallery.R).
# Usage: Rscript release/fieldborders/data-raw/locate_box.R <west> <south> <east> <north> <start> <end>
suppressPackageStartupMessages(library(terra)); library(fieldborders)
a <- commandArgs(trailingOnly = TRUE)
bb <- as.numeric(a[1:4]); month_start <- a[5]; month_end <- a[6]
s <- fb_s2_monthly(bb, month_start, month_end, bands = c("B04", "B08"), resolution = 60, max_invalid = 0.5, verbose = FALSE)
r <- s$data
ndvi <- (r[[2]] - r[[1]]) / (r[[2]] + r[[1]] + 1)
w <- focal(ndvi > 0.3, w = matrix(1, 27, 27), fun = "mean", na.rm = FALSE)   # windows reaching beyond the area are NA
cell <- which.max(values(w, mat = FALSE))
ll <- geom(project(vect(xyFromCell(w, cell), crs = crs(w)), "EPSG:4326"))[, c("x", "y")]
cat(sprintf("vegetated share %.2f centre %.4f %.4f\n", max(values(w, mat = FALSE), na.rm = TRUE), ll[1], ll[2]))
