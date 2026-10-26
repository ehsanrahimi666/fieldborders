#include <Rcpp.h>
#include <algorithm>
#include <map>
#include <queue>
#include <utility>
#include <vector>

using namespace Rcpp;

namespace {
const int DI4[4] = {-1, 1, 0, 0};
const int DJ4[4] = {0, 0, -1, 1};
const int DI8[8] = {-1, -1, -1, 0, 0, 1, 1, 1};
const int DJ8[8] = {-1, 0, 1, -1, 1, -1, 0, 1};

struct HeapItem {
  double e;
  long age;
  int p;
  int lab;
};

struct HeapCmp {
  bool operator()(const HeapItem& a, const HeapItem& b) const {
    if (a.e != b.e) return a.e > b.e;
    return a.age > b.age;
  }
};
}  // namespace

// Connected components of pixels that share the same positive value.
// [[Rcpp::export(name = ".cc_label_cpp")]]
IntegerMatrix cc_label_cpp(IntegerMatrix x, int connectivity) {
  const int nr = x.nrow(), nc = x.ncol();
  IntegerMatrix out(nr, nc);
  const int nn = connectivity == 8 ? 8 : 4;
  const int* di = connectivity == 8 ? DI8 : DI4;
  const int* dj = connectivity == 8 ? DJ8 : DJ4;
  std::vector<int> stack;
  int label = 0;
  for (int j = 0; j < nc; ++j) {
    for (int i = 0; i < nr; ++i) {
      const int v = x(i, j);
      if (v == NA_INTEGER || v <= 0 || out(i, j) != 0) continue;
      ++label;
      out(i, j) = label;
      stack.push_back(i + j * nr);
      while (!stack.empty()) {
        const int p = stack.back();
        stack.pop_back();
        const int pi = p % nr, pj = p / nr;
        for (int k = 0; k < nn; ++k) {
          const int qi = pi + di[k], qj = pj + dj[k];
          if (qi < 0 || qi >= nr || qj < 0 || qj >= nc) continue;
          if (out(qi, qj) != 0 || x(qi, qj) != v) continue;
          out(qi, qj) = label;
          stack.push_back(qi + qj * nr);
        }
      }
    }
  }
  return out;
}

// Marker-controlled watershed by priority flooding (4-connectivity).
// Pixels outside `mask` stay 0. With `lines`, a pixel reached from one basin that
// touches another basin becomes a separating line (0).
// [[Rcpp::export(name = ".watershed_cpp")]]
IntegerMatrix watershed_cpp(NumericMatrix elev, IntegerMatrix markers, LogicalMatrix mask, bool lines) {
  const int nr = elev.nrow(), nc = elev.ncol(), n = nr * nc;
  if (markers.nrow() != nr || markers.ncol() != nc || mask.nrow() != nr || mask.ncol() != nc)
    stop("elev, markers and mask must have the same dimensions");
  IntegerMatrix lab(nr, nc);
  std::vector<char> isline(n, 0);
  std::priority_queue<HeapItem, std::vector<HeapItem>, HeapCmp> heap;
  long age = 0;
  auto elev_at = [&](int q) {
    const double e = elev[q];
    return ISNAN(e) ? R_PosInf : e;
  };
  for (int p = 0; p < n; ++p) {
    const int m = markers[p];
    if (mask[p] == TRUE && m != NA_INTEGER && m > 0) lab[p] = m;
  }
  for (int p = 0; p < n; ++p) {
    if (lab[p] <= 0) continue;
    const int pi = p % nr, pj = p / nr;
    for (int k = 0; k < 4; ++k) {
      const int qi = pi + DI4[k], qj = pj + DJ4[k];
      if (qi < 0 || qi >= nr || qj < 0 || qj >= nc) continue;
      const int q = qi + qj * nr;
      if (mask[q] == TRUE && lab[q] == 0) heap.push({elev_at(q), age++, q, lab[p]});
    }
  }
  while (!heap.empty()) {
    const HeapItem it = heap.top();
    heap.pop();
    const int p = it.p;
    if (lab[p] != 0 || isline[p]) continue;
    const int pi = p % nr, pj = p / nr;
    if (lines) {
      bool conflict = false;
      for (int k = 0; k < 4 && !conflict; ++k) {
        const int qi = pi + DI4[k], qj = pj + DJ4[k];
        if (qi < 0 || qi >= nr || qj < 0 || qj >= nc) continue;
        const int lq = lab[qi + qj * nr];
        if (lq > 0 && lq != it.lab) conflict = true;
      }
      if (conflict) {
        isline[p] = 1;
        continue;
      }
    }
    lab[p] = it.lab;
    for (int k = 0; k < 4; ++k) {
      const int qi = pi + DI4[k], qj = pj + DJ4[k];
      if (qi < 0 || qi >= nr || qj < 0 || qj >= nc) continue;
      const int q = qi + qj * nr;
      if (mask[q] == TRUE && lab[q] == 0 && !isline[q]) heap.push({elev_at(q), age++, q, it.lab});
    }
  }
  return lab;
}

