#' Plot theme and colours of the package
#'
#' @param base_size Base font size.
#' @return A `ggplot2` theme.
#' @examples
#' library(ggplot2)
#' ggplot(data.frame(x = 1:3, y = 1:3), aes(x, y)) + geom_point() + fb_theme()
#' @export
fb_theme <- function(base_size = 10) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(panel.grid = ggplot2::element_blank(),
                   plot.title = ggplot2::element_text(face = "bold", size = base_size + 1),
                   plot.subtitle = ggplot2::element_text(colour = "grey35", size = base_size - 1),
                   axis.text = ggplot2::element_text(colour = "grey40", size = base_size - 2),
                   axis.title = ggplot2::element_blank(),
                   strip.text = ggplot2::element_text(face = "bold", hjust = 0),
                   legend.title = ggplot2::element_text(size = base_size - 1),
                   plot.background = ggplot2::element_rect(fill = "white", colour = NA))
}

fb_cols <- c(tbc = "#C8323F", fusion = "#8E1B26", deep = "#3A7DC9", product = "#5F5F5F", reference = "#E8B12E")

# Raster reduced by block averaging to at most max_cells cells, for display.
display_raster <- function(r, max_cells) {
  f <- ceiling(sqrt(terra::ncell(r) / max_cells))
  if (f > 1) terra::aggregate(r, fact = f, fun = "mean", na.rm = TRUE) else r
}

# Colour matrix (rows north to south) of a linearly stretched true-colour composite.
rgb_image <- function(stack, date, bands, stretch, max_cells) {
  k <- if (is.numeric(date)) as.integer(date) else match(as.Date(date), stack$dates)
  if (is.na(k) || k < 1L || k > length(stack$dates)) stop("date not in the stack")
  nb <- length(stack$bands)
  lay <- (k - 1L) * nb + match(bands, stack$bands)
  if (anyNA(lay)) stop("bands not in the stack")
  r <- display_raster(stack$data[[lay]] / stack$scale, max_cells)
  v <- terra::values(r, mat = TRUE)
  lim <- stats::quantile(v, stretch, na.rm = TRUE)
  v <- pmin(pmax((v - lim[1]) / (lim[2] - lim[1]), 0), 1)
  v[!is.finite(v)] <- 0
  col <- matrix(grDevices::rgb(v[, 1], v[, 2], v[, 3]), terra::nrow(r), terra::ncol(r), byrow = TRUE)
  list(raster = grDevices::as.raster(col), ext = as.vector(terra::ext(r)), k = k)
}

#' True-colour image of one date
#'
#' @param stack An `fb_stack`.
#' @param date Date (or index of the date) to show; by default the date with the most
#'   clear pixels.
#' @param bands Red, green and blue bands.
#' @param stretch Lower and upper quantiles of the linear stretch (common to the three
#'   bands).
#' @param title Plot title; by default the date.
#' @param max_cells Images with more cells are averaged in blocks for display.
#' @return A `ggplot` object; `sf` layers can be added with `ggplot2::geom_sf()`.
#' @examples
#' fb_plot_rgb(fb_example_stack("california"), date = 7)
#' # false colour: near infrared, red, green
#' fb_plot_rgb(fb_example_stack("washington"), date = 7, bands = c("B08", "B04", "B03"))
#' @export
fb_plot_rgb <- function(stack, date = NULL, bands = c("B04", "B03", "B02"), stretch = c(0.02, 0.98), title = NULL,
                        max_cells = 1e6) {
  stopifnot(inherits(stack, "fb_stack"))
  if (is.null(date)) {
    date <- if (is.null(stack$clear)) 1L else which.max(terra::global(stack$clear, "mean", na.rm = TRUE)$mean)
  }
  img <- rgb_image(stack, date, bands, stretch, max_cells)
  e <- unname(img$ext)
  sub <- if (identical(bands, c("B04", "B03", "B02"))) "Sentinel-2 true colour" else paste("Sentinel-2", paste(bands, collapse = ", "))
  ggplot2::ggplot() +
    ggplot2::annotation_raster(img$raster, xmin = e[1], xmax = e[2], ymin = e[3], ymax = e[4], interpolate = FALSE) +
    extent_layer(stack$data, e) +
    map_coord(stack$data, e) +
    ggplot2::labs(title = if (is.null(title)) format(stack$dates[img$k], "%d %B %Y") else title, subtitle = sub) +
    fb_theme()
}

