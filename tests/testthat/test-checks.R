with_temp_vintage <- function(files = character(), code) {
  root <- tempfile("vintage-root-")
  dir.create(root, recursive = TRUE)
  v <- make_vintage(root, "vintage", files)
  force(v)
  force(root)
  eval(substitute(code), envir = list(v = v, root = root), enclos = parent.frame())
}

testthat::test_that("file_exists check passes and fails with reason", {
  with_temp_vintage(c("estimations/prod_refy_estimation.fst"), {
    ok <- run_check(list(type = "file_exists", path = "estimations/prod_refy_estimation.fst", present = TRUE), v)
    testthat::expect_true(ok$passed)

    miss <- run_check(list(type = "file_exists", path = "estimations/lineup_years.fst", present = TRUE), v)
    testthat::expect_false(miss$passed)
    testthat::expect_match(miss$reason, "missing|expected")
  })
})

testthat::test_that("dir_exists check supports present false", {
  with_temp_vintage(character(), {
    res <- run_check(list(type = "dir_exists", path = "lineup_data", present = FALSE), v)
    testthat::expect_true(res$passed)
  })
})

testthat::test_that("dir_extension requires non-empty directory and all files match extension", {
  with_temp_vintage(c("lineup_data/ARG_2020.fst", "lineup_data/BRA_2021.fst"), {
    ok <- run_check(list(type = "dir_extension", path = "lineup_data", extension = ".fst"), v)
    testthat::expect_true(ok$passed)
  })

  with_temp_vintage(c("lineup_data/ARG_2020.fst", "lineup_data/readme.txt"), {
    bad <- run_check(list(type = "dir_extension", path = "lineup_data", extension = ".fst"), v)
    testthat::expect_false(bad$passed)
  })

  with_temp_vintage(character(), {
    dir.create(file.path(v, "lineup_data"), recursive = TRUE)
    empty <- run_check(list(type = "dir_extension", path = "lineup_data", extension = ".fst"), v)
    testthat::expect_false(empty$passed)
  })
})

testthat::test_that("unknown check type errors", {
  with_temp_vintage(character(), {
    testthat::expect_error(run_check(list(type = "not_real"), v), "Unknown check")
  })
})

testthat::test_that("fst_columns signals unevaluable header errors with path", {
  with_temp_vintage(c("estimations/not_a_real_fst.fst"), {
    testthat::expect_error(
      run_check(
        list(
          type = "fst_columns",
          path = "estimations/not_a_real_fst.fst",
          columns = c("country_code")
        ),
        v
      ),
      "Cannot read fst header 'estimations/not_a_real_fst\\.fst'"
    )
  })
})
