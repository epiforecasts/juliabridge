test_that("manifest_julia_version reads the resolving version", {
  project <- withr::local_tempdir()
  writeLines(
    c("# This file is machine-generated", "julia_version = \"1.12.6\"",
      "manifest_format = \"2.0\""),
    file.path(project, "Manifest.toml")
  )
  expect_identical(manifest_julia_version(project), "1.12")
})

test_that("manifest_julia_version returns NULL without a version", {
  project <- withr::local_tempdir()
  expect_null(manifest_julia_version(project))
  writeLines("manifest_format = \"2.0\"", file.path(project, "Manifest.toml"))
  expect_null(manifest_julia_version(project))
})

test_that("juliaup_julia reports rather than fails when juliaup is absent", {
  withr::local_path(withr::local_tempdir(), action = "replace")
  expect_message(
    expect_null(juliaup_julia("1.12")),
    "juliaup not found"
  )
  expect_silent(expect_null(juliaup_julia("1.12", verbose = FALSE)))
})

test_that("a binary already chosen is left alone", {
  project <- withr::local_tempdir()
  writeLines("julia_version = \"1.12.6\"", file.path(project, "Manifest.toml"))
  chosen <- file.path("", "some", "julia")
  withr::local_envvar(JULIACONNECTOR_JULIABIN = chosen)
  expect_null(match_manifest_julia(project, verbose = FALSE))
  expect_identical(Sys.getenv("JULIACONNECTOR_JULIABIN"), chosen)
})