# Map coordinates of a raster: its CRS and extent, no graticule, no expansion. Marked as the
# default coordinate system, so that sf layers added later replace it without a message; the
# invisible extent layer and the zero scale expansion then keep the image extent.
map_coord <- function(r, e = as.vector(terra::ext(r))) {
  e <- unname(e)
  crs <- sf::st_crs(terra::crs(r))
  ggplot2::coord_sf(crs = crs, default_crs = crs, xlim = e[1:2], ylim = e[3:4], datum = NA, expand = FALSE,
                    default = TRUE)
}

extent_layer <- function(r, e = as.vector(terra::ext(r))) {
  e <- unname(e)
  bb <- sf::st_as_sfc(sf::st_bbox(c(xmin = e[1], ymin = e[3], xmax = e[2], ymax = e[4]), crs = sf::st_crs(terra::crs(r))))
  list(ggplot2::geom_sf(data = sf::st_sf(geometry = bb), fill = NA, colour = NA, inherit.aes = FALSE),
       ggplot2::scale_x_continuous(expand = c(0, 0)), ggplot2::scale_y_continuous(expand = c(0, 0)))
}

# Cartesian coordinates with the aspect ratio of the map (longitude shortened by the
# cosine of latitude for geographic coordinates).
map_fixed <- function(r) {
  e <- as.vector(terra::ext(r))
  ratio <- if (terra::is.lonlat(r)) 1 / cos(mean(e[3:4]) * pi / 180) else 1
  ggplot2::coord_fixed(ratio = ratio, expand = FALSE)
}

#' Map layers (edge, cropland or class probabilities)
#'
#' @param maps A `SpatRaster` with probability layers, such as the output of
#'   [fb_tbc_maps()], [fb_fuse()] or [fb_prue_predict()].
#' @param layers Layers to show (default all).
#' @param palette Viridis palette option (`"magma"`, `"viridis"`, ...).
#' @param max_cells Rasters with more cells are averaged in blocks for display.
#' @return A `ggplot` object with one panel per layer.
#' @examples
#' maps <- fb_tbc_maps(fb_example_stack("california"), fb_model_pretrained("california"))
#' fb_plot_maps(maps)
#' fb_plot_maps(fb_read_probabilities(fb_example_files("brazil")$prue), palette = "viridis")
#' @export
fb_plot_maps <- function(maps, layers = names(maps), palette = "magma", max_cells = 250000) {
  r <- display_raster(maps[[layers]], max_cells)
  d <- as.data.frame(r, xy = TRUE, na.rm = FALSE)
  long <- data.frame(x = rep(d$x, length(layers)), y = rep(d$y, length(layers)),
                     layer = factor(rep(layers, each = nrow(d)), levels = layers),
                     value = unlist(d[layers], use.names = FALSE))
  ggplot2::ggplot(long, ggplot2::aes(x, y, fill = value)) + ggplot2::geom_raster() +
    ggplot2::facet_wrap(~layer) +
    ggplot2::scale_fill_viridis_c(option = palette, limits = c(0, 1), breaks = c(0, 0.25, 0.5, 0.75, 1),
                                  name = "Probability",
                                  guide = ggplot2::guide_colourbar(title.position = "top", title.hjust = 0.5)) +
    map_fixed(r) + fb_theme() +
    ggplot2::theme(axis.text = ggplot2::element_blank(), legend.position = "bottom",
                   legend.key.width = ggplot2::unit(12, "mm"), legend.key.height = ggplot2::unit(3, "mm"))
}

