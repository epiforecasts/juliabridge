test_that("eval_julia evaluates and converts simple expressions", {
  skip_if_not(nzchar(julia_bin()), "Julia not installed")
  expect_identical(eval_julia("1 + 1"), 2L)
  expect_identical(eval_julia('"hello"'), "hello")
})

test_that("call_julia invokes Julia functions", {
  skip_if_not(nzchar(julia_bin()), "Julia not installed")
  expect_identical(call_julia("+", 2L, 3L), 5L)
})

test_that("import_julia returns a callable proxy", {
  skip_if_not(nzchar(julia_bin()), "Julia not installed")
  base <- import_julia("Base")
  expect_identical(base$sum(1:5), 15L)
})

test_that("assign_julia binds a value in Main", {
  skip_if_not(nzchar(julia_bin()), "Julia not installed")
  expect_null(assign_julia("juliabridge_assigned", 7L))
  expect_identical(eval_julia("juliabridge_assigned"), 7L)
  expect_error(assign_julia("not valid", 1L), "Invalid Julia identifier")
})

test_that("get_julia translates a NamedTuple into a list", {
  skip_if_not(nzchar(julia_bin()), "Julia not installed")
  value <- get_julia(eval_julia("(a = 1, b = \"x\")"))
  expect_identical(value$a, 1L)
  expect_identical(value$b, "x")
})

test_that("command_julia runs code for its side effects", {
  skip_if_not(nzchar(julia_bin()), "Julia not installed")
  expect_invisible(command_julia("juliabridge_commanded = 3"))
  expect_identical(eval_julia("juliabridge_commanded"), 3L)
})
