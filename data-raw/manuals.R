# Reference manual and tutorial of the package (manual/): the help pages through R CMD Rd2pdf, and the five
# articles (vignettes) knitted into one PDF with pandoc and XeLaTeX. Needs the installed package, LaTeX and
# the packages used by the articles. Run from the package source folder:  Rscript data-raw/manuals.R
dir.create("manual", showWarnings = FALSE)

# reference manual (Times fonts; the default inconsolata font is not needed)
Sys.setenv(R_RD4PDF = "times,hyper")
st <- system2("R", c("CMD", "Rd2pdf", "--no-preview", "--force", "--output=manual/fieldborders-manual.pdf", "."))
if (st != 0) stop("Rd2pdf failed")

# tutorial: each article becomes a top-level section; its setup chunk keeps its own chunk options, which are
# reset to the defaults before every article and set for PDF output after it
articles <- c("fieldborders", "training", "new-area", "gallery", "validation")
work <- Sys.getenv("FB_TUTORIAL_DIR", tempfile("tutorial"))   # set FB_TUTORIAL_DIR to keep the LaTeX files
dir.create(work, showWarnings = FALSE, recursive = TRUE)
file.copy(file.path("vignettes", "figures"), work, recursive = TRUE)
header <- c(
  "---",
  'title: "fieldborders: agricultural field boundaries from Sentinel-2 time series"',
  sprintf('subtitle: "Tutorial, version %s"', as.character(utils::packageVersion("fieldborders"))),
  'author: "Ehsan Rahimi and Chuleui Jung"',
  "output:",
  "  pdf_document:",
  "    toc: true",
  "    toc_depth: 2",
  "    latex_engine: xelatex",
  "    highlight: tango",
  "geometry: margin=2.2cm",
  "fontsize: 10pt",
  "fontfamily: fontspec",
  "mainfont: Caladea",
  "monofont: DejaVu Sans Mono",
  "mathfont: DejaVu Math TeX Gyre",
  "linkcolor: black",
  "urlcolor: blue",
  "header-includes:",
  "  - \\usepackage{fvextra}",
  "  - \\DefineVerbatimEnvironment{Highlighting}{Verbatim}{breaklines,commandchars=\\\\\\{\\}}",
  "  - \\RecustomVerbatimEnvironment{verbatim}{Verbatim}{breaklines}",
  "---",
  "")
body <- unlist(lapply(articles, function(a) {
  x <- readLines(file.path("vignettes", paste0(a, ".Rmd")), encoding = "UTF-8")
  yaml_end <- which(x == "---")[2]
  title <- sub('^title: "(.*)"$', "\\1", grep("^title:", x[seq_len(yaml_end)], value = TRUE))
  x <- x[-seq_len(yaml_end)]
  i <- grep("^```\\{r setup, include = FALSE\\}", x)
  stopifnot(length(i) == 1)
  x[i] <- sprintf("```{r setup-%s, include = FALSE}", a)
  close <- i + which(x[(i + 1):length(x)] == "```")[1]
  c("\\newpage", "", paste("#", title), "",
    sprintf("```{r reset-%s, include = FALSE, eval = TRUE}", a), "knitr::opts_chunk$restore()", "```", "",
    x[seq_len(close)],
    "", sprintf("```{r pdf-%s, include = FALSE, eval = TRUE}", a),
    "knitr::opts_chunk$set(dev = 'png', dpi = 200, out.width = '100%')", "```", "",
    x[-seq_len(close)], "")
}))
rmd <- file.path(work, "fieldborders-tutorial.Rmd")
writeLines(c(header, body), rmd, useBytes = TRUE)
out <- rmarkdown::render(rmd, output_dir = work, quiet = TRUE, envir = new.env())
file.copy(out, file.path("manual", "fieldborders-tutorial.pdf"), overwrite = TRUE)
message("written: manual/fieldborders-manual.pdf, manual/fieldborders-tutorial.pdf")
