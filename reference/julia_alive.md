# Is the Julia session still usable?

[`julia_ready()`](https://epiforecasts.io/juliaready/reference/julia_ready.md)
records that setup has run and returns immediately when called again.
That leaves a session stuck once its Julia process goes away, whether it
was stopped, interrupted or died: the packages are no longer loaded,
while the flag still says they are.

## Usage

``` r
julia_alive(state_env, probe = NULL)
```

## Arguments

- state_env:

  The environment given to
  [`julia_ready()`](https://epiforecasts.io/juliaready/reference/julia_ready.md).

- probe:

  Julia code returning a `Bool`, evaluated to decide whether the session
  still holds what the caller needs. The default checks that this is the
  server `state_env` was set up in. A caller can ask for something more
  specific, e.g. `"isdefined(Main, :MyBridge)"`.

## Value

`TRUE` when the session is usable, otherwise `FALSE`.

## Details

This checks the running session and clears the flag when the check
fails. The next
[`julia_ready()`](https://epiforecasts.io/juliaready/reference/julia_ready.md)
call then sets Julia up again. The environment itself is kept, because
callers may use its identity.

The check itself may start Julia, because JuliaConnectoR starts a new
server whenever its connection has gone. The default probe is `FALSE` in
such a server: only the server
[`julia_ready()`](https://epiforecasts.io/juliaready/reference/julia_ready.md)
ran in holds the token it recorded.

## Examples

``` r
if (FALSE) { # \dontrun{
if (!julia_alive(.my_pkg_env, "isdefined(Main, :MyBridge)")) {
  setup_my_pkg()
}
} # }
```
