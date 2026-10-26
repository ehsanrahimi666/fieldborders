# Shared test data: the California example and a small model trained on it.
example_setup <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      s <- fb_example_stack("california")
      f <- fb_example_files("california")
      ref <- fb_reference(sf::st_read(f$fields, quiet = TRUE), s)
      m <- fb_train(s, ref, n_pairs = 800, n_pixels = 1500, learner = "glm", seed = 1)
      cache <<- list(stack = s, files = f, ref = ref, model = m)
    }
    cache
  }
})
