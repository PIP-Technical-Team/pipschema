build_assign_defs <- function() {
  list(
    version = 1,
    schemas = list(
      list(
        id = "pre-lineup",
        description = "Has none of the four lineup markers (lineup_data/, prod_refy_estimation.fst, lineup_years.fst, lineup_dist_stats.fst).",
        checks = list(
          list(type = "dir_exists", path = "lineup_data", present = FALSE),
          list(type = "file_exists", path = "estimations/prod_refy_estimation.fst", present = FALSE),
          list(type = "file_exists", path = "estimations/lineup_years.fst", present = FALSE),
          list(type = "file_exists", path = "estimations/lineup_dist_stats.fst", present = FALSE)
        )
      ),
      list(
        id = "new-lineup",
        description = "Has lineup_data/ (non-empty, .fst only) and the three lineup estimation files (prod_refy_estimation.fst, lineup_years.fst, lineup_dist_stats.fst).",
        checks = list(
          list(type = "dir_exists", path = "lineup_data", present = TRUE),
          list(type = "dir_extension", path = "lineup_data", extension = ".fst"),
          list(type = "file_exists", path = "estimations/prod_refy_estimation.fst", present = TRUE),
          list(type = "file_exists", path = "estimations/lineup_years.fst", present = TRUE),
          list(type = "file_exists", path = "estimations/lineup_dist_stats.fst", present = TRUE)
        )
      )
    )
  )
}

read_file_bytes <- function(path) {
  con <- file(path, open = "rb")
  on.exit(close(con), add = TRUE)
  readBin(con, what = "raw", n = file.info(path)$size)
}

testthat::test_that("assign_schemas writes sorted deterministic yaml with checks", {
  defs <- build_assign_defs()
  root <- tempfile("assign-root-")
  dir.create(root, recursive = TRUE)

  make_vintage(root, "20260324_2021_01_02_PROD", c(
    "lineup_data/BRA_2021.fst",
    "estimations/prod_refy_estimation.fst",
    "estimations/lineup_years.fst",
    "estimations/lineup_dist_stats.fst"
  ))
  make_vintage(root, "20250401_2021_01_02_PROD", c("estimations/anything.fst"))

  output <- tempfile(fileext = ".yml")
  out <- assign_schemas(data_dir = root, output = output, definitions = defs)

  testthat::expect_identical(normalizePath(out, winslash = "/", mustWork = TRUE), normalizePath(output, winslash = "/", mustWork = TRUE))
  testthat::expect_true(file.exists(output))

  parsed <- yaml::read_yaml(output)
  testthat::expect_equal(parsed$version, defs$version)

  ids <- vapply(parsed$schemas, `[[`, character(1), "id")
  testthat::expect_equal(ids, sort(ids))

  new_schema <- parsed$schemas[[which(ids == "new-lineup")]]
  pre_schema <- parsed$schemas[[which(ids == "pre-lineup")]]
  testthat::expect_equal(
    new_schema$description,
    "Has lineup_data/ (non-empty, .fst only) and the three lineup estimation files (prod_refy_estimation.fst, lineup_years.fst, lineup_dist_stats.fst)."
  )
  testthat::expect_equal(
    pre_schema$description,
    "Has none of the four lineup markers (lineup_data/, prod_refy_estimation.fst, lineup_years.fst, lineup_dist_stats.fst)."
  )
  testthat::expect_equal(new_schema$folders, "20260324_2021_01_02_PROD")
  testthat::expect_equal(pre_schema$folders, "20250401_2021_01_02_PROD")
  testthat::expect_true(length(new_schema$checks) > 0)
})

testthat::test_that("assign_schemas output is byte-identical across repeated runs", {
  defs <- build_assign_defs()
  root <- tempfile("assign-byte-")
  dir.create(root, recursive = TRUE)

  make_vintage(root, "b_folder", c("estimations/anything.fst"))
  make_vintage(root, "a_folder", c(
    "lineup_data/ARG_2020.fst",
    "estimations/prod_refy_estimation.fst",
    "estimations/lineup_years.fst",
    "estimations/lineup_dist_stats.fst"
  ))

  out1 <- tempfile(fileext = ".yml")
  out2 <- tempfile(fileext = ".yml")

  assign_schemas(root, out1, defs)
  assign_schemas(root, out2, defs)

  testthat::expect_identical(read_file_bytes(out1), read_file_bytes(out2))
})

