# Validation results shipped with the package (inst/extdata/validation/object_accuracy.csv):
# object accuracy of each method on the test tiles of the validation regions, compiled from the
# summary tables of the validation pipeline. Run from the project root:
#   Rscript release/fieldborders/data-raw/validation_table.R
suppressPackageStartupMessages(library(data.table))
out_dir <- "release/fieldborders/inst/extdata/validation"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
cols <- c("region", "season", "analysis", "models", "method", "family", "test_tiles", "reference_fields",
          "obj_precision", "obj_recall", "obj_f1", "f1_lo", "f1_hi", "recall_lo", "recall_hi", "primary_metric")

# California 2024: models fitted and thresholds tuned on California tiles; primary design (pre-specified
# threshold grid), all reference fields
ca_methods <- data.table(
  mkey = c("products:USDA_CSB_2024", "products:FTW_GLOBAL_2024", "primary:P0", "primary:P2", "R1:P2",
           "R9:TBC", "primary:TBC", "primary:FUSION", "R1:FUSION"),
  method = c("USDA Crop Sequence Boundaries", "FTW global field map", "PRUE B3", "PRUE B3 + object procedure",
             "PRUE B7 + object procedure", "Multi-temporal Canny + object procedure", "TBC",
             "TBC + PRUE B3", "TBC + PRUE B7"),
  family = c("Existing product", "Existing product", "Deep model", "Deep model", "Deep model",
             "Edge-detection baseline", "TBC", "TBC + deep model", "TBC + deep model"))
tab <- fread("output/phase1c/summary/comparison_table.csv")[regime == "all"]
ci <- fread("output/phase1c/summary/f1_intervals.csv")
ca <- merge(ca_methods, tab[, .(mkey, test_tiles = n_chips, reference_fields = ref_objects, obj_precision, obj_recall, obj_f1)],
            by = "mkey", sort = FALSE)
ca <- merge(ca, ci[, .(mkey, f1_lo = lo, f1_hi = hi)], by = "mkey", sort = FALSE)
stopifnot(nrow(ca) == nrow(ca_methods), all(abs(ca$obj_f1 - ci[match(ca$mkey, ci$mkey), f1]) < 1e-12))
ca[, `:=`(region = "California", season = "2024", analysis = "primary", models = "fitted and tuned in California",
          recall_lo = NA_real_, recall_hi = NA_real_, primary_metric = "obj_f1")]
ca <- ca[match(ca_methods$mkey, mkey)]

# Washington (2024 or 2025 by tile) and Brazil (2019/20): pre-specified comparisons of the second validation.
# Washington models were fitted and tuned on Washington tiles; Brazil was mapped with models fitted and tuned
# on California and Washington tiles together, without Brazilian labels.
d_methods <- data.table(
  mkey = c("wa_products:FTW_GLOBAL", "wa_primary:P0", "wa_primary:P2", "wa_R1_b7:P2", "wa_canny:TBC", "wa_primary:TBC",
           "wa_primary:FUSION", "wa_R1_b7:FUSION",
           "br_products:FTW_GLOBAL", "br_T_POOL_b3:P0", "br_T_POOL_b3:P2", "br_T_POOL_b7:P2", "br_T_POOL_b3:TBC",
           "br_T_POOL_b3:FUSION", "br_T_POOL_b7:FUSION"),
  method = c("FTW global field map", "PRUE B3", "PRUE B3 + object procedure", "PRUE B7 + object procedure",
             "Multi-temporal Canny + object procedure", "TBC", "TBC + PRUE B3", "TBC + PRUE B7",
             "FTW global field map", "PRUE B3", "PRUE B3 + object procedure", "PRUE B7 + object procedure", "TBC",
             "TBC + PRUE B3", "TBC + PRUE B7"),
  family = c("Existing product", "Deep model", "Deep model", "Deep model", "Edge-detection baseline", "TBC",
             "TBC + deep model", "TBC + deep model",
             "Existing product", "Deep model", "Deep model", "Deep model", "TBC", "TBC + deep model", "TBC + deep model"))
tab_d <- fread("output/phase1d/summary/comparison_table.csv")[regime == "all"]
ci_d <- fread("output/phase1d/summary/intervals.csv")[regime == "all"]
dd <- merge(d_methods, tab_d[, .(mkey, region_code = region, test_tiles = tiles, reference_fields = ref_objects,
                                 obj_precision, obj_recall, obj_f1)], by = "mkey", sort = FALSE)
