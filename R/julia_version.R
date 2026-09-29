#' Julia version a Manifest was resolved with
#'
#' A `Manifest.toml` records the Julia version that resolved it, and it
#' pins standard-library versions that only exist on that version. A
#' package shipping a pinned project therefore needs that Julia version to
#' instantiate cleanly.
#'
#' @param project Path to a Julia project directory containing a
#'   `Manifest.toml`.
#' @return The major and minor version as a string (e.g. `"1.12"`), or
#'   `NULL` when there is no manifest or it records no version.
#' @export
#' @examples
#' \dontrun{
#' manifest_julia_version(system.file("julia", package = "MyPkg"))
#' }
manifest_julia_version <- function(project) {
  manifest <- file.path(project, "Manifest.toml")
  if (!file.exists(manifest)) return(NULL)
  line <- grep(
    "^julia_version", readLines(manifest, warn = FALSE), value = TRUE
  )
  version <- regmatches(line, regexpr("[0-9]+\\.[0-9]+", line))
  if (length(version) == 0) NULL else version[1]
}

#' Install a Julia version with juliaup and return its binary
#'
#' Leaves the user's default channel alone: the binary is returned for the
#' caller to use, typically through `JULIACONNECTOR_JULIABIN`.
#'
#' @param version Julia version to install, e.g. `"1.12"`.
#' @param verbose If `TRUE`, print progress messages.
#' @return Path to the Julia executable, or `NULL` when juliaup is absent
#'   or the installation failed.
#' @export
#' @examples
#' \dontrun{
#' juliaup_julia("1.12")
#' }
juliaup_julia <- function(version, verbose = TRUE) {
  if (!nzchar(Sys.which("juliaup"))) {
    if (verbose) {
      message(
        "juliaup not found, so Julia ", version, " cannot be installed. ",
        "Using the Julia on the PATH; see ",
        "https://github.com/JuliaLang/juliaup"
      )
    }
    return(NULL)
  }
  status <- tryCatch(
    system2("juliaup", c("add", version), stdout = FALSE, stderr = FALSE),
    error = function(e) 1L
  )
  if (!identical(as.integer(status), 0L)) return(NULL)

  dirs <- list.dirs(
    file.path(path.expand("~"), ".julia", "juliaup"), recursive = FALSE
  )
  matching <- dirs[startsWith(basename(dirs), paste0("julia-", version, "."))]
  exe <- if (.Platform$OS.type == "windows") "julia.exe" else "julia"
  bins <- file.path(sort(matching, decreasing = TRUE), "bin", exe)
  bins <- bins[file.exists(bins)]
  if (length(bins) == 0) NULL else bins[1]
}

#' Point JuliaConnectoR at the Julia version a project's Manifest needs
#'
#' Reads the version from the manifest and, where juliaup can supply it,
#' sets `JULIACONNECTOR_JULIABIN`. An existing setting is left alone, so a
#' user who has chosen a binary keeps it.
#'
#' @inheritParams manifest_julia_version
#' @param verbose If `TRUE`, print progress messages.
#' @return Invisibly the version used, or `NULL` when none was selected.
#' @noRd
match_manifest_julia <- function(project, verbose = TRUE) {
  if (nzchar(Sys.getenv("JULIACONNECTOR_JULIABIN"))) return(invisible(NULL))
  version <- manifest_julia_version(project)
  if (is.null(version)) return(invisible(NULL))
  bin <- juliaup_julia(version, verbose)
  if (is.null(bin)) return(invisible(NULL))
  if (verbose) message("Using Julia ", version, " from ", bin)
  Sys.setenv(JULIACONNECTOR_JULIABIN = bin)
  invisible(version)
}
