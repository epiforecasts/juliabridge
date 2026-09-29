# juliaready

<!-- badges: start -->
[![R-CMD-check](https://github.com/epiforecasts/juliaready/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/epiforecasts/juliaready/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/epiforecasts/juliaready/graph/badge.svg)](https://app.codecov.io/gh/epiforecasts/juliaready)
<!-- badges: end -->

Julia setup for R packages that wrap a Julia engine.

`juliaready` collects the patterns you otherwise learn the hard way when building an R package that calls Julia: which Julia binary to use when several are installed, how to install Julia packages without leaving the depot in an unstable state, how to load `.jl` bridge files reliably, and how to manage lazy initialisation. It is small and opinionated, and it replaces about 100 lines of brittle boilerplate per consuming package with about 5.

Internally it uses [JuliaConnectoR](https://github.com/stefan-m-lenz/JuliaConnectoR), which runs Julia in a separate process. The main alternative, [JuliaCall](https://github.com/JuliaInterop/JuliaCall), embeds Julia in the R process. Consumer packages call `juliaready::eval_julia()`, `call_julia()` and `import_julia()` and never touch the backend directly, which keeps the choice of backend in one place.

## Why JuliaConnectoR and not JuliaCall

Both work for the simple case. JuliaConnectoR is the better default because it keeps Julia out of R's process. With JuliaCall, R and Julia share memory, threads, signal handlers and the dynamic linker, and a problem in any of them crashes both. We have seen segfaults from `LD_LIBRARY_PATH` poisoning of subprocess Julia, from `Pkg.activate(<path>)` followed by `Pkg.instantiate()` in in-process JuliaCall, and from accessing fields of NamedTuple results via `julia_eval`. With JuliaConnectoR, a Julia segfault closes a TCP socket, R survives, and a crashed simulation can be recovered. The list of things you must not do is also much shorter with out-of-process Julia.

JuliaCall has a larger ecosystem and more frequent commits, but most of that activity is platform-compatibility work. The in-process linking problems cannot be fixed without changing its architecture.

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
- `julia_ready(packages, github, state_env, install, project, verbose)` installs the required Julia packages in a subprocess, then starts the JuliaConnectoR server and loads them with `using`. With `project = "<path>"`, it activates and instantiates a pinned Julia project (e.g. `inst/julia/Project.toml`) instead of installing packages into the user's default Julia environment. We recommend this for reproducible installs. Once setup has completed, later calls return immediately.
- `julia_load_bridge(package, files, verbose)` loads `.jl` files from `inst/julia/` of the calling package via `juliaEval`.
- `ensure_julia(state_env, init_fn)` is a lazy-initialisation guard. Call it at the top of any function that uses Julia.
- `eval_julia(code)`, `call_julia(name, ...)` and `import_julia(module)` wrap `juliaEval`, `juliaCall` and `juliaImport`, and `get_julia()`, `assign_julia()` and `command_julia()` cover the remaining common operations.

## Out of scope

- Pinning a Julia version. If your package needs one, install it via [juliaup](https://github.com/JuliaLang/juliaup) and set `JULIACONNECTOR_JULIABIN`, or wrap `julia_ready()` with a version check.
- Initialising in `.onLoad`. Eager initialisation there interacts badly with other compiled backends (notably Stan) and can crash R while the package attaches. Use `ensure_julia()`.
- A Julia REPL, which is left to JuliaConnectoR.

## Status

Used in [ringbpjl](https://github.com/sbfnk/ringbp.jl); migrations of [forecastbaselines](https://github.com/epiforecasts/forecastbaselines), [EpiAwareR](https://github.com/sbfnk/EpiAwareR), and [epinow2julia](https://github.com/epiforecasts/epinow2julia) are in flight.

## License

MIT
