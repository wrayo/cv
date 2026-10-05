# William Rayo CV

A data-driven CV built with R Markdown and [pagedown](https://pagedown.rbind.io).
The layout and sections follow [pilegard/cv](https://github.com/pilegard/cv); the printing
functions come from [nstrayer/cv](https://github.com/nstrayer/cv).

## Files

| File | What it does |
|---|---|
| Google Sheet (link below) | Every CV entry, contact lines, optional paragraphs |
| `index.Rmd` | Section order, headings and icons |
| `cv_printing_functions.R` | Turns rows into CV entries |
| `dd_cv.css` | Fonts, spacing, colors |
| `render_cv.R` | Builds `index.html` and `Rayo_CV.pdf` |

Live site: https://wrayo.github.io/cv/ · PDF: https://wrayo.github.io/cv/Rayo_CV.pdf

## Build

**On GitHub (no R needed):** after editing the Google Sheet, open the repo's
[Actions tab](https://github.com/wrayo/cv/actions/workflows/rebuild-cv.yml), click
**Run workflow**. It rebuilds the HTML and PDF from the Sheet and publishes them (about 5 min).

**On your laptop:**

```bash
Rscript render_cv.R
```

then commit and push `index.html` and `Rayo_CV.pdf`.

Or open `render_cv.R` in RStudio/Positron and click **Source**. (The **Knit** button on
`index.Rmd` only makes the HTML preview, not the PDF.)

## Add something

Add a row to the entries Google Sheet. The build sorts by date, so row order
only matters for entries with the same date.

| Column | Use |
|---|---|
| `section` | Which section it goes in (ids below) |
| `title` | Bold first line. Links: `[title](https://doi.org/...)` |
| `loc` | Line under the title: institution, role, or citation. Bold your name with `**Rayo, W.**`; mark student authors with `\*` |
| `institution` | Optional; shown with a map-pin icon |
| `start`, `end` | `2025`, `Sep 2025`, or `Fall 2025`. Blank `end` = "Current". Same `start` and `end` shows once |
| `description_md` | Bullets, each line starting `- `. Indent 4 spaces for sub-bullets |
| `in_resume` | `TRUE` to include in a future short resume |

New term of a course you already list: add a bullet line (e.g. `- Winter 2027: 480 students`)
to that course's `description_md` and update its `end` year. Teaching `start`/`end` use years
only; the quarter lives in the bullets.

### Section ids

| id | Section |
|---|---|
| `appointments` | Positions and Appointments |
| `education` | Education |
| `interests` | Interests *(plain list: `title` only)* |
| `awards` | Awards and Honors (includes grants) |
| `teaching_ior` | Teaching Experience: Instructor of Record |
| `teaching_grad` | Graduate Teaching Experience (instructor of record and TA) |
| `teaching_secondary` | Secondary Teaching |
| `mentorship` | Mentorship |
| `pubs` | Publications |
| `presentations` | Presentations |
| `posters` | Poster Presentations |
| `talks` | Invited Talks, Guest Lectures, and Workshops |
| `prof_service` | Professional Service |
| `uni_service` | University and School Service |
| `training` | Certifications and Specialized Training |
| `skills` | Technical Skills *(plain list: `title` = label, `loc` = items)* |
| `affiliations` | Organization Affiliations *(plain list)* |

A new kind of section needs a new id in the data plus a 6-line block in `index.Rmd`
(copy an existing one).

## Text blocks (optional)

Add a row to `text_blocks` with `loc` set to one of these, and the paragraph appears
on the next build. No code changes needed.

- `intro`: under your name
- `interests`: at the top of Interests

## Where the data lives

The build reads one Google Sheet (set under `data_location` at the top of `index.Rmd`):
https://docs.google.com/spreadsheets/d/1V3lM1eQ4JJibDTZ-xjmFPBTUH9wrQSD21DGzjgBvigI

Its tabs must be named `entries`, `contact_info`, and `text_blocks`.

Edit the Sheet, then run the build. It must stay shared as
**Anyone with the link → Viewer**, and keep the first row (column help text) and
second row (column names) as they are.

The csvs in `data/` (local only, not on GitHub) are an old offline backup and are **not** read by the build. To build from
them instead, set `data_location` to `value: "data"`. `data_location` can also be the URL of
a named list of separate Sheet URLs (`entries`, `contact_info`, `text_blocks`).
