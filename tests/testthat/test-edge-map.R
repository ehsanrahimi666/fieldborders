# Reference implementation of the edge map in plain R, for a small random stack.
edge_map_r <- function(Fm, C, nr, nc, K, beta, b0, mu, sd, eps = 1e-4) {
  M <- ncol(C)
  E <- rep(NA_real_, nr * nc)
  for (d in list(c(0, 1), c(1, 0), c(1, 1), c(1, -1))) {
    for (r in (1 + abs(d[1])):(nr - abs(d[1]))) for (cc in (1 + abs(d[2])):(nc - abs(d[2]))) {
      x <- (r - 1) * nc + cc
      p <- (r - 1 - d[1]) * nc + cc - d[2]
      q <- (r - 1 + d[1]) * nc + cc + d[2]
      z <- numeric(2 * K)
      for (k in seq_len(K)) {
        ok <- C[p, ] & C[q, ]
        if (!any(ok)) { z[k] <- mu[k]; z[K + k] <- mu[K + k]; next }
        cols <- (which(ok) - 1) * K + k
        ld <- log(abs(Fm[p, cols] - Fm[q, cols]) + eps)
        z[k] <- max(ld); z[K + k] <- mean(ld)
      }
      pr <- stats::plogis(b0 + sum(beta * (z - mu) / sd))
      E[x] <- if (is.na(E[x])) pr else max(E[x], pr)
    }
  }
  E[is.na(E)] <- 0
  E
}

test_that("the C++ edge map equals the reference implementation", {
  set.seed(3)
  nr <- 7; nc <- 9; M <- 4; K <- 3
  Fm <- matrix(runif(nr * nc * M * K), nr * nc, M * K)
  C <- matrix(runif(nr * nc * M) > 0.3, nr * nc, M)
  beta <- rnorm(2 * K); mu <- rnorm(2 * K); sd <- runif(2 * K, 0.5, 2); b0 <- 0.3
  e_cpp <- fieldborders:::.edge_map_cpp(t(Fm), t(C), nr, nc, K, beta, b0, mu, sd, 1e-4)
  e_r <- edge_map_r(Fm, C, nr, nc, K, beta, b0, mu, sd)
  expect_equal(e_cpp, e_r, tolerance = 1e-10)
})

test_that("row statistics match quantile type 7 and the population SD", {
  set.seed(4)
  A <- matrix(rnorm(60), 10, 6)
  A[2, ] <- NA
  A[3, c(1, 4)] <- NA
  st <- fieldborders:::.row_stats_cpp(t(A), c(0.1, 0.5, 0.9))
  for (i in c(1, 3, 10)) {
    v <- A[i, is.finite(A[i, ])]
    expect_equal(st[i, 1:3], unname(stats::quantile(v, c(0.1, 0.5, 0.9), type = 7)))
    expect_equal(st[i, 4], sqrt(mean((v - mean(v))^2)))
  }
  expect_true(all(is.nan(st[2, ])))
})
