sample_definitions <- list(
  version = 1,
  schemas = list(
    list(
      id = "pre-lineup",
      checks = list(
        list(type = "dir_exists", path = "lineup_data", present = FALSE)
      )
    ),
    list(
      id = "new-lineup",
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
