test_that("ensure_julia calls init_fn when state is not ready", {
  env <- new.env(parent = emptyenv())
  calls <- new.env()
  calls$n <- 0L
  init <- function() {
    calls$n <- calls$n + 1L
    env$ready <- TRUE
  }
  ensure_julia(env, init)
  expect_identical(calls$n, 1L)
})

test_that("ensure_julia is a no-op when already ready", {
  env <- new.env(parent = emptyenv())
  env$ready <- TRUE
  calls <- new.env()
  calls$n <- 0L
  init <- function() {
    calls$n <- calls$n + 1L
  }
  ensure_julia(env, init)
  expect_identical(calls$n, 0L)
})

test_that("ensure_julia returns invisibly", {
  env <- new.env(parent = emptyenv())
  env$ready <- TRUE
  expect_invisible(ensure_julia(env, function() NULL))
})