// Region adjacency from direct 4-adjacency of different positive labels.
// Returns label pairs (a < b) and the 1-based indices of pixels on both sides of
// their shared border.
// [[Rcpp::export(name = ".rag_cpp")]]
List rag_cpp(IntegerMatrix lab) {
  const int nr = lab.nrow(), nc = lab.ncol();
  std::map<std::pair<int, int>, std::vector<int>> border;
  for (int j = 0; j < nc; ++j) {
    for (int i = 0; i < nr; ++i) {
      const int a = lab(i, j);
      if (a <= 0) continue;
      const int p = i + j * nr;
      if (i + 1 < nr) {
        const int b = lab(i + 1, j);
        if (b > 0 && b != a) {
          auto& v = border[std::make_pair(std::min(a, b), std::max(a, b))];
          v.push_back(p + 1);
          v.push_back(p + 2);
        }
      }
      if (j + 1 < nc) {
        const int b = lab(i, j + 1);
        if (b > 0 && b != a) {
          auto& v = border[std::make_pair(std::min(a, b), std::max(a, b))];
          v.push_back(p + 1);
          v.push_back(p + nr + 1);
        }
      }
    }
  }
  const int m = static_cast<int>(border.size());
  IntegerVector va(m), vb(m);
  List pix(m);
  int k = 0;
  for (auto& kv : border) {
    std::vector<int>& v = kv.second;
    std::sort(v.begin(), v.end());
    v.erase(std::unique(v.begin(), v.end()), v.end());
    va[k] = kv.first.first;
    vb[k] = kv.first.second;
    pix[k] = IntegerVector(v.begin(), v.end());
    ++k;
  }
  return List::create(_["a"] = va, _["b"] = vb, _["pixels"] = pix);
}

// Keep pixels flagged in `keep`; also keep a non-flagged pixel inside the mask when
// all four neighbours carry its own label (closes cracks inside one object). Then
// insert one-pixel separating lines wherever two different labels touch (the pixel
// with the larger label is cleared), so objects are 4-separated.
// [[Rcpp::export(name = ".finalise_objects_cpp")]]
IntegerMatrix finalise_objects_cpp(IntegerMatrix lab, LogicalMatrix keep) {
  const int nr = lab.nrow(), nc = lab.ncol();
  IntegerMatrix out(nr, nc);
  for (int j = 0; j < nc; ++j) {
    for (int i = 0; i < nr; ++i) {
      const int a = lab(i, j);
      if (a <= 0) continue;
      if (keep(i, j) == TRUE) {
        out(i, j) = a;
        continue;
      }
      bool inner = true;
      for (int k = 0; k < 4 && inner; ++k) {
        const int qi = i + DI4[k], qj = j + DJ4[k];
        if (qi < 0 || qi >= nr || qj < 0 || qj >= nc || lab(qi, qj) != a) inner = false;
      }
      if (inner) out(i, j) = a;
    }
  }
  IntegerMatrix res = clone(out);
  for (int j = 0; j < nc; ++j) {
    for (int i = 0; i < nr; ++i) {
      const int a = out(i, j);
      if (a <= 0) continue;
      for (int k = 0; k < 4; ++k) {
        const int qi = i + DI4[k], qj = j + DJ4[k];
        if (qi < 0 || qi >= nr || qj < 0 || qj >= nc) continue;
        const int b = out(qi, qj);
        if (b > 0 && b < a) {
          res(i, j) = 0;
          break;
        }
      }
    }
  }
  return res;
}
