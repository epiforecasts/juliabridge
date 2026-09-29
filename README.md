# juliaready

<!-- badges: start -->
[![R-CMD-check](https://github.com/epiforecasts/juliaready/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/epiforecasts/juliaready/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/epiforecasts/juliaready/graph/badge.svg)](https://app.codecov.io/gh/epiforecasts/juliaready)
<!-- badges: end -->

Julia setup for R packages that wrap a Julia engine.

`juliaready` collects the patterns you otherwise learn the hard way when building an R package that calls Julia:

- which Julia binary to use when several are installed, and which Julia version a pinned project needs;
- how to install Julia packages without leaving the depot in an unstable state;
- how to load `.jl` bridge files reliably;
- how to manage lazy initialisation, and how to recover when the Julia process goes away;
- how to keep a Julia object alive from R and release it safely.

It is small and opinionated, and it replaces about 100 lines of brittle boilerplate per consuming package with about 5.

## Backend

juliaready runs Julia through [JuliaConnectoR](https://github.com/stefan-m-lenz/JuliaConnectoR), in a separate process from R. The main alternative, [JuliaCall](https://github.com/JuliaInterop/JuliaCall), embeds Julia in the R process. Both work for simple cases. With JuliaCall, though, R and Julia share memory, threads, signal handlers and the dynamic linker, and a problem in any of them crashes both. We have seen segfaults from `LD_LIBRARY_PATH` poisoning of subprocess Julia, from `Pkg.activate(<path>)` followed by `Pkg.instantiate()` in in-process JuliaCall, and from accessing fields of NamedTuple results via `julia_eval`. With JuliaConnectoR, a Julia segfault closes a TCP socket, R survives, and a crashed simulation can be recovered. Out-of-process Julia also leaves a much shorter list of things you must avoid.

JuliaCall has a larger ecosystem and more frequent commits, but most of that activity is platform-compatibility work. Its in-process linking problems cannot be fixed without changing its architecture.

Consumer packages call `juliaready::eval_julia()`, `call_julia()` and `import_julia()` and never touch JuliaConnectoR directly, which keeps the choice of backend in one place.

## Installation

```r
# install.packages("remotes")
remotes::install_github("epiforecasts/juliaready")
```

You also need [Julia](https://julialang.org/) installed; [juliaup](https://github.com/JuliaLang/juliaup) is recommended.

## Usage in a consuming R package

```r
# In your package's R/zzz.R (or similar):

.mypkg_env <- new.env(parent = emptyenv())

#' @export
setup_mypkg <- function(install = TRUE) {
  juliaready::julia_ready(
    packages  = c("EpiBranch", "Distributions", "Random"),
    github    = c(EpiBranch = "epiforecasts/EpiBranch.jl"),
    state_env = .mypkg_env,
    install   = install
  )
  juliaready::julia_load_bridge(
    package = "mypkg",
    files   = c("dist_lookup.jl", "simulate.jl")
  )
}

.ensure_julia <- function() {
  juliaready::ensure_julia(.mypkg_env, setup_mypkg)
}
```

Then in any function that touches Julia:

```r
my_function <- function(x) {
  .ensure_julia()
  juliaready::call_julia("MyJuliaPkg.do_something", x)
}
```

## API

- `julia_bin()` resolves the Julia binary, checking `JULIACONNECTOR_JULIABIN`, then `JULIA_BINDIR`, then `PATH`.
- `julia_ready(packages, github, state_env, install, project, match_manifest, verbose)` installs the required Julia packages in a subprocess, then starts the JuliaConnectoR server and loads them with `using`. Once setup has completed, later calls return immediately.
  - With `project = "<path>"`, it activates and instantiates a pinned Julia project (e.g. `inst/julia/Project.toml`) and sets `JULIA_PROJECT` for the R session. The user's default Julia environment is not modified, although packages are still downloaded into the shared Julia depot. We recommend this for reproducible installs.
  - With `match_manifest = TRUE` (the default), it also uses the Julia version the project's `Manifest.toml` was resolved with, installing it via juliaup where available. A manifest pins standard libraries that exist only on that version. A `JULIACONNECTOR_JULIABIN` set by the user takes precedence, and a JuliaConnectoR server that is already running, for instance one another package started, keeps its Julia.
- `julia_load_bridge(package, files, verbose)` loads `.jl` files from `inst/julia/` of the calling package via `juliaEval`.
- `ensure_julia(state_env, init_fn)` is a lazy-initialisation guard. Call it at the top of any function that uses Julia.
- `julia_alive(state_env, probe)` checks that the Julia session still holds what you need. If it does not, it clears the setup flag, and the next `julia_ready()` call sets Julia up again.
- `eval_julia(code)`, `call_julia(name, ...)` and `import_julia(module)` wrap `juliaEval`, `juliaCall` and `juliaImport`, and `get_julia()`, `assign_julia()` and `command_julia()` cover the remaining common operations.
- `manifest_julia_version(project)` reads the Julia version a `Manifest.toml` was resolved with. `juliaup_julia(version)` installs a Julia version with juliaup and returns its binary, leaving the user's default channel alone.
- `julia_handle(handle, session, state_env)` holds a Julia object from R by an integer handle, paired with a token for the Julia session that created it. Both sides compare the token before acting on a handle, which stops a handle from an old session naming an unrelated object in a new one. The help page lists the three definitions the Julia side needs.
- `julia_release_pending(state_env, release)` releases the Julia objects of handles R has garbage-collected. Finalisers can run partway through another Julia call, so they only queue a release; call this immediately before a Julia call of your own.
- `julia_handle_owned(x, state_env)` reports whether a handle's Julia object still belongs to this session. It returns `FALSE` for a handle loaded from a saved R object, and for one created before `julia_ready()` last set Julia up.

## Out of scope

- Initialising in `.onLoad`. Eager initialisation there interacts badly with other compiled backends (notably Stan) and can crash R while the package attaches. Use `ensure_julia()`.
- A Julia REPL, which is left to JuliaConnectoR.

## Status

Used in [ringbpjl](https://github.com/sbfnk/ringbp.jl); migrations of [forecastbaselines](https://github.com/epiforecasts/forecastbaselines), [EpiAwareR](https://github.com/sbfnk/EpiAwareR), and [epinow2julia](https://github.com/epiforecasts/epinow2julia) are in flight.

## License

MIT
