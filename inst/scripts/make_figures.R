# Figures of the README (man/figures) made from the example data and the pretrained models.
# Run from the package source folder:  Rscript inst/scripts/make_figures.R
library(fieldborders)
library(ggplot2)
library(patchwork)

out <- file.path("man", "figures")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
save_fig <- function(p, name, width, height) {
  ggsave(file.path(out, name), p, width = width, height = height, units = "mm", dpi = 300, bg = "white")
}
m <- fb_model_pretrained("general")
fu <- fb_model_pretrained("general", "fusion")
summer <- c(california = 7, washington = 7, brazil = 7, moghan = 7)   # date index shown for each example
titles <- c(california = "California", washington = "Washington", brazil = "Brazil", moghan = "Iran")
places <- c(california = "Sacramento Valley", washington = "Columbia Basin", brazil = "Tocantins",
            moghan = "Moghan plain")
panel <- function(p, tag, title, subtitle = NULL) {
  p + labs(title = paste0(tag, "  ", title), subtitle = subtitle) +
    theme(plot.title = element_text(size = 8.5, face = "bold"), plot.subtitle = element_text(size = 7),
          legend.position = "none", plot.margin = margin(2, 3, 2, 3))
}
prob_panel <- function(r, layer, option, tag, title) {
  d <- as.data.frame(r[[layer]], xy = TRUE)
  names(d)[3] <- "value"
  e <- as.vector(terra::ext(r))
  ggplot(d, aes(x, y, fill = value)) + geom_raster() +
    scale_fill_viridis_c(option = option, limits = c(0, 1), breaks = c(0, 0.5, 1), name = "Probability",
                         guide = guide_colourbar(title.position = "top", title.hjust = 0.5,
                                                 barwidth = unit(24, "mm"), barheight = unit(1.8, "mm"))) +
    coord_fixed(ratio = 1 / cos(mean(e[3:4]) * pi / 180), expand = FALSE) +
    labs(title = paste0(tag, "  ", title)) + fb_theme() +
    theme(axis.text = element_blank(), plot.title = element_text(size = 8.5, face = "bold"),
          legend.position = "bottom", legend.title = element_text(size = 6.5), legend.text = element_text(size = 6),
          legend.margin = margin(0, 0, 0, 0), plot.margin = margin(2, 3, 2, 3))
}

## Overview: one example from image to fields
s <- fb_example_stack("washington")
maps <- fb_tbc_maps(s, m)
fields <- fb_delineate(maps, thresholds = m$thresholds)
d7 <- format(s$dates[summer[["washington"]]], "%d %B %Y")
p1 <- panel(fb_plot_rgb(s, date = summer[["washington"]]), "a", "Sentinel-2", d7)
p2 <- prob_panel(maps, "edge", "magma", "b", "Edge probability")
p3 <- prob_panel(maps, "cropland", "viridis", "c", "Cropland probability")
p4 <- panel(fb_plot_fields(fields, s, date = summer[["washington"]], fill_alpha = 0.45), "d", "Fields",
            sprintf("%d fields", length(unique(terra::values(fields)[terra::values(fields) > 0]))))
save_fig(p1 + p2 + p3 + p4 + plot_layout(nrow = 1), "README-overview.png", 174, 78)

## Four landscapes: image and delineated fields (TBC + PRUE B3)
rows <- lapply(fb_example_names(), function(nm) {
  s <- fb_example_stack(nm)
  dl <- fb_read_probabilities(fb_example_files(nm)$prue)
  fused <- fb_fuse(fb_tbc_maps(s, m), dl, fu)
  fl <- fb_delineate(fused, thresholds = fu$thresholds)
  k <- summer[[nm]]
  list(img = panel(fb_plot_rgb(s, date = k), "", titles[[nm]], paste0(places[[nm]], ", ", format(s$dates[k], "%B %Y"))),
       fld = panel(fb_plot_fields(fl, s, date = k, fill_alpha = 0.5), "", "", NULL))
})
tags <- letters[1:8]
imgs <- Map(function(r, t) r$img + labs(title = paste0(t, "  ", r$img$labels$title)), rows, tags[1:4])
flds <- Map(function(r, t) r$fld + labs(title = paste0(t, "  Fields, TBC + PRUE B3")), rows, tags[5:8])
save_fig(wrap_plots(c(imgs, flds), nrow = 2), "README-landscapes.png", 174, 122)

