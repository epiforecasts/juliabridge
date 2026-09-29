test_that("manifest_julia_version reads the resolving version", {
  project <- withr::local_tempdir()
  writeLines(
    c("# This file is machine-generated", "julia_version = \"1.12.6\"",
      "manifest_format = \"2.0\""),
    file.path(project, "Manifest.toml")
  )
  expect_identical(manifest_julia_version(project), "1.12")
})

test_that("manifest_julia_version prefers the newest versioned manifest", {
  project <- withr::local_tempdir()
  writeLines("julia_version = \"1.10.4\"", file.path(project, "Manifest.toml"))
  writeLines(
    "julia_version = \"1.9.4\"", file.path(project, "Manifest-v1.9.toml")
  )
  writeLines(
    "julia_version = \"1.12.6\"", file.path(project, "Manifest-v1.12.toml")
  )
  expect_identical(manifest_julia_version(project), "1.12")
})

test_that("a versioned manifest's name gives the version it lacks", {
  project <- withr::local_tempdir()
  writeLines(
    "manifest_format = \"2.0\"", file.path(project, "Manifest-v1.11.toml")
  )
  expect_identical(manifest_julia_version(project), "1.11")
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
  chosen <- withr::local_tempfile()
  file.create(chosen)
  withr::local_envvar(JULIACONNECTOR_JULIABIN = chosen)
  expect_null(match_manifest_julia(project, verbose = FALSE))
  expect_identical(Sys.getenv("JULIACONNECTOR_JULIABIN"), chosen)
})

test_that("juliaup_julia returns the binary of an installed channel", {
  skip_if_not(nzchar(Sys.which("juliaup")), "juliaup not installed")
  skip_on_cran()
  bin <- juliaup_julia("1.12", verbose = FALSE)
  skip_if(is.null(bin), "Julia 1.12 could not be installed")
  expect_true(file.exists(bin))
  version <- system2(bin, "--version", stdout = TRUE)
  expect_match(version, "version 1.12.", fixed = TRUE)
})

test_that("a binary juliaready set itself does not block matching", {
  project <- withr::local_tempdir()
  writeLines("julia_version = \"1.12.6\"", file.path(project, "Manifest.toml"))
  ours <- file.path("", "earlier", "julia")
  withr::local_envvar(JULIACONNECTOR_JULIABIN = NA)
  withr::defer(assign("juliabin", NULL, envir = .juliaready_state))
  set_juliabin(ours)
  local_mocked_bindings(juliaup_julia = function(version, verbose) {
    file.path("", "matched", version, "julia")
  })
  expect_identical(match_manifest_julia(project, verbose = FALSE), "1.12")
  expect_identical(
    Sys.getenv("JULIACONNECTOR_JULIABIN"),
    file.path("", "matched", "1.12", "julia")
  )
})

test_that("a failed juliaup install is reported", {
  skip_if_not(nzchar(Sys.which("juliaup")), "juliaup not installed")
  skip_on_cran()
  expect_message(
    expect_null(juliaup_julia("0.0.0-nonexistent")),
    "could not install"
  )
})

test_that("a user-chosen binary survives repeated setups", {
  chosen <- unname(julia_bin())
  skip_if_not(nzchar(chosen), "Julia not installed")
  project <- withr::local_tempdir()
  writeLines("julia_version = \"1.12.6\"", file.path(project, "Manifest.toml"))
  withr::local_envvar(JULIACONNECTOR_JULIABIN = chosen)
  withr::defer(assign("juliabin", NULL, envir = .juliaready_state))
  local_mocked_bindings(
    instantiate_julia_project = function(...) invisible(NULL),
    mark_setup = function(...) invisible(NULL),
    juliaup_julia = function(...) stop("should not be called", call. = FALSE)
  )
  local_mocked_bindings(
    juliaEval = function(...) NULL,
    .package = "JuliaConnectoR"
  )
  for (i in 1:2) {
    julia_ready(
      packages = character(), state_env = new.env(), project = project,
      verbose = FALSE
    )
  }
  expect_identical(Sys.getenv("JULIACONNECTOR_JULIABIN"), chosen)
})

test_that("a binary found on the PATH is recognised as juliaready's own", {
  withr::local_envvar(JULIACONNECTOR_JULIABIN = NA)
  withr::defer(assign("juliabin", NULL, envir = .juliaready_state))
  set_juliabin(c(julia = file.path("", "usr", "bin", "julia")))
  expect_false(user_juliabin())
})

test_that("a JULIACONNECTOR_JULIABIN that does not exist is not a choice", {
  withr::local_envvar(
    JULIACONNECTOR_JULIABIN = file.path(tempdir(), "no-such-julia")
  )
  expect_false(user_juliabin())
})
