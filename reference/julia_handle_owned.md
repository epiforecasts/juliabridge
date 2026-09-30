# Does this R session own the Julia object behind a handle?

Returns `FALSE` for a handle that arrived by saving and reloading, whose
Julia object belongs to the session that created it. It also returns
`FALSE` for a handle created before
[`julia_ready()`](https://epiforecasts.io/juliabridge/reference/julia_ready.md)
last set Julia up, whose object went with the old Julia server. Callers
use this to tell the user the object came from disk or an earlier
session.

## Usage

``` r
julia_handle_owned(x, state_env)
```

## Arguments

- x:

  A handle from
  [`julia_handle()`](https://epiforecasts.io/juliabridge/reference/julia_handle.md).

- state_env:

  The environment given to
  [`julia_ready()`](https://epiforecasts.io/juliabridge/reference/julia_ready.md).

## Value

`TRUE` when the current setup of `state_env` created the handle.

## Examples

``` r
if (FALSE) { # \dontrun{
if (!julia_handle_owned(fit$julia, .my_pkg_env)) {
  stop("This fit was loaded from disk; refit it to continue.")
}
} # }
```
