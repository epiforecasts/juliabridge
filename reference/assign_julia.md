# Assign an R value to a name in Julia's `Main` module

Equivalent in spirit to `JuliaCall::julia_assign(name, value)`. Useful
when porting code that previously used the assign-then-eval pattern.
Idiomatic JuliaConnectoR code prefers passing values directly via
[`call_julia()`](https://sbfnk.github.io/juliaready/reference/call_julia.md);
this is provided for migration convenience.

## Usage

``` r
assign_julia(name, value)
```

## Arguments

- name:

  Variable name to bind in `Main`.

- value:

  R value to convert and assign.

## Value

Invisibly `NULL`.

## Details

Internally defines a small Julia helper `__juliaready_assign__!` on
first use and calls it with the (Symbol, value) pair.
