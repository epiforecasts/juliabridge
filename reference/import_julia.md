# Import a Julia module

Returns a list/environment-like object of the module's exported names,
callable as R functions. Equivalent to `juliaImport`.

## Usage

``` r
import_julia(module)
```

## Arguments

- module:

  Name of the Julia module, e.g. `"Distributions"`.

## Value

A `JuliaModuleImport` object.
