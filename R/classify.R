#' Classify one vintage folder against schema definitions
#'
#' @param path Folder path to classify.
#' @param definitions Parsed definitions object from `read_definitions()`.
#'
#' @return A list with `schema_id` and `failures`.
#' @export
classify_folder <- function(path, definitions) {
  if (!dir.exists(path)) {
    stop(sprintf("Folder does not exist: %s", path), call. = FALSE)
  }

  schemas <- definitions$schemas
  if (!is.list(schemas) || length(schemas) == 0L) {
    stop("Definitions must include at least one schema", call. = FALSE)
  }

  matches <- character(0)
  failures <- list()

  for (schema in schemas) {
    sid <- as.character(schema$id)
    schema_failed <- FALSE
    reasons <- character(0)

    for (check in schema$checks) {
      res <- run_check(check, path)
      if (!isTRUE(res$passed)) {
        schema_failed <- TRUE
        reasons <- c(reasons, res$reason)
      }
    }

    if (schema_failed) {
      failures[[sid]] <- reasons
    } else {
      matches <- c(matches, sid)
    }
  }

  if (length(matches) == 1L) {
    return(list(schema_id = matches[[1]], failures = failures))
  }

  if (length(matches) == 0L) {
    msg <- "No schema matched"
    detail <- paste(vapply(names(failures), function(sid) {
      rs <- paste(failures[[sid]], collapse = "; ")
      sprintf("%s: %s", sid, rs)
    }, character(1)), collapse = " | ")
    stop(sprintf("%s for '%s'. %s", msg, basename(path), detail), call. = FALSE)
  }

  stop(sprintf(
    "Folder '%s' matched multiple schemas: %s",
    basename(path),
    paste(matches, collapse = ", ")
  ), call. = FALSE)
}