dd <- merge(dd, ci_d[metric == "obj_f1", .(mkey, f1_lo = lo, f1_hi = hi, f1_check = value)], by = "mkey", sort = FALSE)
dd <- merge(dd, ci_d[metric == "obj_recall", .(mkey, recall_lo = lo, recall_hi = hi, recall_check = value)], by = "mkey",
            sort = FALSE)
stopifnot(nrow(dd) == nrow(d_methods), all(abs(dd$obj_f1 - dd$f1_check) < 1e-12),
          all(abs(dd$obj_recall - dd$recall_check) < 1e-12))
dd[, `:=`(region = fifelse(region_code == "wa", "Washington", "Brazil"), analysis = "primary",
          season = fifelse(region_code == "wa", "2024 or 2025", "2019/20"),
          models = fifelse(region_code == "wa", "fitted and tuned in Washington",
                           "fitted and tuned in California and Washington"),
          primary_metric = fifelse(region_code == "wa", "obj_f1", "obj_recall"))]
dd <- dd[match(d_methods$mkey, mkey)]

# Washington, secondary analysis added after the Washington test results were seen: the same models, with
# thresholds tuned on the Washington tune tiles over the wider grid of the pretrained models (minimum object
# size up to 400 pixels)
ex_methods <- data.table(label = c("PRUE B3 + map procedure", "PRUE B7 + map procedure", "TBC", "TBC + PRUE B3",
                                   "TBC + PRUE B7"),
                         method = c("PRUE B3 + object procedure", "PRUE B7 + object procedure", "TBC", "TBC + PRUE B3",
                                    "TBC + PRUE B7"),
                         family = c("Deep model", "Deep model", "TBC", "TBC + deep model", "TBC + deep model"))
ex <- merge(ex_methods, fread("output/phase1d/summary_extended/comparison_table.csv")[
  , .(label, test_tiles = tiles, reference_fields = ref_objects, obj_precision, obj_recall, obj_f1,
      f1_lo = lo_obj_f1, f1_hi = hi_obj_f1, recall_lo = lo_obj_recall, recall_hi = hi_obj_recall)], by = "label", sort = FALSE)
stopifnot(nrow(ex) == nrow(ex_methods))
ex[, `:=`(region = "Washington", season = "2024 or 2025", analysis = "wider threshold grid (post hoc)",
          models = "fitted and tuned in Washington", primary_metric = "obj_f1")]

res <- rbind(ca[, ..cols], dd[, ..cols], ex[, ..cols])
fwrite(res, file.path(out_dir, "object_accuracy.csv"))
print(res[, .(region, analysis, method, tiles = test_tiles, fields = reference_fields, f1 = round(obj_f1, 3),
              recall = round(obj_recall, 3), primary_metric)])

# The pretrained models of the package on the test tiles of California and Washington (never used to fit or
# tune them), from the verify step of data-raw/pretrained.R; recall_s1 to recall_s5 are the recall of reference
# fields of < 1, 1-5, 5-20, 20-50 and > 50 ha
pm <- fread("data/derived/package_models/verify_test_accuracy.csv")
pm[, region := c(ca = "California", wa = "Washington")[region]]
pm <- pm[, .(model, region, method, tiles, reference_fields, predicted_fields, obj_precision, obj_recall, obj_f1,
             f1_lo, f1_hi, recall_s1, recall_s2, recall_s3, recall_s4, recall_s5)]
# the same design (California fit and tune tiles, wider threshold grid) in the validation pipeline (Phase 1c R8),
# for comparison with the R implementation of the "california" models
r8 <- fread("output/phase1c/summary/comparison_table.csv")[regime == "all" & mkey %in% c("R8:TBC", "R8:FUSION")]
r8[, `:=`(model = "california", region = "California", method = c(`R8:TBC` = "TBC", `R8:FUSION` = "TBC + PRUE B3")[mkey])]
pm <- merge(pm, r8[, .(model, region, method, pipeline_obj_precision = obj_precision, pipeline_obj_recall = obj_recall,
                       pipeline_obj_f1 = obj_f1)], by = c("model", "region", "method"), all.x = TRUE, sort = FALSE)
fwrite(pm, file.path(out_dir, "pretrained_models.csv"))
print(pm[, .(model, region, method, f1 = round(obj_f1, 3), f1_lo = round(f1_lo, 3), f1_hi = round(f1_hi, 3))])