#' Field objects or polygons over the image
#'
#' @param fields Field objects (`SpatRaster` from [fb_delineate()]) or polygons (`sf`).
#' @param stack Optional `fb_stack` shown in true colour underneath.
#' @param date Date of the background image (see [fb_plot_rgb()]).
#' @param reference Optional reference polygons (`sf`), drawn as dashed outlines.
#' @param colour Outline colour of the fields.
#' @param fill_alpha Opacity of the field fill (0 for outlines only).
#' @param title Plot title.
#' @return A `ggplot` object.
#' @examples
#' s <- fb_example_stack("moghan")
#' m <- fb_model_pretrained()
#' fields <- fb_delineate(fb_tbc_maps(s, m), thresholds = m$thresholds)
#' fb_plot_fields(fields, s, date = 7)
#' # with reference fields (dashed)
#' s2 <- fb_example_stack("california")
#' f2 <- fb_delineate(fb_tbc_maps(s2, m), thresholds = m$thresholds)
#' ref_poly <- sf::st_read(fb_example_files("california")$fields, quiet = TRUE)
#' fb_plot_fields(f2, s2, date = 7, reference = ref_poly)
#' @export
fb_plot_fields <- function(fields, stack = NULL, date = NULL, reference = NULL, colour = "#FFE14D", fill_alpha = 0.25,
                           title = NULL) {
  p <- if (inherits(fields, "SpatRaster")) fb_polygons(fields) else fields
  ttl <- if (is.null(title)) "Delineated fields" else title
  g <- if (!is.null(stack)) fb_plot_rgb(stack, date, title = ttl) else ggplot2::ggplot() + fb_theme() + ggplot2::labs(title = ttl)
  set.seed(1)
  fills <- grDevices::hcl(h = stats::runif(nrow(p), 0, 360), c = 70, l = 65)
  g <- g + ggplot2::geom_sf(data = p, fill = fills, alpha = fill_alpha, colour = colour, linewidth = 0.35, inherit.aes = FALSE)
  if (!is.null(reference)) {
    g <- g + ggplot2::geom_sf(data = sf::st_boundary(reference), colour = "white", linewidth = 0.3, linetype = "22",
                              inherit.aes = FALSE)
  }
  g <- g + if (is.null(stack)) ggplot2::coord_sf(datum = NA, expand = FALSE, default = TRUE) else map_coord(stack$data)
  g + ggplot2::labs(subtitle = sprintf("%d fields", nrow(p)))
}

#' Feature ranking by border contrast
#'
#' @param contrast An `fb_contrast` object from [fb_rank_contrast()].
#' @param n Number of top features shown.
#' @param selected Optional names of selected features, highlighted.
#' @return A `ggplot` object.
#' @examples
#' s <- fb_example_stack("california")
#' f <- fb_example_files("california")
#' ref <- fb_reference(sf::st_read(f$fields, quiet = TRUE), s)
#' rk <- fb_rank_contrast(s, ref, n_pairs = 1000)
#' fb_plot_ranking(rk, n = 15, selected = fb_select_features(rk, k = 5))
#' @export
fb_plot_ranking <- function(contrast, n = 20, selected = NULL) {
  d <- utils::head(contrast$ranking, n)
  d$feature <- factor(d$feature, levels = rev(d$feature))
  d$selected <- if (is.null(selected)) "ranked" else ifelse(d$feature %in% selected, "selected", "not selected")
  ggplot2::ggplot(d, ggplot2::aes(auc, feature, colour = selected)) +
    ggplot2::geom_segment(ggplot2::aes(x = 0.5, xend = auc, yend = feature), linewidth = 0.4) +
    ggplot2::geom_point(size = 2) +
    ggplot2::scale_colour_manual(values = c(selected = fb_cols[["tbc"]], `not selected` = "grey60", ranked = fb_cols[["tbc"]]),
                                 name = NULL) +
    ggplot2::labs(x = "AUC of temporal contrast (across vs within fields)", title = "Border contrast of spectral features",
                  subtitle = sprintf("%s pixel pairs, %s across a field border", format(length(contrast$y), big.mark = ","),
                                     format(sum(contrast$y), big.mark = ","))) +
    fb_theme() + ggplot2::theme(axis.title.x = ggplot2::element_text(size = 9), legend.position = "bottom")
}

