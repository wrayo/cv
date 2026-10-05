# This file contains all the code needed to parse and print various sections of your CV
# from data. Feel free to tweak it as you desire!
#
# Based on the printing functions from https://github.com/nstrayer/cv (2025 version),
# with these changes:
#   - text_blocks is optional: the CV builds fine if that sheet/csv is empty or missing
#   - academic terms ("Fall 2025") sort correctly
#   - print_list() for undated bullet-list sections (Interests, Skills, Affiliations)
#   - contact icons can use Font Awesome brand icons (e.g. "fa-brands fa-orcid")


#' Create a CV_Printer object.
#'
#' @param data_location Path of the spreadsheets holding all your data. This can be
#'   either a URL to a google sheet with multiple sheets containing the
#'   data types, a named list of separate Google Sheet URLs (`entries`,
#'   `contact_info`, optional `text_blocks`), or a path to a folder containing
#'   `.csv`s with the neccesary data.
#' @param pdf_mode Is the output being rendered into a pdf? Aka do links need
#'   to be stripped?
#' @param resume_mode Only keep entries with `in_resume` set to TRUE.
#' @param sheet_is_publicly_readable If you're using google sheets for data,
#'   is the sheet publicly available? (Makes authorization easier.)
#' @return A new `CV_Printer` object.
create_CV_object <- function(data_location,
                             pdf_mode = FALSE,
                             resume_mode = FALSE,
                             sheet_is_publicly_readable = TRUE) {
  cv <- list(
    pdf_mode = pdf_mode,
    links = c()
  )

  is_separate_sheets <- is.list(data_location)
  is_google_sheets_location <- is_separate_sheets ||
    stringr::str_detect(data_location, "docs\\.google\\.com")

  if (is_google_sheets_location) {
    if (sheet_is_publicly_readable) {
      # This tells google sheets to not try and authenticate. Note that this will only
      # work if your sheet has sharing set to "anyone with link can view"
      googlesheets4::gs4_deauth()
    } else {
      # designate project-specific cache so we can render Rmd without problems
      options(gargle_oauth_cache = ".secrets")
    }
  }

  if (is_separate_sheets) {
    # One Google Sheet per data type, e.g. list(entries = "https://...", contact_info = "https://...")
    read_data <- function(sheet_id) {
      googlesheets4::read_sheet(data_location[[sheet_id]], skip = 1, col_types = "c")
    }
    has_data <- function(sheet_id) {
      !is.null(data_location[[sheet_id]])
    }
  } else if (is_google_sheets_location) {
    read_data <- function(sheet_id) {
      googlesheets4::read_sheet(data_location, sheet = sheet_id, skip = 1, col_types = "c")
    }
    has_data <- function(sheet_id) {
      sheet_id %in% googlesheets4::sheet_names(data_location)
    }
  } else {
    # Want to go old-school with csvs?
    read_data <- function(sheet_id) {
      readr::read_csv(
        file.path(data_location, paste0(sheet_id, ".csv")),
        skip = 1,
        col_types = readr::cols(.default = "c")
      )
    }
    has_data <- function(sheet_id) {
      file.exists(file.path(data_location, paste0(sheet_id, ".csv")))
    }
  }

  cv$entries_data <- read_data("entries")
  cv$contact_info <- read_data("contact_info")

  # Text blocks are optional
  cv$text_blocks <- if (has_data("text_blocks")) read_data("text_blocks") else NULL
  if (is.null(cv$text_blocks) || nrow(cv$text_blocks) == 0) {
    cv$text_blocks <- data.frame(loc = character(), text = character())
  }


  extract_year <- function(dates) {
    date_year <- stringr::str_extract(dates, "(20|19)[0-9]{2}")
    date_year[is.na(date_year)] <- lubridate::year(lubridate::ymd(Sys.Date())) + 10

    date_year
  }

  parse_dates <- function(dates) {
    date_month <- stringr::str_extract(dates, "(\\w+|\\d+)(?=(\\s|\\/|-)(20|19)[0-9]{2})")

    # Academic terms sort by the month the term starts
    term_months <- c(winter = "1", spring = "4", summer = "7", fall = "9", autumn = "9")
    is_term <- tolower(date_month) %in% names(term_months)
    date_month[is_term] <- term_months[tolower(date_month[is_term])]

    date_month[is.na(date_month)] <- "1"

    paste("1", date_month, extract_year(dates), sep = "-") |>
      lubridate::dmy(quiet = TRUE)
  }


  cv$entries_data <- cv$entries_data |>
    dplyr::filter(
      !resume_mode | in_resume == "TRUE"
    )

  # Check if the column "description_md" exists in the entries_data dataframe
  if ("description_md" %in% colnames(cv$entries_data)) {
    cv$entries_data <- cv$entries_data |>
      dplyr::rename(description_bullets = description_md) |>
      dplyr::mutate(description_bullets = ifelse(is.na(description_bullets), "", description_bullets))
  } else {
    # Assume we're using old bullet_1, bullet_2, etc. columns
    cv$entries_data <- cv$entries_data |>
      tidyr::unite(
        tidyr::starts_with("description"),
        col = "description_bullets",
        sep = "\n- ",
        na.rm = TRUE
      ) |>
      dplyr::mutate(
        description_bullets = ifelse(description_bullets != "", paste0("- ", description_bullets), "")
      )
  }

  # Clean up entries dataframe to format we need it for printing
  cv$entries_data <- cv$entries_data |>
    dplyr::mutate(
      start = ifelse(start == "NULL", NA, start),
      end = ifelse(end == "NULL", NA, end),
      start_year = extract_year(start),
      end_year = extract_year(end),
      no_start = is.na(start),
      has_start = !no_start,
      no_end = is.na(end),
      has_end = !no_end,
      start_end_are_same = start == end,
      timeline = dplyr::case_when(
        no_start & no_end ~ "N/A",
        no_start & has_end ~ as.character(end),
        start_end_are_same ~ as.character(end),
        has_start & no_end ~ paste("Current", "-", start),
        TRUE ~ paste(end, "-", start)
      )
    ) |>
    dplyr::arrange(desc(parse_dates(end))) |>
    dplyr::mutate_all(~ ifelse(is.na(.), "N/A", .))

  cv
}


