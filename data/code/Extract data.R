
# --- (Lastest) Version 1  ---
# Time: 2025/11/02; 15:23 
# Author: Tung-Yen Wu

# --- Description  ---
# This script automatically scrapes and downloads New York City FHVs high-volume trip records for the years 2024–2025.
# The total file size is approximately 10 GB, so please ensure that you have sufficient storage space before running it.
# Make sure to change local direction (variable: dest_dir) before excuting.
# ------------------------------------------------------------
# 0. Install and load required packages
# ------------------------------------------------------------
if (!requireNamespace("rvest", quietly = TRUE)) install.packages("rvest")
if (!requireNamespace("xml2",  quietly = TRUE)) install.packages("xml2")
if (!requireNamespace("stringr", quietly = TRUE)) install.packages("stringr")
if (!requireNamespace("dplyr", quietly = TRUE)) install.packages("dplyr")

library(rvest)
library(xml2)
library(stringr)
library(dplyr)

# ------------------------------------------------------------
# 1. Target URL & local save directory
# ------------------------------------------------------------
tlc_url  <- "https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page"

dest_dir <- "C:/Users/hp/Desktop/ECON5166-final_project/data"
if (!dir.exists(dest_dir)) dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)

# ------------------------------------------------------------
# 2. Read TLC page and extract all links
# ------------------------------------------------------------
page <- read_html(tlc_url)

all_links <- page |>
  html_elements("a") |>
  html_attr("href") |>
  unique()

# Remove NA
all_links <- all_links[!is.na(all_links)]

# Add "https://www.nyc.gov" for relative paths
all_links <- ifelse(
  str_starts(all_links, "http"),
  all_links,
  paste0("https://www.nyc.gov", all_links)
)

# ------------------------------------------------------------
# 3. Filter fhvhv parquet files for 2024/2025
# ------------------------------------------------------------
trip_links <- all_links[
  str_detect(all_links, "trip-data") &
    str_detect(all_links, "\\.parquet$")
]

file_names <- basename(trip_links)

keep_idx <- str_detect(file_names, "^fhvhv") &
  (str_detect(file_names, "_2024-") |
     str_detect(file_names, "_2025-"))

trip_links <- sort(trip_links[keep_idx])

length(trip_links)
trip_links[1:10]

# ------------------------------------------------------------
# 4. Download selected files
# ------------------------------------------------------------
for (url in trip_links) {
  file_name <- basename(url)
  dest_file <- file.path(dest_dir, file_name)
  
  if (file.exists(dest_file)) {
    message("[skip] ", dest_file, " already exists.")
    next
  }
  
  message("[download] ", url, " -> ", dest_file)
  try(
    download.file(
      url      = url,
      destfile = dest_file,
      mode     = "wb",
      quiet    = TRUE
    ),
    silent = FALSE
  )
}

message("Done. Files saved in: ", dest_dir)

# ------------------------------------------------------------
# 5. Fallback: manually fetch 2024-01/02/03 parquet files
#    (Sometimes the scraper fails to capture these months)
# ------------------------------------------------------------

fallback_months <- c("01", "02", "03")

for (m in fallback_months) {
  fname <- paste0("fhvhv_tripdata_2024-", m, ".parquet")
  dest_file <- file.path(dest_dir, fname)
  
  if (!file.exists(dest_file)) {
    url_fallback <- paste0(
      "https://d37ci6vzurychx.cloudfront.net/trip-data/",
      fname
    )
    
    message("[fallback download] ", url_fallback, " -> ", dest_file)
    
    res <- try(
      download.file(
        url      = url_fallback,
        destfile = dest_file,
        mode     = "wb",
        quiet    = FALSE
      ),
      silent = TRUE
    )
    
    if (inherits(res, "try-error")) {
      message("[ERROR] fallback download failed for: ", url_fallback)
    }
  } else {
    message("[ok] File already present: ", fname)
  }
}