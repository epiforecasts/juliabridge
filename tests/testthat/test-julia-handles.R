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
  state$ready <- TRUE
  state$setup <- "setup_a"
  state$released <- list(
    list(handle = 1L, session = "token", setup = "setup_a"),
    list(handle = 2L, session = "token", setup = "setup_a")
  )
  calls <- new.env(parent = emptyenv())
  calls$seen <- list()
  local_mocked_bindings(
    call_julia = function(name, handle, session) {
      calls$seen <- c(calls$seen, list(c(name, handle, session)))
      NULL
    }
  )
  expect_identical(julia_release_pending(state, "Bridge.release!"), 2L)
  expect_length(calls$seen, 2)
  expect_null(state$released)
  expect_identical(julia_release_pending(state, "Bridge.release!"), 0L)
})

test_that("a failed release does not propagate and stays queued", {
  state <- new.env(parent = emptyenv())
  state$ready <- TRUE
  state$setup <- "setup_a"
  entry <- list(handle = 1L, session = "token", setup = "setup_a")
  state$released <- list(entry)
  local_mocked_bindings(
    call_julia = function(...) stop("bridge not loaded", call. = FALSE)
  )
  expect_identical(julia_release_pending(state, "Bridge.release!"), 0L)
  expect_identical(state$released, list(entry))
})

test_that("the queue is dropped without a set-up session", {
  state <- new.env(parent = emptyenv())
  state$released <- list(list(handle = 1L, session = "token", setup = "a"))
  local_mocked_bindings(
    call_julia = function(...) stop("not called", call. = FALSE)
  )
  expect_identical(julia_release_pending(state, "Bridge.release!"), 0L)
  expect_null(state$released)
})

test_that("handles from an earlier setup are dropped, not released", {
  state <- new.env(parent = emptyenv())
  state$ready <- TRUE
  state$setup <- "setup_b"
  state$released <- list(
    list(handle = 1L, session = "old", setup = "setup_a"),
    list(handle = 2L, session = "new", setup = "setup_b")
  )
  released <- new.env(parent = emptyenv())
  local_mocked_bindings(call_julia = function(name, handle, session) {
    released$handles <- c(released$handles, handle)
  })
  expect_identical(julia_release_pending(state, "Bridge.release!"), 1L)
  expect_identical(released$handles, 2L)
  expect_null(state$released)
})

test_that("a handle from an earlier setup is not owned", {
  state <- new.env(parent = emptyenv())
  state$setup <- "setup_a"
  handle <- julia_handle(3L, "token", state)
  expect_true(julia_handle_owned(handle, state))
  state$setup <- "setup_b"
  expect_false(julia_handle_owned(handle, state))
})
