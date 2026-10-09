testthat::test_that("make_vintage creates requested files", {
  root <- tempdir(check = TRUE)
  vintage <- make_vintage(
    root = root,
    name = "20250930_2017_01_02_PROD",
    files = c(
      "estimations/prod_refy_estimation.fst",
      "estimations/lineup_years.fst",
      "estimations/lineup_dist_stats.fst",
      "lineup_data/ARG_2020.fst"
    )
  )

  testthat::expect_true(dir.exists(vintage))
  testthat::expect_true(file.exists(file.path(vintage, "estimations", "prod_refy_estimation.fst")))
  testthat::expect_true(file.exists(file.path(vintage, "lineup_data", "ARG_2020.fst")))
})

testthat::test_that("make_vintage is stable to file order", {
  root <- tempdir(check = TRUE)
  files_a <- c(
    "estimations/prod_refy_estimation.fst",
    "estimations/lineup_years.fst",
    "lineup_data/ARG_2020.fst"
  )
  files_b <- rev(files_a)

  v1 <- make_vintage(root, "vintage_a", files_a)
  v2 <- make_vintage(root, "vintage_b", files_b)

  l1 <- list.files(v1, recursive = TRUE, all.files = FALSE)
  l2 <- list.files(v2, recursive = TRUE, all.files = FALSE)

  testthat::expect_equal(sort(l1), sort(l2))
})

testthat::test_that("make_vintage refuses roots outside tempdir", {
  outside <- normalizePath(file.path(tempdir(check = TRUE), ".."), winslash = "/", mustWork = TRUE)

  testthat::expect_error(
    make_vintage(outside, "bad_vintage", c("a.txt")),
    "tempdir"
  )
})
