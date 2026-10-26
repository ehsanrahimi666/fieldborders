# Logistic regression with a ridge penalty on the slopes (the intercept is not penalised):
# minimises sum of log-losses + lambda / 2 * sum(beta^2) by Newton steps with step halving.
# lambda = 1 is the default of scikit-learn's LogisticRegression (C = 1), used by the
# validation pipeline; the penalty also keeps the fit finite when classes are separable.
# Returns c(intercept, slopes).
logistic_ridge <- function(X, y, lambda = 1, maxit = 100L, tol = 1e-9) {
  X <- cbind(1, as.matrix(X))
  y <- as.numeric(y)
  p <- ncol(X)
  pen <- c(0, rep(lambda, p - 1L))
  objective <- function(w) {
    eta <- drop(X %*% w)
    sum(pmax(eta, 0) - y * eta + log1p(exp(-abs(eta)))) + 0.5 * sum(pen * w^2)
  }
  w <- numeric(p)
  f <- objective(w)
  for (it in seq_len(maxit)) {
    mu <- stats::plogis(drop(X %*% w))
    g <- drop(crossprod(X, mu - y)) + pen * w
    H <- crossprod(X, X * (mu * (1 - mu))) + diag(pen + 1e-10, p)
    step <- tryCatch(solve(H, g), error = function(e) qr.solve(H, g))
    t <- 1
    repeat {
      w_new <- w - t * step
      f_new <- objective(w_new)
      if (f_new <= f + 1e-12 * abs(f) || t < 1e-8) break
      t <- t / 2
    }
    done <- max(abs(w_new - w)) < tol * (1 + max(abs(w)))
    w <- w_new; f <- f_new
    if (done) break
  }
  w
}
