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

test_that("julia_bin uses a Julia in JULIA_BINDIR", {
  bindir <- withr::local_tempdir()
  exe <- if (.Platform$OS.type == "windows") "julia.exe" else "julia"
  file.create(file.path(bindir, exe))
  withr::local_envvar(JULIACONNECTOR_JULIABIN = NA, JULIA_BINDIR = bindir)
  expect_identical(julia_bin(), file.path(bindir, exe))
})

test_that("an empty JULIA_BINDIR is skipped", {
  withr::local_envvar(JULIA_BINDIR = withr::local_tempdir())
  expect_identical(bindir_julia(), "")
})

test_that("a missing Julia binary is an error", {
  expect_error(check_julia_bin(""), "Julia not found")
  expect_error(
    check_julia_bin(file.path(tempdir(), "no-such-julia")),
    "Julia not found"
  )
})

test_that("a failing subprocess is an error, or FALSE when not checked", {
  skip_if_not(nzchar(julia_bin()), "Julia not installed")
  expect_error(
    suppressMessages(julia_subprocess("exit(3)")),
    "Julia subprocess failed (exit 3)",
    fixed = TRUE
  )
  expect_false(julia_subprocess("exit(3)", check = FALSE))
})
