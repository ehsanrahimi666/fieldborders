# Precomputed results of the article "Gallery" (vignettes/gallery.Rmd): monthly Sentinel-2 series of
# about 1.6 km boxes in several farming regions, downloaded with fb_s2_monthly(), and the fields
# delineated in them with the pretrained general model.
# Run from the project root:  Rscript release/fieldborders/data-raw/vignette_gallery.R <download|figures> [site ...]
suppressPackageStartupMessages({ library(terra) })
library(fieldborders)
args <- commandArgs(trailingOnly = TRUE)
step <- args[1]
work <- "data/derived/package_vignettes/gallery"
fig_dir <- "release/fieldborders/vignettes/figures"

# centre (longitude, latitude) and season of each site; the box is about 1.6 km across. The Egypt box
# is the one with the largest share of vegetated pixels (NDVI > 0.3, 60 m, July 2024) within
# 28.35-28.67 E, 22.47-22.77 N (data-raw/locate_box.R), because a box at the region centre held desert.
# The Khuzestan box is centred on the Haft Tappeh tile of the Iran demonstration of the validation.
sites <- data.frame(
  site = c("ukraine", "argentina", "egypt", "france", "khuzestan", "punjab"),
  label = c("Poltava Oblast, Ukraine", "Pergamino, Argentina", "East Oweinat, Egypt", "Beauce, France",
            "Haft Tappeh, Khuzestan, Iran", "Ludhiana, Punjab, India"),
  lon = c(33.30, -60.45, 28.6584, 1.65, 48.3632, 75.65),
  lat = c(50.30, -33.85, 22.5527, 48.32, 32.0069, 30.85),
  start = c("2024-01-01", "2023-07-01", "2024-01-01", "2024-01-01", "2024-01-01", "2024-01-01"),
  end = c("2024-12-31", "2024-06-30", "2024-12-31", "2024-12-31", "2024-12-31", "2024-12-31"),
  stringsAsFactors = FALSE)
selected <- if (length(args) > 1) args[-1] else sites$site
box <- function(lon, lat, half_km = 0.8) {
  dlat <- half_km / 111.32
  dlon <- half_km / (111.32 * cos(lat * pi / 180))
  c(lon - dlon, lat - dlat, lon + dlon, lat + dlat)
}

if (step == "download") {
  for (st in selected) {
    r <- sites[sites$site == st, ]
    d <- file.path(work, st)
    if (file.exists(file.path(d, "s2_index.csv"))) next
    t0 <- Sys.time()
    s <- tryCatch(fb_s2_monthly(box(r$lon, r$lat), r$start, r$end, dir = d), error = function(e) { message(st, ": ", conditionMessage(e)); NULL })
    if (is.null(s)) next
    writeLines(c(capture.output(print(s)), attr(s, "items"), sprintf("minutes %.1f", as.numeric(Sys.time() - t0, units = "mins"))),
               file.path(d, "download_record.txt"))
    message(st, " done")
  }
}

if (step == "figures") {
  suppressPackageStartupMessages({ library(ggplot2); library(patchwork) })
  dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
  # the date of highest median NDVI is shown as background
  greenest <- function(s) {
    nb <- length(s$bands)
    v <- vapply(seq_along(s$dates), function(k) {
      r <- s$data[[(k - 1) * nb + match(c("B08", "B04"), s$bands)]]
      x <- terra::values(r, mat = TRUE)
      stats::median((x[, 1] - x[, 2]) / (x[, 1] + x[, 2] + 1e-4), na.rm = TRUE)
    }, 0)
    which.max(v)
  }
  m <- fb_model_pretrained("general")
  done <- sites[file.exists(file.path(work, sites$site, "s2_index.csv")) & sites$site %in% selected, ]
  panels <- list(); rec <- list()
  for (i in seq_len(nrow(done))) {
    idx <- read.csv(file.path(work, done$site[i], "s2_index.csv"))
    s <- fb_read_stack(idx$image, bands = fb_example_bands(), dates = idx$date, clear = idx$clear)
    res <- fb_fields(s, m)
    k <- greenest(s)
    panels[[i]] <- fb_plot_fields(res$fields, s, date = k, fill_alpha = 0.35, title = done$label[i]) +
      labs(subtitle = sprintf("%s, %d fields", format(s$dates[k], "%B %Y"), nrow(res$polygons))) +
      theme(plot.title = element_text(size = 9), plot.subtitle = element_text(size = 7.5))
    rec[[i]] <- data.frame(site = done$site[i], dates = length(s$dates), date_shown = format(s$dates[k]),
                           fields = nrow(res$polygons), median_area_ha = stats::median(res$polygons$area_ha))
  }
  ggsave(file.path(fig_dir, "gallery.png"), wrap_plots(panels, ncol = 3), width = 180, height = 130, units = "mm",
         dpi = 150, bg = "white")
  write.csv(do.call(rbind, rec), file.path(work, "gallery_fields.csv"), row.names = FALSE)
  print(do.call(rbind, rec))
}

# The scene classification marked every scene of the series as clear. Scenes that are visibly snow-covered,
# cloudy or hazy in true colour (judged from the images, before any delineation) are dropped here to show
# how much they affect the fields.
if (step == "dates") {
  affected <- list(ukraine = c("2024-01-12", "2024-04-16"), france = "2024-03-05",
                   punjab = c("2024-07-30", "2024-08-24", "2024-10-28"))
  m <- fb_model_pretrained("general")
  rec <- list()
  for (st in names(affected)) {
    idx <- read.csv(file.path(work, st, "s2_index.csv"))
    s <- fb_read_stack(idx$image, bands = fb_example_bands(), dates = idx$date, clear = idx$clear)
    keep <- !format(fb_dates(s)) %in% affected[[st]]
    stopifnot(sum(!keep) == length(affected[[st]]))
    s2 <- fb_subset_dates(s, keep)
    a <- fb_fields(s, m)
    b <- fb_fields(s2, m)
    rec[[st]] <- data.frame(site = st, dates_dropped = paste(affected[[st]], collapse = " "),
                            dates_all = length(keep), fields_all = nrow(a$polygons),
                            median_ha_all = stats::median(a$polygons$area_ha),
                            dates_kept = sum(keep), fields_kept = nrow(b$polygons),
                            median_ha_kept = stats::median(b$polygons$area_ha))
  }
  out <- do.call(rbind, rec)
  write.csv(out, file.path(work, "gallery_dropped_dates.csv"), row.names = FALSE)
  print(out)
}
