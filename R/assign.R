default_definitions_path <- function() {
  path <- system.file("schemas", "definitions.yml", package = "pipschema")
  if (!nzchar(path) || !file.exists(path)) {
    stop("Default definitions file not found in package: inst/schemas/definitions.yml", call. = FALSE)
  }
  path
}

normalize_schema_for_output <- function(schema, folders) {
  desc_raw <- schema$description
  has_desc <- !is.null(desc_raw) && is.character(desc_raw) && length(desc_raw) == 1L && nzchar(desc_raw)

  out <- list(
    id = schema$id,
    checks = schema$checks,
    folders = sort(unique(as.character(folders)), method = "radix")
  )

  if (!is.null(desc_raw) && !has_desc) {
    stop(sprintf(
      "Schema '%s' has an invalid 'description' (expected a single, non-empty string)",
      as.character(schema$id)
    ), call. = FALSE)
  }

  if (has_desc) {
    out$description <- desc_raw
    out <- out[c("id", "description", "checks", "folders")]
  }

  out
}

safe_child_dirs <- function(data_dir) {
  list.dirs(data_dir, full.names = TRUE, recursive = FALSE)
}

#' Assign folders to schemas and write registry YAML
#'
#' Classifies one-level child directories under `data_dir` against the supplied
#' schema definitions and writes a deterministic YAML output.
#'
#' @param data_dir Directory containing vintage-folder subdirectories.
#' @param output Output YAML file path.
#' @param definitions Parsed definitions list. If `NULL`, package defaults are
#'   loaded from `inst/schemas/definitions.yml`.
#'
#' @return Normalized output file path.
#' @export
assign_schemas <- function(data_dir, output, definitions = NULL) {
  if (!dir.exists(data_dir)) {
    stop(sprintf("Data directory does not exist: %s", data_dir), call. = FALSE)
  }

  defs <- definitions
  if (is.null(defs)) {
    defs <- read_definitions(default_definitions_path())
  }

  if (!is.list(defs$schemas) || length(defs$schemas) == 0L) {
    stop("Definitions must include at least one schema", call. = FALSE)
  }

  dirs <- safe_child_dirs(data_dir)
  if (length(dirs) == 0L) {
    stop(sprintf("No child directories found in data directory: %s", data_dir), call. = FALSE)
  }

  assign_map <- stats::setNames(vector("list", length(defs$schemas)), vapply(defs$schemas, `[[`, character(1), "id"))
  for (sid in names(assign_map)) assign_map[[sid]] <- character(0)

  for (d in sort(dirs, method = "radix")) {
    folder <- basename(d)
    classified <- tryCatch(
      classify_folder(d, defs),
      error = function(e) {
        stop(sprintf("Failed to classify folder '%s': %s", folder, conditionMessage(e)), call. = FALSE)
      }
    )

    sid <- as.character(classified$schema_id)
    assign_map[[sid]] <- c(assign_map[[sid]], folder)
  }

  schemas_sorted <- defs$schemas[order(vapply(defs$schemas, `[[`, character(1), "id"), method = "radix")]
  out_schemas <- lapply(schemas_sorted, function(schema) {
    sid <- as.character(schema$id)
    normalize_schema_for_output(schema, assign_map[[sid]])
  })

  payload <- list(
    version = defs$version,
    schemas = out_schemas
  )

  yaml_txt <- yaml::as.yaml(payload, indent.mapping.sequence = TRUE)
  writeLines(yaml_txt, con = output, useBytes = TRUE)

  normalizePath(output, winslash = "/", mustWork = TRUE)
}
