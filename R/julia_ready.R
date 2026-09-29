#' Ensure Julia and required Julia packages are ready
#'
#' Performs the steps needed to make Julia and a set of Julia packages
#' callable from R via JuliaConnectoR:
#'
#' 1. Locates the Julia binary (see [julia_bin()]).
#' 2. For each required package, checks it loads in a Julia subprocess.
#'    If a package is missing and `install = TRUE`, installs it (from a
#'    GitHub URL if listed in `github`, otherwise from the General
#'    registry). Subprocess work avoids any interaction with the running
#'    JuliaConnectoR server.
#' 3. Starts (or attaches to) the JuliaConnectoR server.
#' 4. Loads each package via `juliaEval("using <pkg>")`, so dotted
#'    constructor names like `EpiBranch.NegBin` resolve correctly.
#'
#' Idempotent: if `state_env$ready` is already `TRUE`, returns immediately.
#'
#' @param packages Character vector of Julia package names to ensure are
#'   loaded (e.g. `c("EpiBranch", "Distributions")`).
#' @param github Named character vector of GitHub URLs for packages not in
#'   the General registry. Names must match entries in `packages`. Values
#'   may be a full URL, an `"owner/repo"` shorthand, or `"owner/repo:subdir"`.
#' @param state_env An environment used to track initialisation state. The
#'   caller (typically a wrapping R package) supplies its own environment
#'   so multiple consuming packages do not interfere with each other.
#' @param install If `FALSE`, fail rather than installing missing packages.
#' @param project Optional path to a Julia project directory containing a
#'   `Project.toml` (and ideally a `Manifest.toml`). When supplied, the
#'   project is activated and instantiated in a subprocess, and
#'   `JULIA_PROJECT` is set before starting JuliaConnectoR so that the
#'   server picks up the project. Use this when your package ships a
#'   pinned Julia environment under `inst/julia/`. With `project` set,
#'   `packages` typically do not need to be installed individually —
#'   `Pkg.instantiate()` will fetch them from the project's manifest.
#' @param match_manifest If `TRUE` and `project` is supplied, read the
#'   Julia version its `Manifest.toml` was resolved with and use that
#'   version, installing it with juliaup where available. A manifest pins
#'   standard-library versions that exist only on the version that
#'   resolved it, so instantiating it under another Julia can fail.
#'   Ignored when `JULIACONNECTOR_JULIABIN` is already set.
#' @param verbose If `TRUE`, print progress messages.
#' @return Invisibly `TRUE`.
#' @export
#' @examples
#' \dontrun{
#' .my_pkg_env <- new.env(parent = emptyenv())
#' julia_ready(
#'   packages = c("EpiBranch", "Distributions", "Random"),
#'   github   = c(EpiBranch = "epiforecasts/EpiBranch.jl"),
#'   state_env = .my_pkg_env
#' )
#' }
julia_ready <- function(
  packages,
  github = character(),
  state_env = new.env(parent = emptyenv()),
  install = TRUE,
  project = NULL,
  match_manifest = TRUE,
  verbose = TRUE
) {
  if (isTRUE(state_env$ready)) return(invisible(TRUE))

  if (!is.null(project) && isTRUE(match_manifest)) {
    match_manifest_julia(project, verbose)
  }
  bin <- check_julia_bin(julia_bin())
  if (is.null(project)) {
    install_julia_packages(packages, github, bin, install, verbose)
  } else {
    instantiate_julia_project(project, bin, verbose)
  }

  # Tell JuliaConnectoR which Julia binary to use, then load packages.
  Sys.setenv(JULIACONNECTOR_JULIABIN = bin)
  for (pkg in packages) {
    JuliaConnectoR::juliaEval(sprintf("using %s", pkg))
  }

  state_env$ready <- TRUE
  invisible(TRUE)
}

#' Instantiate a pinned Julia project and make it the active project
#'
#' JuliaConnectoR starts its server with `JULIA_PROJECT` active.
#' @noRd
instantiate_julia_project <- function(project, bin, verbose) {
  project <- normalizePath(project, mustWork = TRUE)
  proj_jl <- gsub("\\", "/", project, fixed = TRUE)
  if (!file.exists(file.path(project, "Project.toml"))) {
    stop("No Project.toml found in ", project, call. = FALSE)
  }
  if (verbose) message("Instantiating Julia project: ", project)
  julia_subprocess(
    sprintf('import Pkg; Pkg.activate("%s"); Pkg.instantiate()', proj_jl),
    bin = bin
  )
  Sys.setenv(JULIA_PROJECT = project)
}

#' Install any missing packages into the default depot
#'
#' Each package is checked individually so only missing ones are added.
#' @noRd
install_julia_packages <- function(packages, github, bin, install, verbose) {
  missing_pkgs <- packages[!vapply(
    packages,
    function(pkg) {
      julia_subprocess(sprintf("using %s", pkg), check = FALSE, bin = bin)
    },
    logical(1)
  )]
  if (length(missing_pkgs) == 0) return(invisible())
  if (!install) {
    stop(
      "Julia package(s) not installed and install = FALSE: ",
      toString(missing_pkgs),
      call. = FALSE
    )
  }
  for (pkg in missing_pkgs) {
    if (verbose) message("Installing Julia package: ", pkg, " ...")
    julia_subprocess(.install_code(pkg, github), bin = bin)
  }
  if (verbose) message("Precompiling Julia depot...")
  julia_subprocess("import Pkg; Pkg.precompile()", bin = bin)
}

#' Build the Julia code to install a package, registry or GitHub.
#' @noRd
.install_code <- function(pkg, github) {
  if (pkg %in% names(github)) {
    spec <- github[[pkg]]
    subdir <- NULL
    if (startsWith(spec, "http://") || startsWith(spec, "https://")) {
      repo_url <- spec
    } else if (grepl(":", spec, fixed = TRUE)) {
      parts <- strsplit(spec, ":", fixed = TRUE)[[1]]
      repo_url <- paste0("https://github.com/", parts[1])
      subdir <- parts[2]
    } else {
      repo_url <- paste0("https://github.com/", spec)
    }
    pkgspec <- if (is.null(subdir)) {
      sprintf('Pkg.PackageSpec(url="%s")', repo_url)
    } else {
      sprintf('Pkg.PackageSpec(url="%s", subdir="%s")', repo_url, subdir)
    }
    sprintf("import Pkg; Pkg.add(%s); using %s", pkgspec, pkg)
  } else {
    sprintf('import Pkg; Pkg.add("%s"); using %s', pkg, pkg)
  }
}
