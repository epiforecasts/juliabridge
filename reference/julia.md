# Embed Julia code in a spec

Marks a string as Julia source to be inserted verbatim when a spec is
rendered, for arguments that cannot be expressed in R, such as functions
or objects from other Julia packages.

## Usage

``` r
julia(code, .role = NULL)
```

## Arguments

- code:

  Character string of Julia code.

- .role:

  Optional role (see
  [`julia_spec()`](https://epiforecasts.io/juliabridge/reference/julia_spec.md)).
  Without one the expression is accepted wherever a spec is expected.

## Value

An object of class `julia_code`, which is also a `julia_spec` and holds
the code in `$code`. It has no `$fn`, `$args` or `$kwargs`, so a package
walking a call branches on `inherits(x, "julia_code")` first.

## Examples

``` r
# A Julia function, which has no R equivalent to render
julia_spec("Sampler", transform = julia("identity"))
#> <julia spec>
#> Sampler(; transform = identity)
```
