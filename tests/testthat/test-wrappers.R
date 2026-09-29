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
