# Call a Julia function by (qualified) name

The function name may be module-qualified (e.g. `"Distributions.mean"`).
Qualifying the name after `using` makes constructor names resolve
unambiguously.

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
