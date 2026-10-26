# Package logo (man/figures/logo.png): fields delineated with the pretrained general model in the
# gallery box of Beauce, France (data-raw/vignette_gallery.R), drawn inside a hexagon; outlines are
# simplified (5 m) and fields smaller than 1 ha left out, for legibility at small size.
# Run from the project root:  Rscript release/fieldborders/data-raw/logo.R
suppressPackageStartupMessages({ library(fieldborders); library(ggplot2) })
idx <- read.csv("data/derived/package_vignettes/gallery/france/s2_index.csv")
s <- fb_read_stack(idx$image, bands = fb_example_bands(), dates = idx$date, clear = idx$clear)
res <- fb_fields(s)
p <- sf::st_simplify(res$polygons[res$polygons$area_ha >= 1, ], preserveTopology = TRUE, dTolerance = 5)
bb <- sf::st_bbox(res$polygons)
cx <- mean(bb[c("xmin", "xmax")]); cy <- mean(bb[c("ymin", "ymax")])
r <- 0.98 * min((bb[["xmax"]] - bb[["xmin"]]) / sqrt(3), (bb[["ymax"]] - bb[["ymin"]]) / 2)
ang <- seq(90, 450, by = 60) * pi / 180
hex <- sf::st_sfc(sf::st_polygon(list(cbind(cx + r * cos(ang), cy + r * sin(ang)))), crs = sf::st_crs(p))
inner <- suppressWarnings(sf::st_intersection(sf::st_make_valid(sf::st_geometry(p)), hex))
inner <- sf::st_sf(geometry = inner[sf::st_dimension(inner) == 2])
pal <- c("#F2C14E", "#A9C46C", "#E3A73C", "#7FAE5E", "#CFDB8E", "#DE9A62", "#B8D27A", "#EBCB6E")
inner$col <- pal[(seq_len(nrow(inner)) - 1) %% length(pal) + 1]
m <- 0.06 * r
g <- ggplot() +
  geom_sf(data = hex, fill = "#2B2721", colour = NA) +
  geom_sf(data = inner, aes(fill = col), colour = "#FFF8E6", linewidth = 0.3) +
  geom_sf(data = hex, fill = NA, colour = "#8E1B26", linewidth = 1.6) +
  annotate("label", x = cx, y = cy - 0.55 * r, label = "fieldborders", size = 5.6, fontface = "bold",
           colour = "white", fill = "#8E1B26", linewidth = 0, label.r = unit(0.15, "lines")) +
  scale_fill_identity() +
  coord_sf(xlim = c(cx - sqrt(3) / 2 * r - m, cx + sqrt(3) / 2 * r + m), ylim = c(cy - r - m, cy + r + m),
           datum = NA, expand = FALSE) +
  theme_void() + theme(plot.background = element_rect(fill = "transparent", colour = NA))
ggsave("release/fieldborders/man/figures/logo.png", g, width = 50, height = 57.7, units = "mm", dpi = 300, bg = "transparent")
