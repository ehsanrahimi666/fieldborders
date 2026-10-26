# Precomputed results of the article "Map a new area from Sentinel-2" (vignettes/new-area.Rmd):
# the download of a monthly Sentinel-2 series for a centre pivot and small plots near Jovein, Khorasan
# Razavi, Iran (2024), and the figures made from it with the pretrained models.
# Run from the project root:  Rscript release/fieldborders/data-raw/vignette_new_area.R <download|figures>
suppressPackageStartupMessages({ library(terra) })
library(fieldborders)
step <- commandArgs(trailingOnly = TRUE)[1]
work <- "data/derived/package_vignettes/jovein"
fig_dir <- "release/fieldborders/vignettes/figures"
aoi <- c(57.436, 36.606, 57.454, 36.620)

if (step == "download") {
  t0 <- Sys.time()
  out <- capture.output(s <- fb_s2_monthly(aoi, "2024-01-01", "2024-12-31", dir = work), type = "message")
  writeLines(c(out, sprintf("elapsed minutes: %.1f", as.numeric(Sys.time() - t0, units = "mins"))),
             file.path(work, "download_messages.txt"))
  writeLines(capture.output(print(s)), file.path(work, "stack_print.txt"))
  writeLines(attr(s, "items"), file.path(work, "scene_ids.txt"))
  print(s)
}

if (step == "figures") {
  suppressPackageStartupMessages({ library(ggplot2); library(patchwork) })
  dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
  save_fig <- function(p, name, width, height) {
    ggsave(file.path(fig_dir, name), p, width = width, height = height, units = "mm", dpi = 150, bg = "white")
  }
  idx <- read.csv(file.path(work, "s2_index.csv"))
  s <- fb_read_stack(idx$image, bands = fb_example_bands(), dates = idx$date, clear = idx$clear)
  # the images of six months
  ks <- c(2, 4, 6, 7, 8, 10)
  p <- wrap_plots(lapply(ks, function(k) fb_plot_rgb(s, date = k) + labs(subtitle = NULL) +
                           theme(plot.title = element_text(size = 9))), nrow = 1)
  save_fig(p, "new-area-months.png", 180, 42)
  # fields with the pretrained general model
  res <- fb_fields(s)
  writeLines(capture.output(print(res$polygons, n = 5)), file.path(work, "polygons_print.txt"))
  save_fig(fb_plot_fields(res$fields, s, date = 7, fill_alpha = 0.4), "new-area-fields.png", 120, 120)
  # with the PRUE B3 deep model
  dl <- fb_prue_predict(s, months = c(3, 7), model = "data/derived/prue_b3_ccby_torchscript.pt")
  res2 <- fb_fields(s, dl = dl)
  p2 <- fb_plot_fields(res$fields, s, date = 7, fill_alpha = 0.4, title = "TBC") +
    fb_plot_fields(res2$fields, s, date = 7, fill_alpha = 0.4, title = "TBC + PRUE B3")
  save_fig(p2, "new-area-fusion.png", 180, 95)
  # smaller minimum field size than the model's (about 1.1 ha)
  m <- fb_model_pretrained("general")
  small <- fb_delineate(res$maps, thresholds = m$thresholds, min_area = 2500)
  p_small <- fb_polygons(small)
  save_fig(fb_plot_fields(res$fields, s, date = 7, fill_alpha = 0.4, title = "Minimum field size 1.1 ha (model)") +
             fb_plot_fields(small, s, date = 7, fill_alpha = 0.4, title = "Minimum field size 0.25 ha"),
           "new-area-min-area.png", 180, 95)
  writeLines(c(sprintf("TBC: %d fields, median %.1f ha", nrow(res$polygons), median(res$polygons$area_ha)),
               sprintf("TBC + PRUE B3: %d fields, median %.1f ha", nrow(res2$polygons), median(res2$polygons$area_ha)),
               sprintf("TBC, min_area 2500: %d fields, median %.1f ha", nrow(p_small), median(p_small$area_ha)),
               sprintf("model min_area (m2): %.0f", m$thresholds$min_area)),
             file.path(work, "field_counts.txt"))
}
