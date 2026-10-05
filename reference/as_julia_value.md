# Render a value of a class this package does not know

The extension point for a calling package with its own way of describing
a value, such as a distribution object. Write a method returning either
a spec from
[`julia_spec()`](https://epiforecasts.io/juliabridge/reference/julia_spec.md)
or a plain R value, and it renders wherever the value appears.

## Usage

``` r
as_julia_value(x, ...)
```

## Arguments

- x:

  The value to render.

- ...:

  Passed to methods.

## Value

A spec or an R value that renders on its own.

## Examples

``` r
# A package with a value class of its own renders it like this:
as_julia_value.my_interval <- function(x, ...) {
  julia_spec("Interval", x$lower, x$upper)
}
```
