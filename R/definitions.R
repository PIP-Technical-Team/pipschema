field_shape_validators <- list(
  path = function(x) is.character(x) && length(x) == 1L && nzchar(x),
  extension = function(x) is.character(x) && length(x) == 1L && nzchar(x),
  present = function(x) is.logical(x) && length(x) == 1L && !is.na(x),
  columns = function(x) is.character(x) && length(x) >= 1L && all(nzchar(x))
)

validate_field_shapes <- function(check, required, file_path, schema_id, check_index, check_type) {
  for (field in required) {
    validator <- field_shape_validators[[field]]
    if (is.null(validator)) next

    if (!isTRUE(validator(check[[field]]))) {
      stop(sprintf(
        "%s: schema '%s' check %d type '%s' field '%s' has an invalid shape (expected a single, non-empty value of the right type)",
        file_path,
        schema_id,
        check_index,
        check_type,
        field
      ), call. = FALSE)
    }
  }
}

validate_check <- function(check, file_path, schema_id, check_index) {
  if (is.null(check$type) || !nzchar(as.character(check$type))) {
    stop(sprintf("%s: schema '%s' check %d missing field 'type'", file_path, schema_id, check_index), call. = FALSE)
  }

  check_type <- as.character(check$type)
  required <- required_fields_for_check_type(check_type)
  if (is.null(required)) {
    stop(sprintf("%s: schema '%s' check %d has unknown type '%s'", file_path, schema_id, check_index, check_type), call. = FALSE)
  }

  missing_fields <- required[vapply(required, function(f) is.null(check[[f]]), logical(1))]
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

  validate_field_shapes(check, required, file_path, schema_id, check_index, check_type)

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

#' Read schema definitions from YAML
#'
#' Loads and validates schema definitions from a YAML file. Validation includes
#' duplicate schema IDs, unknown check types, and missing required fields.
#'
#' @param path Path to a definitions YAML file.
#'
#' @return A list with `version` and validated `schemas`.
#' @export
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
    desc_raw <- sch$description
    if (is.null(desc_raw) || !is.character(desc_raw) || length(desc_raw) != 1L || !nzchar(desc_raw)) {
      stop(sprintf("%s: schema '%s' missing field 'description'", path, sid), call. = FALSE)
    }
    desc <- desc_raw
    normalized[[i]] <- list(
      id = sid,
      description = desc,
      checks = normalize_checks(sch$checks, path, sid)
    )
  }

  list(
    version = parsed$version,
    schemas = normalized
  )
}
