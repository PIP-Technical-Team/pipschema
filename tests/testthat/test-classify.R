build_defs <- function() {
  list(
    version = 1,
    schemas = list(
      list(
        id = "pre-lineup",
        checks = list(
          list(type = "dir_exists", path = "lineup_data", present = FALSE),
          list(type = "file_exists", path = "estimations/prod_refy_estimation.fst", present = FALSE),
          list(type = "file_exists", path = "estimations/lineup_years.fst", present = FALSE),
          list(type = "file_exists", path = "estimations/lineup_dist_stats.fst", present = FALSE)
        )
      ),
      list(
        id = "new-lineup",
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

testthat::test_that("classify_folder returns expected schema", {
  defs <- build_defs()
  root <- tempfile("classify-")
  dir.create(root, recursive = TRUE)

  pre <- make_vintage(root, "pre", c("estimations/other.fst"))
  new <- make_vintage(root, "new", c(
    "lineup_data/ARG_2020.fst",
    "estimations/prod_refy_estimation.fst",
    "estimations/lineup_years.fst",
    "estimations/lineup_dist_stats.fst"
  ))

  testthat::expect_equal(classify_folder(pre, defs)$schema_id, "pre-lineup")
  testthat::expect_equal(classify_folder(new, defs)$schema_id, "new-lineup")
})

testthat::test_that("classify_folder tolerates extra unlisted file", {
  defs <- build_defs()
  root <- tempfile("classify-extra-")
  dir.create(root, recursive = TRUE)

  v <- make_vintage(root, "new", c(
    "lineup_data/ARG_2020.fst",
    "extras/README.txt",
    "estimations/prod_refy_estimation.fst",
    "estimations/lineup_years.fst",
    "estimations/lineup_dist_stats.fst"
  ))

  out <- classify_folder(v, defs)
  testthat::expect_equal(out$schema_id, "new-lineup")
})

testthat::test_that("classify_folder supports third schema without code edits", {
  defs <- list(
    version = 1,
    schemas = list(
      list(
        id = "pre-lineup",
        checks = list(
          list(type = "dir_exists", path = "lineup_data", present = FALSE),
          list(type = "file_exists", path = "estimations/prod_refy_estimation.fst", present = FALSE),
          list(type = "file_exists", path = "estimations/lineup_years.fst", present = FALSE),
          list(type = "file_exists", path = "estimations/lineup_dist_stats.fst", present = FALSE),
          list(type = "file_exists", path = "legacy.flag", present = FALSE)
        )
      ),
      list(
        id = "new-lineup",
        checks = list(
          list(type = "dir_exists", path = "lineup_data", present = TRUE),
          list(type = "dir_extension", path = "lineup_data", extension = ".fst"),
          list(type = "file_exists", path = "estimations/prod_refy_estimation.fst", present = TRUE),
          list(type = "file_exists", path = "estimations/lineup_years.fst", present = TRUE),
          list(type = "file_exists", path = "estimations/lineup_dist_stats.fst", present = TRUE)
        )
      ),
      list(
        id = "legacy",
        checks = list(
          list(type = "file_exists", path = "legacy.flag", present = TRUE)
        )
      )
    )
  )

  root <- tempfile("classify-third-")
  dir.create(root, recursive = TRUE)
  v <- make_vintage(root, "legacy", c("legacy.flag"))

  out <- classify_folder(v, defs)
  testthat::expect_equal(out$schema_id, "legacy")
})

testthat::test_that("classify_folder errors on zero and multiple matches", {
  defs <- list(
    version = 1,
    schemas = list(
      list(id = "a", checks = list(list(type = "file_exists", path = "a.flag", present = TRUE))),
      list(id = "b", checks = list(list(type = "file_exists", path = "b.flag", present = TRUE)))
    )
  )

  root <- tempfile("classify-errors-")
  dir.create(root, recursive = TRUE)

  none <- make_vintage(root, "none", c("x.txt"))
  both <- make_vintage(root, "both", c("a.flag", "b.flag"))

  testthat::expect_error(classify_folder(none, defs), "No schema matched")
  testthat::expect_error(classify_folder(both, defs), "matched multiple schemas")
})

testthat::test_that("classify_folder leaves file mtimes unchanged", {
  defs <- build_defs()
  root <- tempfile("classify-mtime-")
  dir.create(root, recursive = TRUE)

  v <- make_vintage(root, "new", c(
    "lineup_data/ARG_2020.fst",
    "estimations/prod_refy_estimation.fst",
    "estimations/lineup_years.fst",
    "estimations/lineup_dist_stats.fst"
  ))

  files <- list.files(v, recursive = TRUE, full.names = TRUE, all.files = FALSE)
  files <- files[file.info(files)$isdir %in% FALSE]

  before <- file.info(files)$mtime
  names(before) <- normalizePath(files, winslash = "/", mustWork = TRUE)

  out <- classify_folder(v, defs)
  testthat::expect_equal(out$schema_id, "new-lineup")

  after <- file.info(files)$mtime
  names(after) <- normalizePath(files, winslash = "/", mustWork = TRUE)

  testthat::expect_equal(after[names(before)], before)
})
