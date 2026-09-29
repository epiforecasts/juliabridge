# Call a Julia function by (qualified) name

The function name may be module-qualified (e.g. `"Distributions.mean"`).
Module qualification is recommended after `using` so that constructor
names resolve unambiguously.

## Usage

``` r
call_julia(name, ...)
```

## Arguments

- name:

  Function name, optionally module-qualified.

- ...:

  Arguments passed to the Julia function.

## Value

The Julia function's return value, converted to R where reasonable.
