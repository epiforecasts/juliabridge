test_that("a missing bridge file is reported with its package", {
  expect_error(
    julia_load_bridge("juliaready", "no-such-bridge.jl"),
    "Bridge file not found: .*no-such-bridge.jl in package 'juliaready'"
  )
})

test_that("bridge files are evaluated in the Julia session", {
  skip_if_not(nzchar(julia_bin()), "Julia not installed")
  src <- withr::local_tempdir()
  writeLines(
    c("Package: bridgetest", "Version: 0.0.1", "Title: Test",
      "Description: Test.", "License: MIT", "Encoding: UTF-8"),
    file.path(src, "DESCRIPTION")
  )
  writeLines("", file.path(src, "NAMESPACE"))
  dir.create(file.path(src, "inst", "julia"), recursive = TRUE)
  writeLines(
    "juliaready_bridge_test(x) = 2x",
    file.path(src, "inst", "julia", "double.jl")
  )
  lib <- withr::local_tempdir()
  install <- system2(
    file.path(R.home("bin"), "R"),
    c("CMD", "INSTALL", "--no-test-load", paste0("--library=", lib), src),
    stdout = FALSE, stderr = FALSE
  )
  expect_identical(install, 0L)
  withr::local_libpaths(lib, action = "prefix")

  expect_message(
    julia_load_bridge("bridgetest", "double.jl", verbose = TRUE),
    "Loading Julia bridge: double.jl"
  )
  expect_identical(call_julia("juliaready_bridge_test", 21L), 42L)
})
