# Install a Julia version with juliaup and return its binary

The user's default channel stays as it is. The caller uses the returned
binary, typically through `JULIACONNECTOR_JULIABIN`.

## Usage

``` r
juliaup_julia(version, verbose = TRUE)
```

## Arguments

- version:

  Julia version to install, e.g. `"1.12"`.

- verbose:

  If `TRUE`, print progress messages.

## Value

Path to the Julia executable, or `NULL` when juliaup is absent or the
installation failed.

## Examples

``` r
if (FALSE) { # \dontrun{
juliaup_julia("1.12")
} # }
```
