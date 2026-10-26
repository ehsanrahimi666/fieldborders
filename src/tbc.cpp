// Temporal boundary contrast: edge map and per-pixel temporal statistics.
#include <Rcpp.h>
#include <algorithm>
#include <cmath>
#include <vector>
using namespace Rcpp;

// Edge probability of every pixel. FT holds the K selected features of M dates with one
// column per cell (cells in row-major order) and rows m * K + k; CT holds the clear flags
// with one column per cell and one row per date. For a pixel x and a direction d, the pair
// (x - d, x + d) is summarised by the temporal maximum and mean, over dates clear at both
// ends, of log(|f(p) - f(q)| + eps) for each feature; summaries without a common clear date
// take the training mean. The logistic edge model gives the pair probability, and the edge
// map is the maximum over the four directions (0 where no pair is centred on the pixel).
// [[Rcpp::export(name = ".edge_map_cpp")]]
NumericVector edge_map_cpp(NumericMatrix FT, LogicalMatrix CT, int nrow, int ncol, int K,
                           NumericVector beta, double intercept, NumericVector mu, NumericVector sd,
                           double eps) {
  const int ncell = nrow * ncol;
  const int M = CT.nrow();
  const int MK = M * K;
  if (FT.ncol() != ncell || CT.ncol() != ncell) stop("FT and CT must have one column per cell");
  if (FT.nrow() != MK) stop("FT must have M * K rows");
  if (beta.size() != 2 * K || mu.size() != 2 * K || sd.size() != 2 * K) stop("model length must be 2 * K");
  const double* f = FT.begin();
  const int* c = CT.begin();
  NumericVector E(ncell, R_NaN);
  const int dirs[4][2] = {{0, 1}, {1, 0}, {1, 1}, {1, -1}};
  std::vector<double> vmax(K), vprod(K), logsum(K);
  std::vector<int> cnt(K);
  std::vector<double> w(2 * K);
  double w0 = intercept;
  for (int j = 0; j < 2 * K; j++) { w[j] = beta[j] / sd[j]; w0 -= beta[j] * mu[j] / sd[j]; }
  for (int d = 0; d < 4; d++) {
    const int di = dirs[d][0], dj = dirs[d][1];
    const int adi = std::abs(di), adj = std::abs(dj);
    for (int r = adi; r < nrow - adi; r++) {
      for (int cc = adj; cc < ncol - adj; cc++) {
        const int x = r * ncol + cc;
        const int p = (r - di) * ncol + (cc - dj);
        const int q = (r + di) * ncol + (cc + dj);
        const double* fp = f + (size_t) p * MK;
        const double* fq = f + (size_t) q * MK;
        const int* cp = c + (size_t) p * M;
        const int* cq = c + (size_t) q * M;
        for (int k = 0; k < K; k++) { vmax[k] = -1.0; cnt[k] = 0; logsum[k] = 0.0; vprod[k] = 1.0; }
        for (int m = 0; m < M; m++) {
          if (!cp[m] || !cq[m]) continue;
          const double* a = fp + m * K;
          const double* b = fq + m * K;
          for (int k = 0; k < K; k++) {
            if (!std::isfinite(a[k]) || !std::isfinite(b[k])) continue;
            const double v = std::fabs(a[k] - b[k]) + eps;
            if (v > vmax[k]) vmax[k] = v;
            vprod[k] *= v;
            if (vprod[k] < 1e-250) { logsum[k] += std::log(vprod[k]); vprod[k] = 1.0; }
            cnt[k]++;
          }
        }
        double eta = w0;
        for (int k = 0; k < K; k++) {
          const double zmax = cnt[k] > 0 ? std::log(vmax[k]) : mu[k];
          const double zmean = cnt[k] > 0 ? (logsum[k] + std::log(vprod[k])) / cnt[k] : mu[K + k];
          eta += w[k] * zmax + w[K + k] * zmean;
        }
        const double pr = 1.0 / (1.0 + std::exp(-eta));
        if (std::isnan(E[x]) || pr > E[x]) E[x] = pr;
      }
    }
  }
  for (int i = 0; i < ncell; i++) if (std::isnan(E[i])) E[i] = 0.0;
  return E;
}

// Percentiles per row (linear interpolation between order statistics, as numpy's default)
// and population standard deviation over the finite values of each row; NaN for rows
// without finite values. Returns a matrix with one column per probability and a last
// column for the standard deviation.
// AT holds the values with one column per row of the result (that is, the transposed
// matrix of rows by dates).
// [[Rcpp::export(name = ".row_stats_cpp")]]
NumericMatrix row_stats_cpp(NumericMatrix AT, NumericVector probs) {
  const int n = AT.ncol(), M = AT.nrow(), np = probs.size();
  NumericMatrix out(n, np + 1);
  std::vector<double> v;
  v.reserve(M);
  const double* base = AT.begin();
  for (int i = 0; i < n; i++) {
    v.clear();
    const double* col = base + (size_t) i * M;
    for (int m = 0; m < M; m++) {
      const double a = col[m];
      if (std::isfinite(a)) v.push_back(a);
    }
    const int k = v.size();
    if (k == 0) {
      for (int j = 0; j <= np; j++) out(i, j) = R_NaN;
      continue;
    }
    std::sort(v.begin(), v.end());
    for (int j = 0; j < np; j++) {
      const double pos = probs[j] * (k - 1);
      const int lo = (int) std::floor(pos), hi = (int) std::ceil(pos);
      out(i, j) = v[lo] + (pos - lo) * (v[hi] - v[lo]);
    }
    double mean = 0.0;
    for (int t = 0; t < k; t++) mean += v[t];
    mean /= k;
    double ss = 0.0;
    for (int t = 0; t < k; t++) ss += (v[t] - mean) * (v[t] - mean);
    out(i, np) = std::sqrt(ss / k);
  }
  return out;
}
