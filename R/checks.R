check_file_exists <- function(check, base_path) {
  target <- file.path(base_path, check$path)
  exists <- file.exists(target)
  expected <- isTRUE(check$present)

  if (identical(exists, expected)) {
    return(list(passed = TRUE, reason = NULL))
  }

  if (expected) {
    list(passed = FALSE, reason = sprintf("Expected file missing: %s", check$path))
  } else {
    list(passed = FALSE, reason = sprintf("File should be absent but exists: %s", check$path))
  }
}

check_dir_exists <- function(check, base_path) {
  target <- file.path(base_path, check$path)
  exists <- dir.exists(target)
  expected <- isTRUE(check$present)

  if (identical(exists, expected)) {
    return(list(passed = TRUE, reason = NULL))
  }

  if (expected) {
    list(passed = FALSE, reason = sprintf("Expected directory missing: %s", check$path))
  } else {
    list(passed = FALSE, reason = sprintf("Directory should be absent but exists: %s", check$path))
  }
}

check_dir_extension <- function(check, base_path) {
  target <- file.path(base_path, check$path)
  if (!dir.exists(target)) {
    return(list(passed = FALSE, reason = sprintf("Directory missing: %s", check$path)))
  }

  files <- list.files(target, full.names = TRUE, recursive = FALSE, all.files = FALSE)
  files <- files[file.info(files)$isdir %in% FALSE]

  if (length(files) == 0L) {
    return(list(passed = FALSE, reason = sprintf("Directory is empty: %s", check$path)))
  }

  exts <- tolower(tools::file_ext(files))
  expected_ext <- sub("^\\.", "", tolower(check$extension))
  all_ok <- all(nzchar(exts) & exts == expected_ext)

  if (!all_ok) {
    return(list(passed = FALSE, reason = sprintf("Directory '%s' has non-matching file extensions", check$path)))
  }

  list(passed = TRUE, reason = NULL)
}

check_fst_columns <- function(check, base_path) {
  target <- file.path(base_path, check$path)
  if (!file.exists(target)) {
    return(list(passed = FALSE, reason = sprintf("Expected file missing: %s", check$path)))
  }

  if (!requireNamespace("fst", quietly = TRUE)) {
    stop("Package 'fst' is required for 'fst_columns' checks", call. = FALSE)
  }

  meta <- tryCatch(
    fst::metadata_fst(target),
    error = function(e) {
      stop(sprintf("Cannot read fst header '%s': %s", check$path, conditionMessage(e)), call. = FALSE)
    }
  )

  cols <- names(meta$columnNames)
  expected <- as.character(check$columns)
  missing <- setdiff(expected, cols)

  if (length(missing) > 0L) {
    return(list(passed = FALSE, reason = sprintf("Missing fst columns in '%s': %s", check$path, paste(missing, collapse = ", "))))
  }

  list(passed = TRUE, reason = NULL)
}

run_check <- function(check, base_path) {
  type <- as.character(check$type)

  switch(
    type,
    file_exists = check_file_exists(check, base_path),
    dir_exists = check_dir_exists(check, base_path),
    dir_extension = check_dir_extension(check, base_path),
    fst_columns = check_fst_columns(check, base_path),
    stop(sprintf("Unknown check type: %s", type), call. = FALSE)
  )
}
