test_that("dates for the deep model are chosen by month", {
  s <- fb_example_stack("california")
  k <- fieldborders:::pick_date(s, 3)
  expect_equal(as.integer(format(s$dates[k], "%m")), 3L)
})

test_that("reflection padding keeps the original pixels", {
  x <- array(seq_len(2 * 3 * 4), c(2, 3, 4))
  y <- fieldborders:::pad_reflect(x, 2, 1)
  expect_equal(dim(y), c(2, 5, 5))
  expect_equal(y[, 1:3, 1:4], x)
})

test_that("PRUE runs in R when torch and the model are available", {
  skip_if_not_installed("torch")
  skip_if_not(torch::torch_is_installed())
  skip_on_cran()
  f <- file.path(tools::R_user_dir("fieldborders", "cache"), "prue_b3_ccby_torchscript.pt")
  skip_if_not(file.exists(f))
  p <- fb_prue_predict(fb_example_stack("california"), c(3, 7), model = f)
  expect_equal(names(p), c("background", "field", "boundary"))
  s <- rowSums(terra::values(p))
  expect_true(all(abs(s - 1) < 1e-4))
  # the example holds the output of the same call, stored with four decimals
  ref <- fb_read_probabilities(fb_example_files("california")$prue)
  expect_lt(max(abs(terra::values(p) - terra::values(ref))), 1e-3)
})
