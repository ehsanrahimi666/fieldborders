test_that("fb_reference rasterizes fields, boundaries and background", {
  g <- terra::rast(nrows = 20, ncols = 20, xmin = 0, xmax = 20, ymin = 0, ymax = 20, crs = "EPSG:32633")
  p <- sf::st_sf(id = 1:2, geometry = sf::st_sfc(sf::st_polygon(list(rbind(c(2, 2), c(9, 2), c(9, 18), c(2, 18), c(2, 2)))),
                                                  sf::st_polygon(list(rbind(c(9, 2), c(17, 2), c(17, 18), c(9, 18), c(9, 2)))),
                                                  crs = 32633))
  ref <- fb_reference(p, g)
  tab <- terra::freq(ref$class)
  expect_true(all(c(0, 1, 2) %in% tab$value))
  expect_equal(sort(unique(terra::values(ref$field_id)[, 1])), 0:2)
  ref3 <- fb_reference(p, g, presence_only = TRUE)
  expect_true(3 %in% terra::freq(ref3$class)$value)
})

test_that("pair sampling separates across and within pairs", {
  cls <- matrix(1L, 10, 10); cls[, 5] <- 2L
  inst <- matrix(1L, 10, 10); inst[, 6:10] <- 2L; inst[, 5] <- 0L
  pr <- fieldborders:::sample_pairs(as.vector(t(cls)), as.vector(t(inst)), 10, 10, 1000, 1)
  expect_true(all(c(0, 1) %in% pr[, "y"]))
  across <- pr[pr[, "y"] == 1, ]
  ii <- as.vector(t(inst))
  expect_true(all(ii[across[, "p"]] != ii[across[, "q"]]))
})
