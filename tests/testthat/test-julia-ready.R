test_that("julia_ready is a no-op when state is already ready", {
  env <- new.env(parent = emptyenv())
  env$ready <- TRUE
  expect_silent(
    julia_ready(packages = "Distributions", state_env = env, verbose = FALSE)
  )
})

test_that("julia_ready loads Distributions in a fresh state_env", {
  skip_if_not(nzchar(julia_bin()), "Julia not installed")
  env <- new.env(parent = emptyenv())
  julia_ready(
    packages = c("Distributions", "Random"),
    state_env = env,
    verbose = FALSE
  )
  expect_true(isTRUE(env$ready))
  # Verify packages are actually loaded by accessing a function
  m <- eval_julia("Distributions.mean([1.0, 2.0, 3.0])")
  expect_equal(m, 2.0)
})

test_that("missing packages are installed, then the depot precompiled", {
  calls <- new.env()
  calls$code <- character()
  local_mocked_bindings(julia_subprocess = function(code, check = TRUE, bin) {
    calls$code <- c(calls$code, code)
    !identical(code, "using Missing")
  })
  expect_message(
    install_julia_packages(
      c("Present", "Missing"), character(), "julia",
      install = TRUE, verbose = TRUE
    ),
    "Installing Julia package: Missing"
  )
  expect_true(any(grepl('Pkg.add("Missing")', calls$code, fixed = TRUE)))
  expect_false(any(grepl('Pkg.add("Present")', calls$code, fixed = TRUE)))
  expect_identical(
    calls$code[length(calls$code)], "import Pkg; Pkg.precompile()"
  )
})

test_that("missing packages are an error with install = FALSE", {
  local_mocked_bindings(julia_subprocess = function(...) FALSE)
  expect_error(
    install_julia_packages(
      c("A", "B"), character(), "julia", install = FALSE, verbose = FALSE
    ),
    "not installed and install = FALSE: A, B"
  )
})

test_that("nothing is installed when every package loads", {
  local_mocked_bindings(julia_subprocess = function(code, ...) {
    if (!startsWith(code, "using")) stop("unexpected: ", code, call. = FALSE)
    TRUE
  })
  expect_null(install_julia_packages(
    "Present", character(), "julia", install = TRUE, verbose = FALSE
  ))
})

test_that("a project without Project.toml is an error", {
  expect_error(
    instantiate_julia_project(withr::local_tempdir(), "julia", FALSE),
    "No Project.toml found"
  )
})

test_that("instantiating a project activates it for the session", {
  project <- withr::local_tempdir()
  file.create(file.path(project, "Project.toml"))
  withr::local_envvar(JULIA_PROJECT = NA)
  seen <- new.env()
  local_mocked_bindings(julia_subprocess = function(code, bin) {
    seen$code <- code
    invisible(TRUE)
  })
  expect_message(
    instantiate_julia_project(project, "julia", verbose = TRUE),
    "Instantiating Julia project"
  )
  expect_match(seen$code, "Pkg.instantiate()", fixed = TRUE)
  expect_identical(
    Sys.getenv("JULIA_PROJECT"), normalizePath(project, mustWork = TRUE)
  )
})
