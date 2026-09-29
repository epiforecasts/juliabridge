# Load Julia bridge (.jl) files from a package's `inst/julia/` directory

Reads each file as a string and evaluates it via
[`JuliaConnectoR::juliaEval()`](https://rdrr.io/pkg/JuliaConnectoR/man/juliaEval.html)
in the running Julia server. Bridge files typically define helper
functions used by the wrapping R package; loading them once after
package setup makes them available to subsequent `juliaCall()`
invocations.

## Usage

``` r
julia_load_bridge(package, files, verbose = FALSE)
```

## Arguments

- package:

  Name of the calling R package (used as the `package` argument to
  [`system.file()`](https://rdrr.io/r/base/system.file.html)). Files are
  looked up under `inst/julia/` of that package.

- files:

  Character vector of `.jl` filenames (no directory).

- verbose:

  If `TRUE`, print a message per loaded file.

## Value

Invisibly the character vector of paths that were loaded.

## Examples

``` r
if (FALSE) { # \dontrun{
julia_load_bridge("ringbpjl",
  c("dist_lookup.jl", "simulate.jl", "generation_time.jl"))
} # }
```
