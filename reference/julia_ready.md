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
  match_manifest = TRUE,
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
  (typically a wrapping R package) supplies its own environment. Several
  consuming packages then keep separate state.

- install:

  If `FALSE`, a missing package is an error.

- project:

  Optional path to a Julia project directory containing a `Project.toml`
  (and ideally a `Manifest.toml`). When supplied, the project is
  activated and instantiated in a subprocess. Setting `JULIA_PROJECT`
  before JuliaConnectoR starts makes the server use the project. Use
  this when your package ships a pinned Julia environment under
  `inst/julia/`. `Pkg.instantiate()` fetches everything in the project's
  manifest; `packages` then only names the packages to load with
  `using`.

- match_manifest:

  If `TRUE` and `project` is supplied, read the Julia version its
  `Manifest.toml` was resolved with and use that version, installing it
  with juliaup where available. Instantiating a manifest under a
  different Julia can fail, because it pins standard-library versions
  that exist only on the version that resolved it. Ignored when the user
  has chosen a binary through `JULIACONNECTOR_JULIABIN` or
  `JULIA_BINDIR`. A JuliaConnectoR server that is already running, for
  instance one another package started, keeps its Julia: the project is
  then instantiated under the matched version but loaded in the running
  one.

- verbose:

  If `TRUE`, print progress messages.

## Value

Invisibly `TRUE`.

## Details

1.  Locates the Julia binary (see
    [`julia_bin()`](https://epiforecasts.io/juliabridge/reference/julia_bin.md)).

2.  Without `project`, checks in a Julia subprocess that each required
    package loads. If a package is missing and `install = TRUE`,
    installs it (from a GitHub URL if listed in `github`, otherwise from
    the General registry). With `project`, instantiates that project
    instead. Both run in a subprocess, apart from the JuliaConnectoR
    server.

3.  Starts (or attaches to) the JuliaConnectoR server.

4.  Loads each package with `juliaEval("using <pkg>")`. Dotted
    constructor names such as `EpiBranch.NegBin` then resolve.

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
