test_that("fb_stack checks its inputs and names layers", {
  r <- terra::rast(nrows = 5, ncols = 6, nlyrs = 6, vals = runif(180, 100, 3000))
  s <- fb_stack(r, c("2024-04-01", "2024-07-01"), c("B04", "B03", "B08"))
  expect_s3_class(s, "fb_stack")
  expect_equal(names(s$data)[4], "B04_2024-07-01")
  expect_error(fb_stack(r, c("2024-07-01", "2024-04-01"), c("B04", "B03", "B08")), "increasing")
  expect_error(fb_stack(r, "2024-04-01", c("B04", "B03", "B08")), "layers")
  expect_output(print(s), "fb_stack")
})

test_that("stacks are written and read back unchanged", {
  s <- fb_example_stack("moghan")
  d <- file.path(tempdir(), "stack_rt")
  idx <- fb_write_stack(s, d)
  s2 <- fb_read_stack(idx$image, bands = s$bands, dates = idx$date, clear = idx$clear)
  expect_equal(terra::values(s2$data), terra::values(s$data))
  expect_equal(terra::values(s2$clear), terra::values(s$clear))
  expect_equal(fb_dates(s2), fb_dates(s))
})

test_that("fb_subset_dates keeps the bands of the chosen dates", {
  s <- fb_example_stack("moghan")
  s3 <- fb_subset_dates(s, 2:4)
  expect_equal(length(s3$dates), 3)
  expect_equal(terra::nlyr(s3$data), 3 * length(s$bands))
  expect_equal(terra::values(s3$data[[1]]), terra::values(s$data[[length(s$bands) + 1]]))
})

test_that("selected cells are read as in full blocks", {
  s <- fb_example_stack("california")
  a <- fieldborders:::stack_block(s)
  cl <- c(5L, 100L, 20000L, terra::ncell(s$data))
  b <- fieldborders:::stack_block(s, cells = cl)
  expect_equal(b$X, a$X[cl, ], ignore_attr = TRUE)
  expect_equal(b$C, a$C[cl, ], ignore_attr = TRUE)
})
