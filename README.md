# juliaready

<!-- badges: start -->
[![R-CMD-check](https://github.com/sbfnk/juliaready/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/sbfnk/juliaready/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/sbfnk/juliaready/graph/badge.svg)](https://app.codecov.io/gh/sbfnk/juliaready)
<!-- badges: end -->

Robust Julia setup for R packages that wrap a Julia engine.

`juliaready` captures the patterns you have to learn the hard way when building an R package that calls Julia: which Julia binary to use when several are installed, how to install Julia packages cleanly without leaving the depot in an unstable state, how to load `.jl` bridge files reliably, and how to manage lazy initialisation. It is small, opinionated, and meant to replace ~100 lines of brittle boilerplate per consuming package with ~5.

Internally it uses [JuliaConnectoR](https://github.com/stefan-m-lenz/JuliaConnectoR) — keeping Julia in a separate process from R — rather than [JuliaCall](https://github.com/JuliaInterop/JuliaCall) which embeds Julia in the R process. Consumer packages call `juliaready::eval_julia()` / `call_julia()` / `import_julia()` rather than the underlying library directly, so the choice of backend is encapsulated.

## Why JuliaConnectoR and not JuliaCall

Both work for the simple case. JuliaConnectoR is the better default because:

- **No shared-process segfaults.** With JuliaCall, R and Julia share memory, threads, signal handlers, and the dynamic linker. Any one of them being unhappy crashes both. We have observed segfaults from `LD_LIBRARY_PATH` poisoning of subprocess Julia, from `Pkg.activate(<path>)` followed by `Pkg.instantiate()` from in-process JuliaCall, from accessing fields of NamedTuple results via `julia_eval`, and so on. JuliaConnectoR puts Julia in a separate process; a Julia segfault closes a TCP socket and R survives.
- **Smaller list of rules.** The list of "things you must not do" is much shorter with out-of-process Julia. Less to remember, less to break.
- **Crash containment.** A bad simulation crash is recoverable rather than fatal.

JuliaCall has a larger ecosystem and more frequent commits, but most of the activity is platform-compatibility work; the hard interaction (in-process linking) cannot be fixed without changing the architecture.

## Installation

```r
# install.packages("remotes")
remotes::install_github("sbfnk/juliaready")
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

- **`julia_bin()`** — resolve the Julia binary, honouring `JULIACONNECTOR_JULIABIN`, `JULIA_BINDIR`, then `PATH`.
- **`julia_ready(packages, github, state_env, install, project, verbose)`** — install required Julia packages in a subprocess, then start the JuliaConnectoR server and `using` them. With `project = "<path>"`, activates and instantiates a pinned Julia project (e.g. `inst/julia/Project.toml`) instead of installing into the user's default depot — recommended for shipping reproducible installs. Idempotent.
- **`julia_load_bridge(package, files, verbose)`** — load `.jl` files from `inst/julia/<package>` of a calling package via `juliaEval`.
- **`ensure_julia(state_env, init_fn)`** — lazy-init guard. Call from the top of any function that will use Julia.
- **`eval_julia(code)`** / **`call_julia(name, ...)`** / **`import_julia(module)`** — backend-agnostic wrappers around `juliaEval` / `juliaCall` / `juliaImport`.

## What this package deliberately does *not* do

- It does not pin a specific Julia version. If your package needs that, install via [juliaup](https://github.com/JuliaLang/juliaup) and set `JULIACONNECTOR_JULIABIN`, or wrap `julia_ready()` with a version check.
- It does not auto-initialise on `.onLoad`. Eager init in `.onLoad` interacts badly with other compiled backends (notably Stan) and can crash R during package attach. Use `ensure_julia()` instead.
- It does not provide a Julia REPL. That is `JuliaConnectoR`'s job.

## Status

Used in [ringbpjl](https://github.com/sbfnk/ringbp.jl); migrations of [forecastbaselines](https://github.com/epiforecasts/forecastbaselines), [EpiAwareR](https://github.com/sbfnk/EpiAwareR), and [epinow2julia](https://github.com/epiforecasts/epinow2julia) are in flight.

## License

MIT
