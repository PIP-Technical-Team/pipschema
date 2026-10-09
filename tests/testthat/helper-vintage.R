normalize_local_path <- function(path) {
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

is_path_within <- function(path, root) {
  p <- normalize_local_path(path)
  r <- normalize_local_path(root)
  startsWith(paste0(p, "/"), paste0(r, "/")) || identical(p, r)
}

make_vintage <- function(root, name, files) {
  if (!dir.exists(root)) {
    stop("Root directory does not exist: ", root, call. = FALSE)
  }

  temp_root <- tempdir(check = TRUE)
  if (!is_path_within(root, temp_root)) {
    stop("Root must be inside tempdir(): ", temp_root, call. = FALSE)
  }

  vintage_path <- file.path(root, name)
  dir.create(vintage_path, recursive = TRUE, showWarnings = FALSE)

  file_list <- unique(as.character(files))
  file_list <- file_list[nzchar(file_list)]

  if (length(file_list) == 0L) {
    return(vintage_path)
  }

  for (rel in file_list) {
    full_path <- file.path(vintage_path, rel)
    parent <- dirname(full_path)
    dir.create(parent, recursive = TRUE, showWarnings = FALSE)
    if (!file.exists(full_path)) {
      file.create(full_path)
    }
  }

  vintage_path
}