testthat::test_that("assign_schemas writes nothing on unmatched folder", {
  defs <- build_assign_defs()
  root <- tempfile("assign-unmatched-")
  dir.create(root, recursive = TRUE)

  v <- make_vintage(root, "bad_folder", c(
    "lineup_data/ARG_2020.fst",
    "estimations/prod_refy_estimation.fst"
  ))

  files <- list.files(v, recursive = TRUE, full.names = TRUE)
  files <- files[file.info(files)$isdir %in% FALSE]
  before <- file.info(files)$mtime
  names(before) <- normalizePath(files, winslash = "/", mustWork = TRUE)

  output <- tempfile(fileext = ".yml")
  testthat::expect_error(assign_schemas(root, output, defs), "No schema matched|bad_folder")
  testthat::expect_false(file.exists(output))

  after <- file.info(files)$mtime
  names(after) <- normalizePath(files, winslash = "/", mustWork = TRUE)
  testthat::expect_equal(after[names(before)], before)
})

testthat::test_that("assign_schemas writes nothing on ambiguous match", {
  defs <- list(
    version = 1,
    schemas = list(
      list(id = "a", checks = list(list(type = "file_exists", path = "x.flag", present = TRUE))),
      list(id = "b", checks = list(list(type = "file_exists", path = "x.flag", present = TRUE)))
    )
  )

  root <- tempfile("assign-ambiguous-")
  dir.create(root, recursive = TRUE)
  v <- make_vintage(root, "amb", c("x.flag"))

  files <- list.files(v, recursive = TRUE, full.names = TRUE)
  files <- files[file.info(files)$isdir %in% FALSE]
  before <- file.info(files)$mtime
  names(before) <- normalizePath(files, winslash = "/", mustWork = TRUE)

  output <- tempfile(fileext = ".yml")
  testthat::expect_error(assign_schemas(root, output, defs), "matched multiple schemas|amb")
  testthat::expect_false(file.exists(output))

  after <- file.info(files)$mtime
  names(after) <- normalizePath(files, winslash = "/", mustWork = TRUE)
  testthat::expect_equal(after[names(before)], before)
})

testthat::test_that("assign_schemas writes nothing on unevaluable check and preserves mtimes", {
  defs <- list(
    version = 1,
    schemas = list(
      list(
        id = "header-check",
        checks = list(
          list(type = "fst_columns", path = "estimations/not_a_real_fst.fst", columns = c("country_code"))
        )
      )
    )
  )

  root <- tempfile("assign-unevaluable-")
  dir.create(root, recursive = TRUE)
  v <- make_vintage(root, "broken", c("estimations/not_a_real_fst.fst"))

  files <- list.files(v, recursive = TRUE, full.names = TRUE)
  files <- files[file.info(files)$isdir %in% FALSE]
  before <- file.info(files)$mtime
  names(before) <- normalizePath(files, winslash = "/", mustWork = TRUE)

  output <- tempfile(fileext = ".yml")
  testthat::expect_error(assign_schemas(root, output, defs), "Cannot read fst header|estimations/not_a_real_fst.fst")
  testthat::expect_false(file.exists(output))

  after <- file.info(files)$mtime
  names(after) <- normalizePath(files, winslash = "/", mustWork = TRUE)
  testthat::expect_equal(after[names(before)], before)
})

testthat::test_that("assign_schemas errors for unreadable data_dir before write", {
  output <- tempfile(fileext = ".yml")
  bad <- tempfile("missing-dir-")

  testthat::expect_error(assign_schemas(bad, output, build_assign_defs()), "Data directory does not exist")
  testthat::expect_false(file.exists(output))
})

testthat::test_that("assign_schemas errors for empty data_dir before write", {
  root <- tempfile("assign-empty-")
  dir.create(root, recursive = TRUE)

  output <- tempfile(fileext = ".yml")
  testthat::expect_error(assign_schemas(root, output, build_assign_defs()), "No child directories found")
  testthat::expect_false(file.exists(output))
})

testthat::test_that("assign_schemas rejects a non-scalar description even when bypassing read_definitions", {
  defs <- list(
    version = 1,
    schemas = list(
      list(
        id = "bad-desc",
        description = c("one", "two"),
        checks = list(list(type = "file_exists", path = "x.flag", present = TRUE))
      )
    )
  )

  root <- tempfile("assign-bad-desc-")
  dir.create(root, recursive = TRUE)
  make_vintage(root, "v", c("x.flag"))

  output <- tempfile(fileext = ".yml")
  testthat::expect_error(assign_schemas(root, output, defs), "invalid 'description'")
  testthat::expect_false(file.exists(output))
})
