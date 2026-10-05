# This script builds both the HTML and PDF versions of your CV.
# Run it from this folder with:  Rscript render_cv.R

# Outside RStudio, use the copy of pandoc that ships with RStudio
if (!rmarkdown::pandoc_available()) {
  Sys.setenv(RSTUDIO_PANDOC = "/Applications/RStudio.app/Contents/Resources/app/quarto/bin/tools/aarch64")
}

# Knit the HTML version (this is also the page GitHub Pages serves)
rmarkdown::render("index.Rmd",
                  params = list(pdf_mode = FALSE),
                  output_file = "index.html")

# Print the HTML to PDF with Chrome. Links stay clickable in the PDF.
# (To turn links into numbered footnotes instead, render a second copy with
# params = list(pdf_mode = TRUE) to a temporary file and print that.)
pagedown::chrome_print(input = "index.html",
                       output = "Rayo_CV.pdf",
                       # GitHub Actions runs Chrome as root, which needs --no-sandbox
                       extra_args = if (Sys.getenv("CI") == "true") "--no-sandbox" else character())
