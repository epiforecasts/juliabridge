test_that("scalars render as Julia literals", {
  expect_identical(.render(1), "1.0")
  expect_identical(.render(2L), "2")
  expect_identical(.render(0.1), "0.1")
  expect_identical(.render(1e-20), "1e-20")
  expect_identical(.render(-Inf), "-Inf")
  expect_identical(.render(NA_real_), "missing")
  expect_identical(.render(NA_character_), "missing")
  expect_identical(.render(c("a", NA)), "[\"a\", missing]")
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
    .render(list(julia_spec("Normal"), julia_spec("Gamma", 2, 1))),
    "[Normal(), Gamma(2.0, 1.0)]"
  )
  expect_error(.render(list(a = 1)), "Named lists")
  expect_error(.render(numeric()), "empty")
  expect_error(.render(sum), "Cannot render")
})

test_that("specs render positional and keyword arguments", {
  expect_identical(as_julia(julia_spec("F", 1, a = 2L)), "F(1.0; a = 2)")
  expect_identical(as_julia(julia_spec("F")), "F()")
  expect_identical(
    as_julia(julia_spec("F", b = NULL, c = 3)), "F(; c = 3.0)"
  )
  expect_identical(
    as_julia(julia_spec("F", julia_spec("G"), h = julia_spec("H"))),
    "F(G(); h = H())"
  )
  # The first formal is `.fn`, so a Julia keyword named `f` or `fn` reaches
  # the call rather than being taken for the constructor name.
  expect_identical(as_julia(julia_spec("F", f = "Bar")), "F(; f = \"Bar\")")
  expect_identical(as_julia(julia_spec("F", fn = 2L)), "F(; fn = 2)")
})

test_that("arguments Julia could not read are refused", {
  expect_error(julia_spec("bad name"), "name of a Julia constructor")
  # A dot qualifies a name by its module; it does not start or end one, where
  # Julia would read a broadcast call
  expect_identical(as_julia(julia_spec("MyModule.build")), "MyModule.build()")
  expect_error(julia_spec("F."), "name of a Julia constructor")
  # A trailing newline would render two Julia expressions, and a role ending
  # in one would be a class nothing could assert
  expect_error(julia_spec("F\n"), "name of a Julia constructor")
  expect_error(julia_spec("F", `a\n` = 1), "out of")
  expect_error(julia_spec("F", .role = "prior\n"), "such as .prior.")
  expect_error(julia_spec(".F"), "name of a Julia constructor")
  # A constructor name may use letters from any script, as a keyword may, and
  # Julia decides what counts as one: `\u2207loss` and `x\u2032` are names
  # `Base.isidentifier()` accepts
  expect_identical(as_julia(julia_spec("\u0394", 1)), "\u0394(1.0)")
  expect_identical(as_julia(julia_spec("\u2207loss")), "\u2207loss()")
  prime <- list(1L)
  names(prime) <- "x\u2032"
  expect_identical(
    as_julia(do.call(julia_spec, c("F", prime))), "F(; x\u2032 = 1)"
  )
  # A parameter list comes through, with the comma and space it needs
  expect_identical(
    as_julia(julia_spec("Vector{Float64}", 0, 0)), "Vector{Float64}(0.0, 0.0)"
  )
  expect_identical(
    as_julia(julia_spec("Array{Vector{Float64}, 2}")),
    "Array{Vector{Float64}, 2}()"
  )
  # A `{}` holds expressions Julia evaluates, so what would break out of the
  # call is refused there too
  expect_error(julia_spec("F{(); run_me()}"), "name of a Julia constructor")
  expect_error(julia_spec("F(1); run_me()"), "name of a Julia constructor")
  expect_error(julia_spec("F,G"), "name of a Julia constructor")
  # One case per character that would take the name out of the call, since
  # that set is the whole barrier and a slip in it would be invisible
  breaks_call <- c(
    "F(", "F)", "F\"q", "F'q", "F`q", "F#q", "F$q", "F=q", "F;q", "F\\q"
  )
  for (name in breaks_call) {
    expect_error(julia_spec(name), "name of a Julia constructor", info = name)
    expect_error(
      do.call(julia_spec, c("G", stats::setNames(list(1), name))),
      "out of the call", info = name
    )
  }
  expect_error(julia_spec(1), "name of a Julia constructor")
  expect_error(julia_spec("F", 1, NULL, 3), "positional argument")
  expect_error(julia_spec("F", `a b` = 1), "out of")
  repeated <- list(1, 2)
  names(repeated) <- c("a", "a")
  expect_error(do.call(julia_spec, c("F", repeated)), "must be distinct")
  # A `NULL` among them is still a repeat: dropping either value discards
  # something the caller wrote, so neither reading is safe to pick
  overridden <- list(1e-8, NULL)
  names(overridden) <- c("tol", "tol")
  expect_error(
    do.call(julia_spec, c("Solver", overridden)), "no reading of the call"
  )
  expect_error(julia_spec("F", .role = "not a role"), "such as .prior.")
  expect_error(julia_spec("F", .role = "code"), "juliabridge uses")
  expect_error(julia_spec("F", .role = "spec"), "juliabridge uses")
  expect_error(julia("F()", .role = "code"), "juliabridge uses")
  # A role may use letters from any script, as a class name may
  expect_s3_class(julia_spec("F", .role = "mod\u00e8le"), "julia_mod\u00e8le")
  expect_error(julia(""), "non-empty")
})

