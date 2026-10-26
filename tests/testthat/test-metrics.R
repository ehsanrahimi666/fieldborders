test_that("a perfect prediction has object F1 of 1", {
  sem <- matrix(0L, 10, 10); sem[2:4, 2:8] <- 1L; sem[6:9, 2:8] <- 1L
  pred <- fb_components(sem == 1L)
  ev <- fb_evaluate(sem, pred)
  expect_equal(ev$obj_tp, 2)
  expect_equal(fb_accuracy(ev)$obj_f1, 1)
})

test_that("a merged prediction misses both fields", {
  sem <- matrix(0L, 10, 10); sem[2:4, 2:8] <- 1L; sem[6:9, 2:8] <- 1L
  pred <- matrix(0L, 10, 10); pred[2:9, 2:8] <- 1L
  ev <- fb_evaluate(sem, pred)
  expect_equal(ev$obj_tp, 0)
  expect_equal(ev$obj_fn, 2)
  expect_equal(ev$obj_fp, 1)
})

test_that("unlabelled predictions are ignored in obj_fp", {
  sem <- matrix(3L, 10, 10); sem[2:4, 2:8] <- 1L
  pred <- matrix(0L, 10, 10); pred[2:4, 2:8] <- 1L; pred[7:9, 2:8] <- 2L
  ev <- fb_evaluate(sem, pred)
  expect_equal(ev$obj_fp, 0)
  expect_equal(ev$obj_fp_all, 1)
})

test_that("AUC and bootstrap behave as expected", {
  expect_equal(fb_auc(c(0.1, 0.2, 0.8, 0.9), c(0, 0, 1, 1)), 1)
  expect_equal(fb_auc(c(1, 1, 1, 1), c(0, 0, 1, 1)), 0.5)
  d <- data.frame(tile = rep(1:10, 2), method = rep(c("a", "b"), each = 10), obj_tp = c(rep(9, 10), rep(5, 10)),
                  obj_fp = 1, obj_fn = c(rep(1, 10), rep(5, 10)))
  b <- fb_bootstrap(d, c("a", "b"), B = 200)
  expect_gt(b$lo, 0)
})