# Remove links from a text block and add to internal list
sanitize_links <- function(cv, text) {
  if (cv$pdf_mode) {
    # Only match real markdown links, so text like "[Talk]" is left alone
    link_matches <- stringr::str_match_all(text, "\\[([^\\]]+)\\]\\(([^)]+)\\)")[[1]]
    n_new_links <- nrow(link_matches)

    for (i in seq_len(n_new_links)) {
      cv$links <- c(cv$links, link_matches[i, 3])
      text <- stringr::str_replace(
        text,
        stringr::fixed(link_matches[i, 1]),
        paste0(link_matches[i, 2], "<sup>", length(cv$links), "</sup>")
      )
    }
  }

  list(cv = cv, text = text)
}


#' @description Take a position data frame and the section id desired and prints the section to markdown.
#' @param section_id ID of the entries section to be printed as encoded by the `section` column of the `entries` table
print_section <- function(cv, section_id, glue_template = "default") {
  if (glue_template == "default") {
    glue_template <- "
### {title}

{loc}

{institution}

{timeline}

{description_bullets}
\n\n\n"
  }

  section_data <- dplyr::filter(cv$entries_data, section == section_id)

  if (nrow(section_data) == 0) {
    stop(glue::glue("Tried to print section {section_id} with no entries. Make sure everything is spelled correctly or remove this section."))
  }

  # Take entire entries data frame and removes the links in descending order
  # so links for the same position are right next to each other in number.
  for (i in 1:nrow(section_data)) {
    for (col in c("title", "loc", "description_bullets")) {
      strip_res <- sanitize_links(cv, section_data[i, col])
      section_data[i, col] <- strip_res$text
      cv <- strip_res$cv
    }
  }

  print(glue::glue_data(section_data, glue_template))

  invisible(cv)
}


#' @description Prints a section as a plain bullet list, with no dates or timeline.
#'   Each item is the `title`; when `loc` is filled in it is shown after a bold
#'   `title` label (e.g. title = "Programming Languages", loc = "R, Python").
#' @param section_id ID of the entries section to be printed as encoded by the `section` column of the `entries` table
print_list <- function(cv, section_id) {
  section_data <- dplyr::filter(cv$entries_data, section == section_id)

  if (nrow(section_data) == 0) {
    stop(glue::glue("Tried to print section {section_id} with no entries. Make sure everything is spelled correctly or remove this section."))
  }

  items <- ifelse(
    section_data$loc == "N/A",
    section_data$title,
    paste0("**", section_data$title, ":** ", section_data$loc)
  )

  for (i in seq_along(items)) {
    strip_res <- sanitize_links(cv, items[i])
    items[i] <- strip_res$text
    cv <- strip_res$cv
  }

  cat(paste0("- ", items, collapse = "\n"), "\n\n")

  invisible(cv)
}



#' @description Prints out text block identified by a given label. Prints
#'   nothing if there is no text block with that label, so a block can be added
#'   to the data later without touching the .Rmd.
#' @param label ID of the text block to print as encoded in `loc` column of `text_blocks` table.
print_text_block <- function(cv, label) {
  text_block <- dplyr::filter(cv$text_blocks, loc == label) |>
    dplyr::pull(text)

  if (length(text_block) == 0 || all(is.na(text_block))) {
    return(invisible(cv))
  }

  strip_res <- sanitize_links(cv, paste(text_block, collapse = "\n\n"))

  cat(strip_res$text, "\n\n")

  invisible(strip_res$cv)
}



#' @description List of all links in document labeled by their superscript integer.
print_links <- function(cv) {
  n_links <- length(cv$links)
  if (n_links > 0) {
    cat("
Links {data-icon=link}
--------------------------------------------------------------------------------

<br>


")

    purrr::walk2(cv$links, 1:n_links, function(link, index) {
      print(glue::glue("{index}. {link}"))
    })
  }

  invisible(cv)
}



#' @description Contact information section with icons. An icon is a Font
#'   Awesome name ("envelope") or full classes for brand icons ("fa-brands fa-orcid").
print_contact_info <- function(cv) {
  cv$contact_info |>
    dplyr::mutate(icon = ifelse(grepl("fa-", icon), icon, paste0("fa fa-", icon))) |>
    glue::glue_data("- <i class='{icon}'></i> {contact}") |>
    print()

  invisible(cv)
}
