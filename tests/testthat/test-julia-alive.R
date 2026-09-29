test_that("julia_alive is FALSE before setup has run", {
  state <- new.env(parent = emptyenv())
  expect_false(julia_alive(state))
})

test_that("julia_alive clears the flag when the session has gone", {
  state <- new.env(parent = emptyenv())
  state$ready <- TRUE
  local_mocked_bindings(
    juliaEval = function(...) stop("no connection", call. = FALSE),
    .package = "JuliaConnectoR"
  )
  expect_false(julia_alive(state))
  expect_false(isTRUE(state$ready))
})

test_that("julia_alive keeps the flag while the probe answers", {
  state <- new.env(parent = emptyenv())
  state$ready <- TRUE
  local_mocked_bindings(
    juliaEval = function(code) identical(code, "isdefined(Main, :Bridge)"),
    .package = "JuliaConnectoR"
  )
  expect_true(julia_alive(state, "isdefined(Main, :Bridge)"))
  expect_true(state$ready)
  expect_false(julia_alive(state, "isdefined(Main, :Other)"))
})

test_that("julia_alive is FALSE in a server it was not set up in", {
  state <- new.env(parent = emptyenv())
  state$ready <- TRUE
  state$setup <- "setup_a"
  local_mocked_bindings(
    juliaEval = function(code) grepl('"setup_b"', code, fixed = TRUE),
    .package = "JuliaConnectoR"
  )
  expect_false(julia_alive(state))
  expect_false(isTRUE(state$ready))
})

test_that("julia_alive finds the setup token in a live session", {
  skip_if_not(nzchar(julia_bin()), "Julia not installed")
  state <- new.env(parent = emptyenv())
  julia_ready(packages = character(), state_env = state, verbose = FALSE)
  expect_true(julia_alive(state))
  JuliaConnectoR::stopJulia()
  expect_false(julia_alive(state))
  expect_false(isTRUE(state$ready))
})
