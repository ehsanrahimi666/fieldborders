test_that("pretrained models load with thresholds", {
  for (r in c("general", "california", "ftw")) {
    m <- fb_model_pretrained(r)
    expect_s3_class(m, "fb_model")
    expect_true(all(c("t_edge", "t_field", "min_size") %in% names(m$thresholds)))
  }
  expect_s3_class(fb_model_pretrained("general", "fusion"), "fb_fusion")
  expect_error(fb_model_pretrained("ftw", "fusion"), "no pretrained")
})
