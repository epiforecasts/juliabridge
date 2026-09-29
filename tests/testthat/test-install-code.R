# Regular expressions matching URLs are not file paths.
# nolint start: nonportable_path_linter.
test_that("registry install code is built correctly", {
  code <- .install_code("Distributions", character())
  expect_match(code, 'Pkg\\.add\\("Distributions"\\)')
  expect_match(code, "using Distributions")
})

test_that("github shorthand owner/repo is expanded to full URL", {
  code <- .install_code(
    "EpiBranch",
    c(EpiBranch = "epiforecasts/EpiBranch.jl")
  )
  expect_match(code, "https://github\\.com/epiforecasts/EpiBranch\\.jl")
  expect_match(code, "Pkg\\.PackageSpec\\(url=")
  expect_match(code, "using EpiBranch")
})

test_that("github subdir spec owner/repo:subdir is parsed", {
  code <- .install_code(
    "EpiAware",
    c(EpiAware = "CDCgov/Rt-without-renewal:EpiAware")
  )
  expect_match(code, "https://github\\.com/CDCgov/Rt-without-renewal")
  expect_match(code, 'subdir="EpiAware"')
})

test_that("full URL is passed through unchanged", {
  code <- .install_code(
    "Foo",
    c(Foo = "https://gitlab.example.org/x/Foo.jl")
  )
  expect_match(code, "https://gitlab\\.example\\.org/x/Foo\\.jl")
})
# nolint end
