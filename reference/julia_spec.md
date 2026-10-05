# Describe a Julia constructor call

Records a call to a Julia constructor as an R object, rendered to Julia
source only when it is run. A package wrapping a Julia library builds
its own constructors on top of this, and exposes it directly so that
users can reach anything it has not wrapped.

## Usage

``` r
julia_spec(.fn, ..., .role = NULL)
```

## Arguments

- .fn:

  Character string. Name of the Julia constructor, which may be
  qualified by its module and may hold a parameter list, as in
  `"Vector{Float64}"`. A parameter list may not hold a parenthesis or a
  quote, so a name such as `"NamedTuple{(:a, :b), Tuple{Int, Int}}"` has
  to be written with
  [`julia()`](https://epiforecasts.io/juliabridge/reference/julia.md).
  It is spelled with a dot so that a Julia keyword named `f` or `fn`
  still reaches `...` rather than being taken for this argument.

- ...:

  Arguments to the constructor. Unnamed arguments are positional and
  named arguments become keyword arguments. A keyword name is refused if
  it begins with a digit, holds a space or comma, holds a character that
  would take it out of the call, or repeats another; beyond that, which
  names Julia accepts is left to Julia, and a name may hold non-ASCII
  characters. Every keyword name is checked, including one whose value
  is `NULL` and so is dropped.

- .role:

  Optional character string naming what the spec is, in whatever
  vocabulary the calling package uses (for example `"prior"` or
  `"model"`). It becomes a class, so
  [`assert_role()`](https://epiforecasts.io/juliabridge/reference/assert_role.md)
  can check that specs are composed sensibly. `NULL` leaves the spec
  untyped, which every role accepts. It is spelled with a dot for the
  same reason as `.fn`, so that a Julia keyword named `role` reaches
  `...`.

## Value

An object of class `julia_spec`, holding the constructor name in `$fn`,
the positional arguments in `$args` and the keyword arguments in
`$kwargs`. A package may read those to inspect or rewrite a call.

## Details

Arguments are rendered to Julia as follows: specs and
[`julia()`](https://epiforecasts.io/juliabridge/reference/julia.md)
expressions are inserted as code, numeric vectors of length one become
scalars and longer ones become vectors, unnamed lists become vectors,
`NA` becomes `missing`, and character strings become Julia strings.
Integers (e.g. `2L`) render as Julia integers and doubles as floats. A
`NULL` keyword argument is dropped, so the Julia default applies; a
`NULL` positional argument is an error, since dropping it would renumber
the arguments that follow. A matrix or array keeps its shape, arriving
in Julia as a `Matrix` or `Array` of the same dimensions. A named
vector, a named list and an empty value are all refused, since Julia
would read them as something the R value did not say.

## Examples

``` r
# Any Julia constructor, by name. R types map across: `10L` is a Julia
# integer, `1e-8` a float and `"BFGS"` a Julia string.
julia_spec("Solver", 10L, tol = 1e-8, method = "BFGS")
#> <julia spec>
#> Solver(10; tol = 1e-08, method = "BFGS")

# A name may be qualified by its module, and a spec may nest in another
julia_spec("MyModule.Problem", julia_spec("Solver", 10L), verbose = TRUE)
#> <julia spec>
#> MyModule.Problem(Solver(10); verbose = true)

# A matrix keeps its shape, reaching Julia as a Matrix
as_julia(julia_spec("Weights", matrix(1:4, nrow = 2)))
#> [1] "Weights(reshape([1, 2, 3, 4], (2, 2)))"

# A role lets the calling package check how specs are composed
julia_spec("Normal", 0, 1, .role = "prior")
#> <julia prior spec>
#> Normal(0.0, 1.0)
```
