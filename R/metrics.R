#' Object-level accuracy of field delineation
#'
#' Compares predicted field objects with reference fields using the object metric of the
#' Fields of The World benchmark. Reference objects are the 4-connected components of
#' field pixels; predicted objects are the 4-connected components of each label. A
#' reference and a predicted object match when their intersection over union exceeds
#' `iou` (with `iou >= 0.5` every match is one-to-one). Unmatched predicted objects with
#' more than half of their pixels unlabelled (class 3) are not counted as false
#' positives (`obj_fp`); `obj_fp_all` counts all of them.
#'
#' @param reference Reference classes: a raster from [fb_reference()] (its `class`
#'   layer is used) or an integer matrix (0 background, 1 field, 2 boundary,
#'   3 unlabelled).
#' @param fields Predicted objects: a raster from [fb_delineate()] or an integer matrix.
#' @param iou Matching threshold (at least 0.5).
#' @param pixel_area Pixel area in square metres for the size classes; computed from the
#'   raster when `reference` is a `SpatRaster`.
#' @param size_breaks_ha Breaks of the reference-field size classes in hectares.
#' @param field,unlabelled Class codes.
#' @return A one-row data frame of counts: pixel `tp`, `fp`, `fn`; objects `obj_tp`,
#'   `obj_fp`, `obj_fp_all`, `obj_fn`, `n_pred`; and reference fields and matches per
#'   size class (`ref_s<k>`, `hit_s<k>`). Summarise with [fb_accuracy()].
#' @examples
#' s <- fb_example_stack("california")
#' f <- fb_example_files("california")
#' ref <- fb_reference(sf::st_read(f$fields, quiet = TRUE), s)
#' m <- fb_model_pretrained("california")
#' fields <- fb_delineate(fb_tbc_maps(s, m), thresholds = m$thresholds)
#' ev <- fb_evaluate(ref, fields)
#' ev
#' fb_accuracy(ev)
#' @export
fb_evaluate <- function(reference, fields, iou = 0.5, pixel_area = NA_real_, size_breaks_ha = c(0, 1, 5, 20, 50, Inf),
                        field = 1L, unlabelled = 3L) {
  if (iou < 0.5) stop("iou must be at least 0.5 for one-to-one matching")
  if (inherits(reference, "SpatRaster")) {
    if (is.na(pixel_area)) pixel_area <- mean_cell_area(reference)
    sem <- as_matrix(if ("class" %in% names(reference)) reference[["class"]] else reference[[1]])
  } else sem <- reference
  pred <- if (inherits(fields, "SpatRaster")) as_matrix(fields) else fields
  object_counts(sem, pred, iou, pixel_area, size_breaks_ha, field, unlabelled)
}

# Counts of fb_evaluate() for matrices; G (components of the reference fields) can be
# passed when the same reference is evaluated many times.
object_counts <- function(sem, pred, iou = 0.5, pixel_area = NA_real_, size_breaks_ha = c(0, 1, 5, 20, 50, Inf),
                          field = 1L, unlabelled = 3L, G = NULL) {
  storage.mode(sem) <- "integer"
  pred[is.na(pred)] <- 0L
  storage.mode(pred) <- "integer"
  valid <- sem != unlabelled
  gt <- sem == field
  pf <- pred > 0
  out <- data.frame(tp = sum(pf & gt & valid), fp = sum(pf & !gt & valid), fn = sum(!pf & gt & valid))
  if (is.null(G)) G <- fb_components(gt)
  P <- fb_components(pred)
  ng <- max(G, 0L); np <- max(P, 0L)
  ag <- tabulate(G[G > 0], nbins = ng)
  ap <- tabulate(P[P > 0], nbins = np)
  matched_g <- logical(ng); matched_p <- logical(np)
  both <- which(G > 0 & P > 0)
  if (length(both)) {
    key <- data.table::data.table(g = G[both], p = P[both])[, list(inter = .N), by = c("g", "p")]
    pair_iou <- key$inter / (ag[key$g] + ap[key$p] - key$inter)
    hit <- pair_iou > iou
    matched_g[key$g[hit]] <- TRUE
    matched_p[key$p[hit]] <- TRUE
  }
  unl <- tabulate(P[P > 0 & !valid], nbins = np)
  fp_all <- !matched_p
  out$obj_tp <- sum(matched_g)
  out$obj_fn <- ng - sum(matched_g)
  out$obj_fp <- sum(fp_all & !(unl > 0.5 * ap))
  out$obj_fp_all <- sum(fp_all)
  out$n_pred <- np
  if (!is.na(pixel_area)) {
    sz <- cut(ag * pixel_area / 1e4, size_breaks_ha, right = FALSE, labels = FALSE)
    for (k in seq_len(length(size_breaks_ha) - 1)) {
      out[[paste0("ref_s", k)]] <- sum(sz == k, na.rm = TRUE)
      out[[paste0("hit_s", k)]] <- sum(sz == k & matched_g, na.rm = TRUE)
    }
  }
  out
}