test_that("a separator does not push an argument past the width", {
  # An argument lands exactly on the width here, and then gains a `,` from
  # the join, so the budget has to leave room for it
  inner <- julia_spec("G", strrep("y", 62))
  lines <- format(julia_spec("F", aaaa = inner, b = 1))
  expect_true(all(nchar(lines) <= 78))
  expect_identical(
    as_julia(julia_spec("F", aaaa = inner, b = 1)),
    paste0("F(; aaaa = G(\"", strrep("y", 62), "\"), b = 1.0)")
  )
})

test_that("a Julia keyword named role or fn reaches the constructor", {
  spec <- julia_spec("F", role = "sink", fn = "exp", .role = "prior")
  expect_identical(as_julia(spec), "F(; role = \"sink\", fn = \"exp\")")
  expect_s3_class(spec, "julia_prior")
})

test_that("non-ASCII keyword names are escaped only in ASCII mode", {
  eps <- list(1)
  names(eps) <- "\u03f5_t"
  comp <- do.call(julia_spec, c("Process", eps))
  expect_identical(as_julia(comp), "Process(; \u03f5_t = 1.0)")
  expect_identical(
    as_julia(comp, ascii = TRUE),
    "Process(; (Symbol(\"\\u03f5_t\") => 1.0,)...)"
  )
})

test_that("julia() inserts code verbatim", {
  expect_identical(as_julia(julia("exp")), "exp")
  expect_identical(
    as_julia(julia_spec("F", transformation = julia("identity"))),
    "F(; transformation = identity)"
  )
})

test_that("roles are the caller's own vocabulary", {
  prior <- julia_spec("Normal", 0, 1, .role = "prior")
  expect_s3_class(prior, "julia_prior")
  expect_s3_class(prior, "julia_spec")
  expect_invisible(assert_role(prior, "prior"))
  expect_invisible(assert_role(prior, c("model", "prior")))
  expect_invisible(assert_role(NULL, "prior", null_ok = TRUE))
  expect_error(assert_role(prior, "model"), "must be a model spec")
  expect_error(assert_role(prior, "observation"), "must be an observation")
  expect_error(
    assert_role(prior, "model", labels = c(model = "a fitted model")),
    "must be a fitted model"
  )
  expect_error(assert_role(prior, "model", arg_name = "x"), "`x` must be")
})

test_that("an untyped julia() expression satisfies any role", {
  expect_invisible(assert_role(julia("anything()"), "model"))
  expect_error(assert_role(julia("Normal()", .role = "prior"), "model"))
})

test_that("printing breaks a long spec over lines", {
  nested <- julia_spec(
    "Mixture",
    weights = julia_spec("Dirichlet", list(1, 1)),
    parts = list(
      julia_spec("Normal", 0, 1),
      julia_spec("Gamma", 6.5, 0.62)
    ),
    .role = "model"
  )
  lines <- .format_code(nested)
  expect_gt(length(lines), 1)
  expect_true(all(nchar(lines) <= 78))
  # The separators are what make the broken-up form valid Julia: dropping
  # them still gives lines that fit and a plausible header.
  expect_identical(
    gsub("[[:space:]]", "", paste(lines, collapse = "")),
    gsub("[[:space:]]", "", as_julia(nested))
  )
  expect_identical(format(nested), lines)
  expect_output(print(nested), "<julia model spec>")
  expect_output(print(julia("exp")), "<julia code>")
  expect_output(print(julia_spec("Normal")), "Normal\\(\\)")
})