#' Accuracy of several methods
#'
#' @param acc Output of [fb_accuracy()] with a `method` column (one row per method).
#' @param type `"objects"` for object precision, recall and F1, or `"size"` for the recall
#'   of reference fields by size class (classes without reference fields are left out; the
#'   axis labels give the number of reference fields, from the first row of `acc`).
#' @param size_labels Labels of the size classes (for `type = "size"`).
#' @return A `ggplot` object.
#' @examples
#' s <- fb_example_stack("california")
#' f <- fb_example_files("california")
#' ref <- fb_reference(sf::st_read(f$fields, quiet = TRUE), s)
#' m <- fb_model_pretrained("california")
#' fu <- fb_model_pretrained("california", "fusion")
#' maps <- fb_tbc_maps(s, m)
#' dl <- fb_read_probabilities(f$prue)
#' fields <- list(TBC = fb_delineate(maps, thresholds = m$thresholds),
#'                `PRUE B3` = fb_delineate(dl, thresholds = fu$thresholds),
#'                `TBC + PRUE B3` = fb_delineate(fb_fuse(maps, dl, fu), thresholds = fu$thresholds))
#' ev <- do.call(rbind, lapply(names(fields), function(nm)
#'   cbind(method = nm, fb_evaluate(ref, fields[[nm]]))))
#' acc <- fb_accuracy(ev, by = "method")
#' fb_plot_accuracy(acc)
#' fb_plot_accuracy(acc, type = "size")
#' @export
fb_plot_accuracy <- function(acc, type = c("objects", "size"), size_labels = c("< 1", "1-5", "5-20", "20-50", "> 50")) {
  type <- match.arg(type)
  if (type == "objects") {
    d <- data.frame(method = rep(acc$method, 3), metric = rep(c("Precision", "Recall", "F1"), each = nrow(acc)),
                    value = c(acc$obj_precision, acc$obj_recall, acc$obj_f1))
    d$metric <- factor(d$metric, levels = c("Precision", "Recall", "F1"))
    ggplot2::ggplot(d, ggplot2::aes(value, method, fill = metric)) +
      ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.75), width = 0.7) +
      ggplot2::geom_text(ggplot2::aes(label = sprintf("%.2f", value)), position = ggplot2::position_dodge(width = 0.75),
                         hjust = -0.15, size = 3) +
      ggplot2::scale_fill_manual(values = c(Precision = "#9FB8D9", Recall = "#E3A96B", F1 = "#C8323F"), name = NULL) +
      ggplot2::scale_x_continuous(limits = c(0, 1.08), breaks = seq(0, 1, 0.25)) +
      ggplot2::labs(x = "Object accuracy (IoU > 0.5)", title = "Field objects") + fb_theme() +
      ggplot2::theme(axis.title.x = ggplot2::element_text(size = 9), legend.position = "bottom")
  } else {
    rc <- grep("^recall_s[0-9]+$", names(acc), value = TRUE)
    lab <- size_labels[seq_along(rc)]
    nc <- sub("recall_", "ref_", rc)
    if (all(nc %in% names(acc))) lab <- sprintf("%s\n(n = %d)", lab, as.integer(unlist(acc[1, nc])))
    d <- data.frame(method = rep(acc$method, length(rc)), size = rep(lab, each = nrow(acc)),
                    recall = unlist(acc[rc], use.names = FALSE))
    d$size <- factor(d$size, levels = lab)
    d <- d[is.finite(d$recall), ]
    d$size <- droplevels(d$size)
    # methods with equal recall are offset slightly so that none is hidden
    pos <- ggplot2::position_dodge(width = 0.25)
    okabe_ito <- c("#E69F00", "#56B4E9", "#009E73", "#CC79A7", "#0072B2", "#D55E00", "#F0E442", "#000000")
    nm <- unique(as.character(d$method))
    cols <- if (length(nm) <= length(okabe_ito)) stats::setNames(okabe_ito[seq_along(nm)], nm) else NULL
    ggplot2::ggplot(d, ggplot2::aes(size, recall, colour = method, group = method)) +
      ggplot2::geom_line(linewidth = 0.6, position = pos) + ggplot2::geom_point(size = 2, position = pos) +
      (if (is.null(cols)) ggplot2::scale_colour_discrete() else ggplot2::scale_colour_manual(values = cols)) +
      ggplot2::scale_y_continuous(limits = c(0, 1)) +
      ggplot2::labs(x = "Reference field area (ha)", y = "Object recall", colour = NULL, title = "Recall by field size") +
      fb_theme() + ggplot2::theme(axis.title = ggplot2::element_text(size = 9), legend.position = "bottom")
  }
}
