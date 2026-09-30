# Release the Julia objects of collected handles

Because a finaliser can run partway through another Julia call, it only
adds the handle to a queue. This function flushes the queue. Call it
immediately before a Julia call of your own.

## Usage

``` r
julia_release_pending(state_env, release)
```

## Arguments

- state_env:

  The environment given to
  [`julia_ready()`](https://epiforecasts.io/juliaready/reference/julia_ready.md).

- release:

  Name of the Julia function releasing a handle, taking the handle and
  the session token.

## Value

Invisibly the number of handles released.

## Details

Only handles from the current setup of `state_env` are released. The
queue is dropped when `state_env` is not set up. Handles from an earlier
setup are dropped too, because their objects went with the old Julia
server. A release that fails stays queued for the next call, up to three
attempts, after which it is dropped: a release that keeps failing
usually means the server was replaced without
[`julia_alive()`](https://epiforecasts.io/juliaready/reference/julia_alive.md)
noticing.

## Examples

``` r
if (FALSE) { # \dontrun{
julia_release_pending(.my_pkg_env, "MyBridge.release!")
call_julia("MyBridge.forecast", handle, horizon)
} # }
```
