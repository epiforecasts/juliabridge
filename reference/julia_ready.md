# Ensure Julia and required Julia packages are ready

Performs the steps needed to make Julia and a set of Julia packages
callable from R via JuliaConnectoR:

## Usage

``` r
julia_ready(
  packages,
  github = character(),
  state_env = new.env(parent = emptyenv()),
  install = TRUE,
  project = NULL,
  verbose = TRUE
)
```

## Arguments

- packages:

  Character vector of Julia package names to ensure are loaded (e.g.
  `c("EpiBranch", "Distributions")`).

- github:

  Named character vector of GitHub URLs for packages not in the General
  registry. Names must match entries in `packages`. Values may be a full
  URL, an `"owner/repo"` shorthand, or `"owner/repo:subdir"`.

- state_env:

  An environment used to track initialisation state. The caller
  (typically a wrapping R package) supplies its own environment so
  multiple consuming packages do not interfere with each other.

- install:

  If `FALSE`, fail rather than installing missing packages.

- project:

  Optional path to a Julia project directory containing a `Project.toml`
  (and ideally a `Manifest.toml`). When supplied, the project is
  activated and instantiated in a subprocess, and `JULIA_PROJECT` is set
  before starting JuliaConnectoR so that the server picks up the
  project. Use this when your package ships a pinned Julia environment
  under `inst/julia/`. With `project` set, `packages` typically do not
  need to be installed individually — `Pkg.instantiate()` will fetch
  them from the project's manifest.

- verbose:

  If `TRUE`, print progress messages.

## Value

Invisibly `TRUE`.

## Details

1.  Locates the Julia binary (see
    [`julia_bin()`](https://epiforecasts.io/juliaready/reference/julia_bin.md)).

2.  For each required package, checks it loads in a Julia subprocess. If
    a package is missing and `install = TRUE`, installs it (from a
    GitHub URL if listed in `github`, otherwise from the General
    registry). Subprocess work avoids any interaction with the running
    JuliaConnectoR server.

3.  Starts (or attaches to) the JuliaConnectoR server.

4.  Loads each package via `juliaEval("using <pkg>")`, so dotted
    constructor names like `EpiBranch.NegBin` resolve correctly.

Idempotent: if `state_env$ready` is already `TRUE`, returns immediately.

## Examples

``` r
if (FALSE) { # \dontrun{
.my_pkg_env <- new.env(parent = emptyenv())
julia_ready(
  packages = c("EpiBranch", "Distributions", "Random"),
  github   = c(EpiBranch = "epiforecasts/EpiBranch.jl"),
  state_env = .my_pkg_env
)
} # }
```
