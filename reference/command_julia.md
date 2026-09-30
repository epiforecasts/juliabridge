# Run a Julia command for its side effects

Equivalent in spirit to `JuliaCall::julia_command(code)`: evaluate Julia
code without using the return value. Provided for migration convenience;
functionally identical to
[`eval_julia()`](https://epiforecasts.io/juliabridge/reference/eval_julia.md)
called for its side effects.

## Usage

``` r
command_julia(code)
```

## Arguments

- code:

  A string of Julia code.

## Value

Invisibly the result of `juliaEval`.
