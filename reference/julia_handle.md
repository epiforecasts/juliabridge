# Hold a Julia object from R

Some Julia results are too big, or too Julia-shaped, to convert: an MCMC
chain a later call will sample from, a simulation state later
summarised. The Julia side keeps such an object in a registry and
returns an integer handle. R holds the handle in an environment whose
finaliser queues it for release once nothing refers to it.

## Usage

``` r
julia_handle(handle, session, state_env)
```

## Arguments

- handle:

  Integer handle returned by the Julia side.

- session:

  Token identifying the Julia session that made it.

- state_env:

  The environment given to
  [`julia_ready()`](https://epiforecasts.io/juliabridge/reference/julia_ready.md).

## Value

An environment holding `handle`, `session` and the owning `state_env`.

## Details

These functions deal with two hazards of that arrangement.

Handles are numbered per session. After a restart, an old handle names
whatever object the new session gave that number. Each handle is
therefore paired with a token for the session that made it. Both sides
compare tokens before acting.

Saving an R object copies the environment by value but not its
finaliser. A reloaded object then points at a Julia object it does not
own.
[`julia_handle_owned()`](https://epiforecasts.io/juliabridge/reference/julia_handle_owned.md)
detects this by comparing the state environment recorded in the handle
with the current one.

A consumer package defines three things on the Julia side, in its own
module where they precompile:

    const HANDLES = Dict{Int, Any}()
    const NEXT_HANDLE = Ref(0)
    const SESSION = Ref("")

    function __init__()
        SESSION[] = string(rand(Random.RandomDevice(), UInt128); base = 16)
        return nothing
    end

    function keep!(x)
        NEXT_HANDLE[] += 1
        HANDLES[NEXT_HANDLE[]] = x
        return NEXT_HANDLE[]
    end

    function release!(handle::Integer, session::AbstractString)
        session == SESSION[] && delete!(HANDLES, Int(handle))
        return nothing
    end

A function returning a handle also returns `SESSION[]`. A function
acting on a handle takes that token too and refuses a mismatch.

## Examples

``` r
if (FALSE) { # \dontrun{
result <- call_julia("MyBridge.fit", data)
fit <- list(
  draws = result$draws,
  julia = julia_handle(result$handle, result$session, .my_pkg_env)
)
} # }
```
