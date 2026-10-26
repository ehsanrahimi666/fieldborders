test_that("the output grid uses the UTM zone of the area", {
  g <- fieldborders:::s2_grid(c(-122.03, 39.20, -122.02, 39.21), 10)
  expect_true(grepl("32610", terra::crs(g, describe = TRUE)$code))
  expect_equal(terra::res(g), c(10, 10))
  g2 <- fieldborders:::s2_grid(c(47.80, 39.50, 47.82, 39.52), 20)
  expect_true(grepl("32638", terra::crs(g2, describe = TRUE)$code))
})

test_that("monthly Sentinel-2 download works", {
  skip_on_cran()
  skip_if_offline()
  skip_if_not_installed("rstac")
  skip_if(Sys.getenv("FIELDBORDERS_TEST_DOWNLOAD") != "true", "set FIELDBORDERS_TEST_DOWNLOAD=true to run")
  s <- fb_s2_monthly(c(-122.03, 39.200, -122.025, 39.205), "2024-06-01", "2024-08-31", verbose = FALSE)
  expect_s3_class(s, "fb_stack")
  expect_gte(length(s$dates), 1)
})
