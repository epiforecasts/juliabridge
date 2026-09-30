test_that("scalars render as Julia literals", {
  expect_identical(.render(1), "1.0")
  expect_identical(.render(2L), "2")
  expect_identical(.render(0.1), "0.1")
  expect_identical(.render(1e-20), "1e-20")
  expect_identical(.render(-Inf), "-Inf")
  expect_identical(.render(NA_real_), "missing")
  expect_identical(.render(NaN), "NaN")
  expect_identical(.render(TRUE), "true")
  expect_identical(.render("a\"b"), "\"a\\\"b\"")
})

test_that("doubles round-trip exactly", {
  x <- 1 / 3
  expect_identical(as.numeric(.render(x)), x)
})

test_that("strings are escaped to ASCII, whatever the plane", {
  expect_identical(.render("caf\u00e9"), "\"caf\\u00e9\"")
  # Julia's \u takes at most four hex digits, so anything above the basic
  # plane needs the eight-digit escape or it becomes two characters.
  expect_identical(.render("a\U0001F600b"), "\"a\\U0001f600b\"")
  expect_error(.render_string(rawToChar(as.raw(255))), "valid UTF-8")
})

test_that("vectors and lists render as Julia vectors", {
  expect_identical(.render(c(0.2, 0.8)), "[0.2, 0.8]")
  expect_identical(.render(list(0.5)), "[0.5]")
  expect_identical(
    .render(list(component("Normal"), component("Gamma", 2, 1))),
    "[Normal(), Gamma(2.0, 1.0)]"
  )
  expect_error(.render(list(a = 1)), "Named lists")
  expect_error(.render(numeric()), "empty")
  expect_error(.render(sum), "Cannot render")
})

test_that("components render positional and keyword arguments", {
  expect_identical(as_julia(component("F", 1, a = 2L)), "F(1.0; a = 2)")
  expect_identical(as_julia(component("F")), "F()")
  expect_identical(
    as_julia(component("F", b = NULL, c = 3)), "F(; c = 3.0)"
  )
  expect_identical(
    as_julia(component("F", component("G"), h = component("H"))),
    "F(G(); h = H())"
  )
})

test_that("arguments Julia could not read are refused", {
  expect_error(component("bad name"), "a single name")
  expect_error(component(1), "a single name")
  expect_error(component("F", 1, NULL, 3), "positional argument")
  expect_error(component("F", `a b` = 1), "Julia identifiers")
  expect_error(component("F", role = "not a role"), "single name")
  expect_error(julia(""), "non-empty")
})

test_that("non-ASCII keyword names are escaped only in ASCII mode", {
  eps <- list(1)
  names(eps) <- "\u03f5_t"
  comp <- do.call(component, c("Process", eps))
  expect_identical(as_julia(comp), "Process(; \u03f5_t = 1.0)")
  expect_identical(
    as_julia(comp, ascii = TRUE),
    "Process(; (Symbol(\"\\u03f5_t\") => 1.0,)...)"
  )
})

test_that("julia() inserts code verbatim", {
  expect_identical(as_julia(julia("exp")), "exp")
  expect_identical(
    as_julia(component("F", transformation = julia("identity"))),
    "F(; transformation = identity)"
  )
})

test_that("roles are the caller's own vocabulary", {
  prior <- component("Normal", 0, 1, role = "prior")
  expect_s3_class(prior, "julia_prior")
  expect_s3_class(prior, "julia_component")
  expect_invisible(assert_role(prior, "prior"))
  expect_invisible(assert_role(prior, c("model", "prior")))
  expect_invisible(assert_role(NULL, "prior", null_ok = TRUE))
  expect_error(assert_role(prior, "model"), "must be a model component")
  expect_error(assert_role(prior, "observation"), "must be an observation")
  expect_error(
    assert_role(prior, "model", labels = c(model = "a fitted model")),
    "must be a fitted model"
  )
  expect_error(assert_role(prior, "model", arg_name = "x"), "`x` must be")
})

test_that("an untyped julia() expression satisfies any role", {
  expect_invisible(assert_role(julia("anything()"), "model"))
  expect_error(assert_role(julia("Normal()", role = "prior"), "model"))
})

test_that("printing breaks a long component over lines", {
  nested <- component(
    "Mixture",
    weights = component("Dirichlet", list(1, 1)),
    parts = list(
      component("Normal", 0, 1),
      component("Gamma", 6.5, 0.62)
    ),
    role = "model"
  )
  lines <- .format_code(nested)
  expect_gt(length(lines), 1)
  expect_true(all(nchar(lines) <= 78))
  expect_output(print(nested), "<julia model component>")
  expect_output(print(julia("exp")), "<julia Julia code>")
  expect_output(print(component("Normal")), "Normal\\(\\)")
})

test_that("a class of the caller's own renders through as_julia_value()", {
  # Registered as a consuming package would register it: the generic is
  # called from inside this package, so dispatch reads the methods table
  # rather than the caller's environment. The classes exist only here.
  registerS3method(
    "as_julia_value", "my_normal",
    function(x, ...) component("Normal", x$mean, x$sd)
  )
  registerS3method(
    "as_julia_value", "my_scalar",
    function(x, ...) component("Dirac", unclass(x))
  )

  # Such a class is usually a list or a vector underneath, which would
  # otherwise be rendered as one.
  spec <- structure(list(mean = 0, sd = 1), class = "my_normal")
  expect_identical(as_julia(component("F", spec)), "F(Normal(0.0, 1.0))")
  expect_identical(as_julia(spec), "Normal(0.0, 1.0)")
  expect_identical(
    as_julia(component("F", structure(3.5, class = "my_scalar"))),
    "F(Dirac(3.5))"
  )
})

test_that("a class with no method says what is missing", {
  expect_error(as_julia(component("F", factor("a"))), "as_julia_value")
  expect_error(as_julia(component("F", sum)), "class 'function'")
})

test_that("a component with no role is accepted wherever one is expected", {
  untyped <- component("Normal", 0, 1)
  expect_s3_class(untyped, "julia_component", exact = TRUE)
  expect_invisible(assert_role(untyped, "prior"))
  expect_invisible(assert_role(untyped, c("prior", "model")))
  expect_output(print(untyped), "<julia untyped component>")
  # A role, once given, is still checked
  expect_error(
    assert_role(component("Normal", 0, 1, role = "prior"), "model"),
    "must be a model component"
  )
})
