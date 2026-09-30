test_that("julia_ready with project = ... activates and uses the project", {
  skip_if_not(nzchar(julia_bin()), "Julia not installed")

  # Build a minimal pinned project containing only Distributions
  proj <- tempfile("juliabridge_test_proj_")
  dir.create(proj)
  on.exit(unlink(proj, recursive = TRUE), add = TRUE)
  julia_subprocess(sprintf(
    paste(
      'import Pkg; Pkg.activate("%s");',
      'Pkg.add("Distributions"); Pkg.instantiate()'
    ),
    # Backslashes in Windows paths would be read as escapes in a Julia string
    normalizePath(proj, winslash = "/")
  ))
  expect_true(file.exists(file.path(proj, "Project.toml")))

  env <- new.env(parent = emptyenv())
  julia_ready(
    packages = "Distributions",
    state_env = env,
    project = proj,
    verbose = FALSE
  )
  expect_true(isTRUE(env$ready))
  expect_equal(eval_julia("Distributions.mean([1.0, 2.0])"), 1.5)
})
