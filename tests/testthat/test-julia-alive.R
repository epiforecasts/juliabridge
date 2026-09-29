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