## Feature ranking on the California example
s_ca <- fb_example_stack("california")
f_ca <- fb_example_files("california")
ref_poly <- sf::st_read(f_ca$fields, quiet = TRUE)
ref <- fb_reference(ref_poly, s_ca)
rk <- fb_rank_contrast(s_ca, ref, n_pairs = 4000)
sel <- fb_select_features(rk, k = 8)
save_fig(fb_plot_ranking(rk, n = 20, selected = sel) + theme(plot.margin = margin(4, 8, 4, 4)),
         "README-ranking.png", 120, 110)

## Fusion on the California example
maps_ca <- fb_tbc_maps(s_ca, m)
dl <- fb_read_probabilities(f_ca$prue)
fused <- fb_fuse(maps_ca, dl, fu)
e1 <- prob_panel(dl, "boundary", "magma", "a", "PRUE B3 boundary")
e2 <- prob_panel(maps_ca, "edge", "magma", "b", "TBC edge")
e3 <- prob_panel(fused, "edge", "magma", "c", "Fused edge")
counts <- rbind(
  cbind(method = "PRUE B3", fb_evaluate(ref, fb_delineate(dl, thresholds = fu$thresholds))),
  cbind(method = "TBC", fb_evaluate(ref, fb_delineate(maps_ca, thresholds = m$thresholds))),
  cbind(method = "TBC + PRUE B3", fb_evaluate(ref, fb_delineate(fused, thresholds = fu$thresholds))))
acc_tab <- fb_accuracy(counts, by = "method")
acc <- fb_plot_accuracy(acc_tab) +
  labs(title = sprintf("d  Field objects in this window (%d reference fields)", acc_tab$reference_fields[1])) +
  theme(plot.title = element_text(size = 8.5, face = "bold"), legend.text = element_text(size = 7))
save_fig((e1 + e2 + e3) / acc + plot_layout(heights = c(1.4, 1)), "README-fusion.png", 174, 150)

## Validation summary: object F1 in California and Washington, object recall in Brazil (partial labels)
va <- read.csv(system.file("extdata", "validation", "object_accuracy.csv", package = "fieldborders"))
va <- va[va$analysis == "primary", ]
f1 <- va$primary_metric == "obj_f1"
va$value <- ifelse(f1, va$obj_f1, va$obj_recall)
va$lo <- ifelse(f1, va$f1_lo, va$recall_lo)
va$hi <- ifelse(f1, va$f1_hi, va$recall_hi)
rng <- function(x) if (min(x) == max(x)) format(min(x), big.mark = ",") else
  paste0(format(min(x), big.mark = ","), "-", format(max(x), big.mark = ","))
lab <- vapply(split(va, va$region), function(d) {
  sprintf("%s %s\n%s\n%s test tiles, %s fields", d$region[1], d$season[1],
          if (d$primary_metric[1] == "obj_f1") "object F1" else "object recall", rng(d$test_tiles), rng(d$reference_fields))
}, "")
va$panel <- factor(lab[va$region], levels = lab[c("California", "Washington", "Brazil")])
va$method <- factor(va$method, levels = c("USDA Crop Sequence Boundaries", "FTW global field map", "PRUE B3",
                                          "PRUE B3 + object procedure", "PRUE B7 + object procedure",
                                          "Multi-temporal Canny + object procedure", "TBC", "TBC + PRUE B3",
                                          "TBC + PRUE B7"))
cols <- c(`Existing product` = "#5F5F5F", `Deep model` = "#3A7DC9", `Edge-detection baseline` = "#9A7BB5",
          TBC = "#C8323F", `TBC + deep model` = "#8E1B26")
pv <- ggplot(va, aes(value, method, colour = family)) +
  geom_errorbar(aes(xmin = lo, xmax = hi), width = 0, linewidth = 0.7, orientation = "y") +
  geom_point(size = 2) +
  geom_text(aes(x = hi, label = sprintf("%.2f", value)), hjust = -0.3, size = 2.4, show.legend = FALSE) +
  facet_wrap(~panel, nrow = 1) +
  scale_colour_manual(values = cols, breaks = names(cols), name = NULL) +
  scale_x_continuous(limits = c(0, 0.85), breaks = seq(0, 0.8, 0.2)) +
  labs(x = "Object accuracy with 95 % bootstrap interval (IoU > 0.5)", y = NULL) +
  fb_theme(base_size = 8) +
  theme(legend.position = "bottom", legend.text = element_text(size = 7), axis.title.x = element_text(size = 7.5),
        strip.text = element_text(size = 7), panel.spacing.x = unit(5, "mm"), plot.margin = margin(4, 8, 4, 4))
save_fig(pv, "README-validation.png", 174, 82)

