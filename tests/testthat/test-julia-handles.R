test_that("a handle records its session and owner", {
  state <- new.env(parent = emptyenv())
  handle <- julia_handle(3L, "token", state)
  expect_identical(handle$handle, 3L)
  expect_identical(handle$session, "token")
  expect_true(julia_handle_owned(handle, state))
})

test_that("a saved and reloaded handle is not owned", {
  state <- new.env(parent = emptyenv())
  file <- withr::local_tempfile()
  saveRDS(julia_handle(3L, "token", state), file)
  expect_false(julia_handle_owned(readRDS(file), state))
})

test_that("only an owned handle is queued for release", {
  state <- new.env(parent = emptyenv())
  local({
    owned <- julia_handle(1L, "token", state)
    foreign <- julia_handle(2L, "token", state)
    foreign$owner <- new.env()
    NULL
  })
  gc()
  queued <- vapply(state$released, function(x) x$handle, integer(1))
  expect_true(1L %in% queued)
  expect_false(2L %in% queued)
})

test_that("flushing releases each queued handle once", {
  state <- new.env(parent = emptyenv())
  state$released <- list(
    list(handle = 1L, session = "token"),
    list(handle = 2L, session = "token")
  )
  released <- list()
  local_mocked_bindings(
    call_julia = function(name, handle, session) {
      released[[length(released) + 1]] <<- c(name, handle, session)
      NULL
    }
  )
  expect_identical(julia_release_pending(state, "Bridge.release!"), 2L)
  expect_length(released, 2)
  expect_null(state$released)
  expect_identical(julia_release_pending(state, "Bridge.release!"), 0L)
})

test_that("a failed release does not propagate", {
  state <- new.env(parent = emptyenv())
  state$released <- list(list(handle = 1L, session = "token"))
  local_mocked_bindings(
    call_julia = function(...) stop("session gone", call. = FALSE)
  )
  expect_identical(julia_release_pending(state, "Bridge.release!"), 1L)
})
