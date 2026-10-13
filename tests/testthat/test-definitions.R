sample_definitions <- list(
  version = 1,
  schemas = list(
    list(
      id = "pre-lineup",
      description = "Has none of the four lineup markers.",
      checks = list(
        list(type = "dir_exists", path = "lineup_data", present = FALSE)
      )
    ),
    list(
      id = "new-lineup",
      description = "Has lineup_data and lineup estimation markers.",
      checks = list(
        list(type = "dir_exists", path = "lineup_data", present = TRUE)
      )
    )
  )
)

write_yaml_file <- function(obj, path) {
  yaml::write_yaml(obj, path)
}

testthat::test_that("read_definitions loads valid definitions", {
  tf <- tempfile(fileext = ".yml")
  write_yaml_file(sample_definitions, tf)

  out <- read_definitions(tf)

  testthat::expect_equal(out$version, 1)
  testthat::expect_equal(vapply(out$schemas, `[[`, character(1), "id"), c("new-lineup", "pre-lineup"))
})

testthat::test_that("read_definitions is stable to schema order", {
  tf1 <- tempfile(fileext = ".yml")
  tf2 <- tempfile(fileext = ".yml")

  write_yaml_file(sample_definitions, tf1)
  rev_obj <- sample_definitions
  rev_obj$schemas <- rev(rev_obj$schemas)
  write_yaml_file(rev_obj, tf2)

  d1 <- read_definitions(tf1)
  d2 <- read_definitions(tf2)

  testthat::expect_equal(d1, d2)
})

testthat::test_that("read_definitions rejects duplicate schema ids", {
  tf <- tempfile(fileext = ".yml")
  dup_obj <- sample_definitions
  dup_obj$schemas[[2]]$id <- "pre-lineup"
  write_yaml_file(dup_obj, tf)

  err <- testthat::expect_error(read_definitions(tf))
  msg <- conditionMessage(err)
  testthat::expect_true(grepl(tf, msg, fixed = TRUE))
  testthat::expect_true(grepl("duplicate schema id(s)", msg, fixed = TRUE))
  testthat::expect_true(grepl("pre-lineup", msg, fixed = TRUE))
})

testthat::test_that("read_definitions rejects unknown check type", {
  tf <- tempfile(fileext = ".yml")
  bad_obj <- sample_definitions
  bad_obj$schemas[[1]]$checks[[1]]$type <- "unknown_type"
  write_yaml_file(bad_obj, tf)

  err <- testthat::expect_error(read_definitions(tf))
  msg <- conditionMessage(err)
  testthat::expect_true(grepl(tf, msg, fixed = TRUE))
  testthat::expect_true(grepl("schema 'pre-lineup'", msg, fixed = TRUE))
  testthat::expect_true(grepl("check 1", msg, fixed = TRUE))
  testthat::expect_true(grepl("unknown type 'unknown_type'", msg, fixed = TRUE))
})

testthat::test_that("read_definitions rejects missing required check field", {
  tf <- tempfile(fileext = ".yml")
  bad_obj <- sample_definitions
  bad_obj$schemas[[1]]$checks[[1]]$path <- NULL
  write_yaml_file(bad_obj, tf)

  err <- testthat::expect_error(read_definitions(tf))
  msg <- conditionMessage(err)
  testthat::expect_true(grepl(tf, msg, fixed = TRUE))
  testthat::expect_true(grepl("schema 'pre-lineup'", msg, fixed = TRUE))
  testthat::expect_true(grepl("type 'dir_exists'", msg, fixed = TRUE))
  testthat::expect_true(grepl("missing field(s): path", msg, fixed = TRUE))
})

testthat::test_that("read_definitions rejects missing schema description", {
  tf <- tempfile(fileext = ".yml")
  bad_obj <- sample_definitions
  bad_obj$schemas[[1]]$description <- NULL
  write_yaml_file(bad_obj, tf)

  err <- testthat::expect_error(read_definitions(tf))
  msg <- conditionMessage(err)
  testthat::expect_true(grepl(tf, msg, fixed = TRUE))
  testthat::expect_true(grepl("schema 'pre-lineup'", msg, fixed = TRUE))
  testthat::expect_true(grepl("missing field 'description'", msg, fixed = TRUE))
})