## Workflow
round_rect <- function(x0, y0, x1, y1, r = 0.12, n = 8) {
  a <- seq(0, pi / 2, length.out = n)
  cx <- c(x1 - r, x0 + r, x0 + r, x1 - r); cy <- c(y1 - r, y1 - r, y0 + r, y0 + r)
  st <- c(0, pi / 2, pi, 3 * pi / 2)
  do.call(rbind, lapply(1:4, function(k) data.frame(x = cx[k] + r * cos(st[k] + a), y = cy[k] + r * sin(st[k] + a))))
}
stage <- list(data = c(fill = "#EEF2F7", line = "#5B7DA8"), tbc = c(fill = "#FBEAEC", line = "#C8323F"),
              deep = c(fill = "#EAF2FB", line = "#3A7DC9"), out = c(fill = "#EDF6EE", line = "#3E8E4E"))
boxes <- data.frame(
  id = c("s2", "rank", "train", "maps", "obj", "poly", "ref", "deep", "fuse", "acc"),
  x = c(1, 3, 5, 7, 9, 11, 3, 7, 9, 11),
  y = c(2.3, 2.3, 2.3, 2.3, 2.3, 2.3, 0.6, 0.6, 0.6, 0.6),
  stage = c("data", "tbc", "tbc", "tbc", "out", "out", "data", "deep", "deep", "out"),
  title = c("Sentinel-2 series", "Border contrast", "TBC models", "Probability maps", "Field objects", "Polygons",
            "Reference fields", "Deep model", "Fusion", "Accuracy"),
  body = c("fb_s2_monthly()\nfb_read_stack()\nmonthly, 10 bands",
           "fb_rank_contrast()\nfeatures ranked by\nseasonal contrast",
           "fb_train() or\nfb_model_pretrained()\nedge + cropland",
           "fb_tbc_maps()\nborder and cropland\nprobability",
           "fb_delineate()\nseeded watershed\nfb_tune()",
           "fb_polygons()\narea, perimeter,\ncompactness",
           "fb_reference()\nfield, boundary,\nbackground",
           "fb_prue_predict()\nFTW PRUE in R\n(optional)",
           "fb_fuse()\nlogistic\ncombination",
           "fb_evaluate()\nFTW object metric\nfb_bootstrap()"),
  stringsAsFactors = FALSE)
w <- 0.86; h <- 0.55
shapes <- do.call(rbind, lapply(seq_len(nrow(boxes)), function(i) {
  cbind(round_rect(boxes$x[i] - w, boxes$y[i] - h, boxes$x[i] + w, boxes$y[i] + h), id = boxes$id[i], stage = boxes$stage[i])
}))
arrow_df <- function(from, to, dx0 = 0, dy0 = 0, dx1 = 0, dy1 = 0) {
  a <- boxes[boxes$id == from, ]; b <- boxes[boxes$id == to, ]
  data.frame(x = a$x + dx0, y = a$y + dy0, xend = b$x + dx1, yend = b$y + dy1)
}
arrows <- rbind(arrow_df("s2", "rank", w, 0, -w, 0), arrow_df("rank", "train", w, 0, -w, 0),
                arrow_df("train", "maps", w, 0, -w, 0), arrow_df("maps", "obj", w, 0, -w, 0),
                arrow_df("obj", "poly", w, 0, -w, 0), arrow_df("ref", "rank", 0, h, 0, -h),
                arrow_df("deep", "fuse", w, 0, -w, 0), arrow_df("maps", "fuse", 0.5, -h, -0.5, h),
                arrow_df("fuse", "obj", 0, h, 0, -h), arrow_df("obj", "acc", 0.5, -h, -0.5, h))
fills <- vapply(stage, `[[`, "", "fill"); lines <- vapply(stage, `[[`, "", "line")
pw <- ggplot() +
  geom_polygon(data = shapes, aes(x, y, group = id, fill = stage, colour = stage), linewidth = 0.45) +
  geom_segment(data = arrows, aes(x, y, xend = xend, yend = yend), colour = "grey35", linewidth = 0.4,
               arrow = arrow(length = unit(1.5, "mm"), type = "closed")) +
  geom_text(data = boxes, aes(x, y + 0.33, label = title), fontface = "bold", size = 2.55) +
  geom_text(data = boxes, aes(x, y - 0.12, label = body), size = 2.15, colour = "grey20", lineheight = 0.95) +
  scale_fill_manual(values = fills, guide = "none") + scale_colour_manual(values = lines, guide = "none") +
  coord_fixed(xlim = c(0.05, 11.95), ylim = c(-0.02, 2.92), expand = FALSE) +
  theme_void() + theme(plot.background = element_rect(fill = "white", colour = NA))
save_fig(pw, "README-workflow.png", 174, 46)