#' Accuracy metrics from evaluation counts
#'
#' Pools the counts of [fb_evaluate()] over tiles (optionally by group) and computes
#' pixel precision, recall and IoU and object precision, recall and F1.
#'
#' @param counts Data frame of counts, one row per tile, possibly with grouping columns.
#' @param by Grouping column names, or `NULL` for one pooled summary.
#' @return A data frame of metrics; `ref_s<k>` gives the number of reference fields in
#'   size class `k` and `recall_s<k>` their recall (`NA` if the class holds no field).
#' @examples
#' s <- fb_example_stack("california")
#' f <- fb_example_files("california")
#' ref <- fb_reference(sf::st_read(f$fields, quiet = TRUE), s)
#' # fields from the PRUE probabilities of the example, with the thresholds of the fusion model
#' dl <- fb_read_probabilities(f$prue)
#' th <- fb_model_pretrained("california", "fusion")$thresholds
#' tuned <- fb_delineate(dl, thresholds = th)
#' unfiltered <- fb_delineate(dl, thresholds = th, min_size = 0)
#' ev <- rbind(cbind(method = "tuned thresholds", fb_evaluate(ref, tuned)),
#'             cbind(method = "no size filter", fb_evaluate(ref, unfiltered)))
#' fb_accuracy(ev, by = "method")
#' @export
fb_accuracy <- function(counts, by = NULL) {
  counts <- as.data.frame(counts)
  sm <- function(d) {
    s <- colSums(d[, setdiff(names(d), by), drop = FALSE])
    f1 <- function(tp, fp, fn) if (tp == 0) 0 else 2 * tp / (2 * tp + fp + fn)
    res <- data.frame(
      tiles = nrow(d),
      pixel_precision = s[["tp"]] / (s[["tp"]] + s[["fp"]]),
      pixel_recall = s[["tp"]] / (s[["tp"]] + s[["fn"]]),
      pixel_iou = s[["tp"]] / (s[["tp"]] + s[["fp"]] + s[["fn"]]),
      reference_fields = s[["obj_tp"]] + s[["obj_fn"]],
      predicted_fields = s[["n_pred"]],
      obj_precision = s[["obj_tp"]] / (s[["obj_tp"]] + s[["obj_fp"]]),
      obj_recall = s[["obj_tp"]] / (s[["obj_tp"]] + s[["obj_fn"]]),
      obj_f1 = f1(s[["obj_tp"]], s[["obj_fp"]], s[["obj_fn"]])
    )
    for (r in grep("^ref_s[0-9]+$", names(s), value = TRUE)) {
      k <- sub("ref_s", "", r)
      res[[paste0("ref_s", k)]] <- s[[r]]
      res[[paste0("recall_s", k)]] <- if (s[[r]] > 0) s[[paste0("hit_s", k)]] / s[[r]] else NA_real_
    }
    res
  }
  if (is.null(by)) return(sm(counts))
  sp <- split(counts, counts[by], drop = TRUE)
  out <- do.call(rbind, lapply(names(sp), function(nm) cbind(unique(sp[[nm]][by]), sm(sp[[nm]]))))
  rownames(out) <- NULL
  out
}

