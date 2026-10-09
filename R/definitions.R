required_fields_for_type <- list(
  file_exists = c("path", "present"),
  dir_exists = c("path", "present"),
  dir_extension = c("path", "extension"),
  fst_columns = c("path", "columns")
)

validate_check <- function(check, file_path, schema_id, check_index) {
  if (is.null(check$type) || !nzchar(as.character(check$type))) {
    stop(sprintf("%s: schema '%s' check %d missing field 'type'", file_path, schema_id, check_index), call. = FALSE)
  }

  check_type <- as.character(check$type)
  if (!check_type %in% names(required_fields_for_type)) {
    stop(sprintf("%s: schema '%s' check %d has unknown type '%s'", file_path, schema_id, check_index, check_type), call. = FALSE)
  }

  required <- required_fields_for_type[[check_type]]
  missing_fields <- required[!vapply(required, function(f) !is.null(check[[f]]), logical(1))]
  if (length(missing_fields) > 0L) {
    stop(sprintf(
      "%s: schema '%s' check %d type '%s' missing field(s): %s",
      file_path,
      schema_id,
      check_index,
      check_type,
      paste(missing_fields, collapse = ", ")
    ), call. = FALSE)
  }

  check
}

normalize_checks <- function(checks, file_path, schema_id) {
  if (!is.list(checks) || length(checks) == 0L) {
    stop(sprintf("%s: schema '%s' has missing or empty 'checks'", file_path, schema_id), call. = FALSE)
  }

  out <- vector("list", length(checks))
  for (i in seq_along(checks)) {
    out[[i]] <- validate_check(checks[[i]], file_path, schema_id, i)
  }

  order_key <- vapply(out, function(ch) paste0(ch$type, "::", ch$path %||% ""), character(1))
  out[order(order_key)]
}

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

read_definitions <- function(path) {
  if (!file.exists(path)) {
    stop(sprintf("Cannot read definitions file: %s", path), call. = FALSE)
  }

  parsed <- tryCatch(
    yaml::read_yaml(path),
    error = function(e) {
      stop(sprintf("Failed to read yaml '%s': %s", path, conditionMessage(e)), call. = FALSE)
    }
  )

  if (is.null(parsed$version)) {
    stop(sprintf("%s: missing field 'version'", path), call. = FALSE)
  }

  if (is.null(parsed$schemas) || !is.list(parsed$schemas) || length(parsed$schemas) == 0L) {
    stop(sprintf("%s: missing or empty 'schemas'", path), call. = FALSE)
  }

  schemas <- parsed$schemas
  ids <- vapply(schemas, function(s) as.character(s$id %||% ""), character(1))
  if (any(!nzchar(ids))) {
    stop(sprintf("%s: schema with missing field 'id'", path), call. = FALSE)
  }

  dup <- unique(ids[duplicated(ids)])
  if (length(dup) > 0L) {
    stop(sprintf("%s: duplicate schema id(s): %s", path, paste(dup, collapse = ", ")), call. = FALSE)
  }

  ord <- order(ids)
  schemas <- schemas[ord]

  normalized <- vector("list", length(schemas))
  for (i in seq_along(schemas)) {
    sch <- schemas[[i]]
    sid <- as.character(sch$id)
    normalized[[i]] <- list(
      id = sid,
      checks = normalize_checks(sch$checks, path, sid)
    )
  }

  list(
    version = parsed$version,
    schemas = normalized
  )
}
