test_that("two fields separated by an edge line become two objects", {
  g <- terra::rast(nrows = 30, ncols = 30, xmin = 0, xmax = 300, ymin = 0, ymax = 300, crs = "EPSG:32633", nlyrs = 2)
  E <- matrix(0.05, 30, 30); E[, 15] <- 0.95
  F <- matrix(0.95, 30, 30); F[1:3, ] <- 0.05
  terra::values(g) <- cbind(as.vector(t(E)), as.vector(t(F)))
  names(g) <- c("edge", "cropland")
  o <- fb_delineate(g, t_edge = 0.5, t_field = 0.5, min_size = 10)
  expect_equal(length(setdiff(unique(terra::values(o)[, 1]), 0)), 2)
  p <- fb_polygons(o, g)
  expect_equal(nrow(p), 2)
  expect_true(all(c("area_ha", "perimeter_m", "compactness", "mean_edge") %in% names(p)))
  expect_equal(sum(p$area_ha), sum(terra::values(o)[, 1] > 0) * 100 / 1e4, tolerance = 1e-6)
})

test_that("deep-model probabilities are accepted by fb_delineate", {
  p <- fb_read_probabilities(fb_example_files("california")$prue)
  o <- fb_delineate(p, 0.2, 0.7, 50)
  expect_true(max(terra::values(o)) > 0)
})

test_that("fb_tune returns combinations sorted by F1", {
  e <- example_setup()
  maps <- fb_tbc_maps(e$stack, e$model)
  tn <- fb_tune(maps, e$ref, t_edge = c(0.3, 0.6), t_field = c(0.5, 0.8), min_size = c(0, 40))
  expect_equal(nrow(tn), 8)
  expect_true(all(diff(tn$f1) <= 0))
})
