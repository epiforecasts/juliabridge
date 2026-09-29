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
