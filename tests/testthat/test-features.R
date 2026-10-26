test_that("the default feature set holds the bands and all normalised differences", {
  fs <- fb_feature_set(fb_example_bands())
  expect_equal(nrow(fs), 10 + choose(10, 2))
  expect_true(all(c("band", "nd") %in% fs$type))
  X <- matrix(c(0.1, 0.3, 0.2, 0.4), 2)
  v <- fieldborders:::feature_matrix(fb_feature_set(c("B04", "B08")), X, 1, c("B04", "B08"))
  expect_equal(unname(v[, 3]), (X[, 1] - X[, 2]) / (X[, 1] + X[, 2] + 1e-4))
})

test_that("cropland variables include NDVI when red and near-infrared are present", {
  v <- fieldborders:::cropland_variables(c("B04", "B08", "B11"))
  expect_true(all(c("NDVI", "NDMI") %in% v$name))
  expect_false("NDSW" %in% v$name)
})

test_that("published indices of svid are rewritten in band names", {
  skip_if_not_installed("svid")
  fs <- fb_feature_set(fb_example_bands(), set = "svid")
  sv <- fs[fs$type == "svid", ]
  expect_gt(nrow(sv), 50)
  # every expression uses only the stack's bands and evaluates on reflectances
  used <- unique(unlist(lapply(sv$expr, function(e) all.vars(str2lang(e)))))
  expect_true(all(used %in% fb_example_bands()))
  X <- matrix(runif(20 * 10, 0.02, 0.5), 20)
  v <- fieldborders:::feature_matrix(sv, X, 1, fb_example_bands())
  expect_equal(dim(v), c(20L, nrow(sv)))
  # expressions from an svid grammar are added
  g <- svid::svid_grammar(bands = c("R", "N", "S1"), ops = c("-", "/"), max_depth = 1L)
  fg <- fb_feature_set(fb_example_bands(), set = "svid", grammar = g)
  expect_gt(nrow(fg), nrow(fs))
  expect_true("(B08)/(B11)" %in% fg$expr)
})
