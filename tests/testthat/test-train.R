test_that("features are ranked and a model is trained on the example", {
  e <- example_setup()
  rk <- fb_rank_contrast(e$stack, e$ref, n_pairs = 500)
  expect_s3_class(rk, "fb_contrast")
  expect_true(rk$ranking$auc[1] > 0.6)
  sel <- fb_select_features(rk, k = 4)
  expect_length(sel, 4)
  m <- e$model
  expect_s3_class(m, "fb_model")
  expect_equal(length(m$edge$beta), 2 * nrow(m$features))
  expect_output(print(m), "temporal boundary contrast")
})

test_that("TBC maps are probabilities on the stack grid", {
  e <- example_setup()
  maps <- fb_tbc_maps(e$stack, e$model)
  expect_equal(names(maps), c("edge", "cropland"))
  v <- terra::values(maps)
  expect_true(all(v >= 0 & v <= 1))
  expect_true(terra::compareGeom(maps, e$stack$data[[1]]))
  # edge probabilities are higher on reference boundaries than inside fields
  cls <- terra::values(e$ref$class)[, 1]
  expect_gt(mean(v[cls == 2, "edge"]), mean(v[cls == 1, "edge"]))
})

test_that("block processing gives the same maps as one block", {
  e <- example_setup()
  a <- fb_tbc_maps(e$stack, e$model)
  b <- fb_tbc_maps(e$stack, e$model, block_cells = 2000)
  expect_equal(terra::values(a), terra::values(b), tolerance = 1e-10)
})

test_that("models are saved and loaded", {
  e <- example_setup()
  f <- tempfile(fileext = ".rds")
  fb_save_model(e$model, f)
  expect_equal(fb_load_model(f)$edge, e$model$edge)
})

test_that("the ridge logistic regression matches scikit-learn (C = 1)", {
  set.seed(3)
  n <- 400
  X <- matrix(rnorm(n * 4), n)
  y <- rbinom(n, 1, plogis(0.5 + X %*% c(2, -1, 0.5, 0)))
  # reference: sklearn.linear_model.LogisticRegression(C = 1.0, tol = 1e-12) on the same data
  expect_equal(fieldborders:::logistic_ridge(X, y), c(0.401922, 1.928779, -0.948065, 0.358919, 0.079289),
               tolerance = 1e-5)
  # separable classes give finite coefficients
  w <- fieldborders:::logistic_ridge(X, as.integer(X[, 1] > 0))
  expect_true(all(is.finite(w)) && max(abs(w)) < 20)
})

test_that("the gradient-boosting cropland learner trains, predicts and survives saving", {
  e <- example_setup()
  m <- fb_train(e$stack, e$ref, n_pairs = 500, n_pixels = 1000, learner = "xgboost", num_trees = 20, seed = 1)
  expect_equal(m$cropland$learner, "xgboost")
  maps <- fb_tbc_maps(e$stack, m)
  v <- terra::values(maps)
  expect_true(all(v >= 0 & v <= 1))
  f <- tempfile(fileext = ".rds")
  fb_save_model(m, f)
  expect_equal(terra::values(fb_tbc_maps(e$stack, fb_load_model(f))), v)
  # cropland probabilities separate the reference classes
  cls <- terra::values(e$ref$class)[, 1]
  expect_gt(mean(v[cls == 1, "cropland"]), mean(v[cls == 0, "cropland"]))
})