test_that("a class of the caller's own renders through as_julia_value()", {
  # Registered as a consuming package would register it: the generic is
  # called from inside this package, so dispatch reads the methods table
  # rather than the caller's environment. The classes exist only here.
  registerS3method(
    "as_julia_value", "my_normal",
    function(x, ...) julia_spec("Normal", x$mean, x$sd)
  )
  registerS3method(
    "as_julia_value", "my_scalar",
    function(x, ...) julia_spec("Dirac", unclass(x))
  )

  # Such a class is usually a list or a vector underneath, which would
  # otherwise be rendered as one.
  spec <- structure(list(mean = 0, sd = 1), class = "my_normal")
  expect_identical(as_julia(julia_spec("F", spec)), "F(Normal(0.0, 1.0))")
  expect_identical(as_julia(spec), "Normal(0.0, 1.0)")
  expect_identical(
    as_julia(julia_spec("F", structure(3.5, class = "my_scalar"))),
    "F(Dirac(3.5))"
  )
})

test_that("a class with no method says what is missing", {
  expect_error(as_julia(julia_spec("F", factor("a"))), "as_julia_value")
  expect_error(as_julia(julia_spec("F", sum)), "class 'function'")
})

test_that("a spec with no role is accepted wherever one is expected", {
  untyped <- julia_spec("Normal", 0, 1)
  expect_s3_class(untyped, "julia_spec", exact = TRUE)
  expect_invisible(assert_role(untyped, "prior"))
  expect_invisible(assert_role(untyped, c("prior", "model")))
  expect_output(print(untyped), "<julia spec>")
  # A role, once given, is still checked
  expect_error(
    assert_role(julia_spec("Normal", 0, 1, .role = "prior"), "model"),
    "must be a model spec"
  )
})

test_that("a broken-up print agrees with the rendered code", {
  registerS3method(
    "as_julia_value", "long_spec",
    function(x, ...) {
      julia_spec(
        "AVeryLongConstructorNameIndeedTrulyEnormousAndThenSomeMore",
        x$a, x$b, x$c, x$d, x$e
      )
    }
  )
  spec <- structure(
    list(a = 1, b = 2, c = 3, d = 4, e = 5), class = "long_spec"
  )
  wrapped <- julia_spec("F", spec)
  # Long enough to be broken over lines, which is where reading the structure
  # underneath the class, rather than asking it, would show through.
  expect_gt(nchar(as_julia(wrapped)), 78)
  lines <- .format_code(wrapped)
  expect_gt(length(lines), 1)
  expect_true(any(grepl("AVeryLongConstructorName", lines, fixed = TRUE)))
  expect_false(any(grepl("^\\s*\\[", lines)))
})

test_that("a matrix keeps its shape", {
  # A non-square case: reversing the dimensions, the natural row-major
  # mistake, would hand Julia a transposed matrix and pass a square test.
  expect_identical(
    .render(matrix(1:6, nrow = 2)), "reshape([1, 2, 3, 4, 5, 6], (2, 3))"
  )
  expect_identical(.render(matrix(2.5, 1, 1)), "reshape([2.5], (1, 1))")
  expect_identical(
    .render(matrix(c("a", "b", "c", "d"), 2)),
    "reshape([\"a\", \"b\", \"c\", \"d\"], (2, 2))"
  )
  expect_identical(
    as_julia(julia_spec("F", m = matrix(1:4, 2))),
    "F(; m = reshape([1, 2, 3, 4], (2, 2)))"
  )
  expect_error(
    .render(matrix(1:4, 2, 2, dimnames = list(c("a", "b"), c("x", "y")))),
    "Named vectors and arrays"
  )
  expect_error(
    .render(matrix(1:4, 2, 2, dimnames = list(c("a", "b"), NULL))),
    "Named vectors and arrays"
  )
  # An all-NULL dimnames carries no names: this is what stripping them leaves
  labelled <- matrix(1:4, 2, 2, dimnames = list(c("a", "b"), c("x", "y")))
  rownames(labelled) <- NULL
  colnames(labelled) <- NULL
  expect_identical(.render(labelled), "reshape([1, 2, 3, 4], (2, 2))")
  # R and Julia both store column-major, so the elements travel as they are
  # and reshape restores the shape. Julia reads this back as a Matrix.
  expect_identical(
    .render(matrix(1:4, nrow = 2)), "reshape([1, 2, 3, 4], (2, 2))"
  )
  expect_identical(
    .render(array(1:8, c(2, 2, 2))),
    "reshape([1, 2, 3, 4, 5, 6, 7, 8], (2, 2, 2))"
  )
  expect_identical(.render(c(1, 2)), "[1.0, 2.0]")
})

test_that("names that Julia would drop are refused rather than dropped", {
  expect_error(.render(c(alpha = 1, beta = 2)), "Named vectors")
  expect_error(.render(list(alpha = 1)), "Named lists")
  expect_error(.render(list()), "empty")
  expect_error(.render(numeric()), "empty")
})
