# Render a spec as Julia code

Render a spec as Julia code

## Usage

``` r
as_julia(x, ascii = FALSE)
```

## Arguments

- x:

  A spec from
  [`julia_spec()`](https://epiforecasts.io/juliabridge/reference/julia_spec.md)
  or
  [`julia()`](https://epiforecasts.io/juliabridge/reference/julia.md).

- ascii:

  Logical. If `TRUE`, keyword names with non-ASCII characters are
  written with Unicode escapes, as string literals always are. The
  constructor name is inserted verbatim, as code supplied through
  [`julia()`](https://epiforecasts.io/juliabridge/reference/julia.md)
  is, since Julia has no escape for an identifier in call position. The
  default gives the more readable form that can be pasted into Julia.

## Value

A character string of Julia code that constructs the spec.

## Examples

``` r
as_julia(julia_spec("Solver", 10L, tol = 1e-8))
#> [1] "Solver(10; tol = 1e-08)"

# A keyword name outside ASCII travels as an escape
greek <- list(1)
names(greek) <- "\u03f5_t"
as_julia(do.call(julia_spec, c("Process", greek)), ascii = TRUE)
#> [1] "Process(; (Symbol(\"\\u03f5_t\") => 1.0,)...)"
```
