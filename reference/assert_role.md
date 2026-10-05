# Check that an argument is a spec of an accepted role

Composition errors are worth catching in R, where the argument can be
named, rather than in Julia, where the error arrives from inside a
constructor. A
[`julia()`](https://epiforecasts.io/juliabridge/reference/julia.md)
expression with no role is accepted for any role, since the caller has
said what it is by writing the code.

## Usage

``` r
assert_role(
  x,
  roles,
  null_ok = FALSE,
  arg_name = deparse(substitute(x)),
  labels = NULL
)
```

## Arguments

- x:

  Object to check.

- roles:

  Character vector of accepted roles.

- null_ok:

  Logical. Whether `NULL` is accepted.

- arg_name:

  Name used in error messages.

- labels:

  Optional named character vector describing each role, used in the
  error message, for instance `c(prior = "a prior (e.g. `Normal()`)")`.
  Roles without an entry are described by their own name.

## Value

Invisibly `TRUE`.

## Examples

``` r
transform <- julia_spec("LogTransform", .role = "transform")
assert_role(transform, "transform")
try(assert_role(transform, "model"))
#> Error : `transform` must be a model spec.
```
