test_that("julia_bin returns a path or empty string", {
  bin <- julia_bin()
  expect_type(bin, "character")
  expect_length(bin, 1)
  if (nzchar(bin)) {
    expect_true(file.exists(bin))
  }
})

test_that("julia_bin returns an executable file when Julia is installed", {
  bin <- julia_bin()
  skip_if_not(nzchar(bin), "Julia not installed")
  expect_identical(unname(file.access(bin, mode = 1)), 0L)
})