#' Paired bootstrap of accuracy differences between methods
#'
#' Tiles are resampled with replacement (within strata, if given); the same resampled
#' tiles are used for both methods of a comparison.
#'
#' @param counts Data frame with columns `tile`, `method`, optionally `stratum`, and the
#'   count columns of [fb_evaluate()].
#' @param comparisons Two-column matrix (or a length-2 vector) of method names; the
#'   difference is first minus second.
#' @param metric `"obj_f1"`, `"obj_recall"` or `"obj_precision"`.
#' @param B Number of bootstrap resamples.
#' @param seed Random seed.
#' @return A data frame with the observed difference and the 2.5 and 97.5 percentiles of
#'   the bootstrap differences.
#' @examples
#' s <- fb_example_stack("california")
#' f <- fb_example_files("california")
#' ref <- fb_reference(sf::st_read(f$fields, quiet = TRUE), s)
#' m <- fb_model_pretrained("general")
#' fu <- fb_model_pretrained("general", "fusion")
#' maps <- fb_tbc_maps(s, m)
#' fused <- fb_fuse(maps, fb_read_probabilities(f$prue), fu)
#' fields <- list(TBC = fb_delineate(maps, thresholds = m$thresholds),
#'                FUSION = fb_delineate(fused, thresholds = fu$thresholds))
#' # the example window cut into four quarters, standing in for tiles
#' e <- as.vector(terra::ext(ref)); xm <- mean(e[1:2]); ym <- mean(e[3:4])
#' quarters <- list(c(e[1], xm, ym, e[4]), c(xm, e[2], ym, e[4]),
#'                  c(e[1], xm, e[3], ym), c(xm, e[2], e[3], ym))
#' counts <- do.call(rbind, lapply(seq_along(quarters), function(k) {
#'   q <- terra::ext(quarters[[k]])
#'   do.call(rbind, lapply(names(fields), function(nm)
#'     cbind(tile = k, method = nm, fb_evaluate(terra::crop(ref, q), terra::crop(fields[[nm]], q)))))
#' }))
#' fb_bootstrap(counts, c("FUSION", "TBC"), B = 500)
#' @export
fb_bootstrap <- function(counts, comparisons, metric = c("obj_f1", "obj_recall", "obj_precision"), B = 2000L, seed = 1L) {
  metric <- match.arg(metric)
  counts <- as.data.frame(counts)
  if (is.null(dim(comparisons))) comparisons <- matrix(comparisons, ncol = 2)
  if (is.null(counts$stratum)) counts$stratum <- "all"
  tiles <- unique(counts[, c("tile", "stratum")])
  stat <- function(x) {
    s <- colSums(x)
    switch(metric,
           obj_f1 = if (s[1] == 0) 0 else 2 * s[1] / (2 * s[1] + s[2] + s[3]),
           obj_recall = s[1] / (s[1] + s[3]),
           obj_precision = s[1] / (s[1] + s[2]))
  }
  arr <- lapply(unique(c(comparisons)), function(m) {
    d <- counts[counts$method == m, ]
    d <- d[match(tiles$tile, d$tile), ]
    if (anyNA(d$obj_tp)) stop("method ", m, " lacks some tiles")
    cbind(d$obj_tp, d$obj_fp, d$obj_fn)
  })
  names(arr) <- unique(c(comparisons))
  set.seed(seed)
  strata <- split(seq_len(nrow(tiles)), tiles$stratum)
  idx <- replicate(B, unlist(lapply(strata, function(i) i[sample.int(length(i), length(i), replace = TRUE)]), use.names = FALSE),
                   simplify = FALSE)
  do.call(rbind, lapply(seq_len(nrow(comparisons)), function(k) {
    a <- arr[[comparisons[k, 1]]]; b <- arr[[comparisons[k, 2]]]
    bs <- vapply(idx, function(i) stat(a[i, , drop = FALSE]) - stat(b[i, , drop = FALSE]), 0)
    data.frame(comparison = paste(comparisons[k, 1], "-", comparisons[k, 2]), metric = metric,
               difference = stat(a) - stat(b), lo = stats::quantile(bs, 0.025, names = FALSE),
               hi = stats::quantile(bs, 0.975, names = FALSE))
  }))
}

#' Area under the ROC curve
#'
#' Probability that a random positive scores higher than a random negative (ties count
#' one half), computed from ranks.
#'
#' @param score Numeric scores.
#' @param y Binary labels (1 positive, 0 negative).
#' @return The AUC, or `NA` if one class is missing.
#' @examples
#' fb_auc(c(0.1, 0.4, 0.35, 0.8), c(0, 0, 1, 1))
#' @export
fb_auc <- function(score, y) {
  ok <- is.finite(score) & !is.na(y)
  score <- score[ok]; y <- y[ok]
  n1 <- as.numeric(sum(y == 1)); n0 <- as.numeric(sum(y == 0))
  if (n1 == 0 || n0 == 0) return(NA_real_)
  r <- data.table::frank(score, ties.method = "average")
  (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}