testthat::test_that("read_definitions rejects non-scalar schema description", {
  tf <- tempfile(fileext = ".yml")
  bad_obj <- sample_definitions
  bad_obj$schemas[[1]]$description <- c("one", "two")
  write_yaml_file(bad_obj, tf)

  err <- testthat::expect_error(read_definitions(tf))
  msg <- conditionMessage(err)
  testthat::expect_true(grepl(tf, msg, fixed = TRUE))
  testthat::expect_true(grepl("schema 'pre-lineup'", msg, fixed = TRUE))
  testthat::expect_true(grepl("missing field 'description'", msg, fixed = TRUE))
})

testthat::test_that("read_definitions rejects a non-scalar check path", {
  tf <- tempfile(fileext = ".yml")
  bad_obj <- sample_definitions
  bad_obj$schemas[[1]]$checks[[1]]$path <- c("a", "b")
  write_yaml_file(bad_obj, tf)

  err <- testthat::expect_error(read_definitions(tf))
  msg <- conditionMessage(err)
  testthat::expect_true(grepl(tf, msg, fixed = TRUE))
  testthat::expect_true(grepl("schema 'pre-lineup'", msg, fixed = TRUE))
  testthat::expect_true(grepl("field 'path'", msg, fixed = TRUE))
  testthat::expect_true(grepl("invalid shape", msg, fixed = TRUE))
})

testthat::test_that("read_definitions rejects empty fst_columns columns", {
  tf <- tempfile(fileext = ".yml")
  bad_obj <- sample_definitions
  bad_obj$schemas[[1]]$checks[[1]] <- list(type = "fst_columns", path = "a.fst", columns = character(0))
  write_yaml_file(bad_obj, tf)

  err <- testthat::expect_error(read_definitions(tf))
  msg <- conditionMessage(err)
  testthat::expect_true(grepl(tf, msg, fixed = TRUE))
  testthat::expect_true(grepl("schema 'pre-lineup'", msg, fixed = TRUE))
  testthat::expect_true(grepl("field 'columns'", msg, fixed = TRUE))
  testthat::expect_true(grepl("invalid shape", msg, fixed = TRUE))
})

testthat::test_that("read_definitions rejects unreadable or invalid yaml", {
  missing <- tempfile(fileext = ".yml")
  missing_err <- testthat::expect_error(read_definitions(missing))
  missing_msg <- conditionMessage(missing_err)
  testthat::expect_true(grepl("Cannot read definitions file:", missing_msg, fixed = TRUE))
  testthat::expect_true(grepl(missing, missing_msg, fixed = TRUE))

  bad <- tempfile(fileext = ".yml")
  writeLines("version: [", bad)
  bad_err <- testthat::expect_error(read_definitions(bad))
  bad_msg <- conditionMessage(bad_err)
  testthat::expect_true(grepl("Failed to read yaml", bad_msg, fixed = TRUE))
  testthat::expect_true(grepl(bad, bad_msg, fixed = TRUE))
})

testthat::test_that("registry-only check type is accepted by loader and classifier", {
  tf <- tempfile(fileext = ".yml")
  obj <- list(
    version = 1,
    schemas = list(
      list(
        id = "dummy-schema",
        description = "Dummy schema for registry override test.",
        checks = list(
          list(type = "dummy_exists", path = "dummy.flag", present = TRUE)
        )
      )
    )
  )
  write_yaml_file(obj, tf)

  withr::local_options(list(
    pipschema.check_registry_override = list(
      dummy_exists = list(
        required_fields = c("path", "present"),
        runner = function(check, base_path) {
          target <- file.path(base_path, check$path)
          exists <- file.exists(target)
          expected <- isTRUE(check$present)
          if (identical(exists, expected)) {
            return(list(passed = TRUE, reason = NULL))
          }
          list(passed = FALSE, reason = sprintf("dummy_exists mismatch at %s", check$path))
        }
      )
    )
  ))

  defs <- read_definitions(tf)
  testthat::expect_equal(defs$schemas[[1]]$id, "dummy-schema")

  root <- tempfile("dummy-reg-")
  dir.create(root, recursive = TRUE)
  v <- make_vintage(root, "v", c("dummy.flag"))

  out <- classify_folder(v, defs)
  testthat::expect_equal(out$schema_id, "dummy-schema")
})
