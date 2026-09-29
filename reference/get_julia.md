# Fully translate a Julia value into R

[`eval_julia()`](https://sbfnk.github.io/juliaready/reference/eval_julia.md)
and
[`call_julia()`](https://sbfnk.github.io/juliaready/reference/call_julia.md)
return composite Julia values (structs, Tuples, NamedTuples, Dicts) as
proxy objects that reference the value inside the Julia session. This
function translates such a proxy into a plain R object, e.g. a
NamedTuple into a named list. Values that are already plain R objects
pass through unchanged.

## Usage

``` r
get_julia(x)
```

## Arguments

- x:

  A Julia proxy object (or an already-translated R value).

## Value

The value fully translated into R data structures.
