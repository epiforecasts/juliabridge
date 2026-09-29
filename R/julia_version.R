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
  recorded <- grep(
    "^julia_version", readLines(manifest, warn = FALSE), value = TRUE
  )
  # nolint next: nonportable_path_linter. A version pattern, not a path.
  matched <- regmatches(recorded, regexpr("[0-9]+\\.[0-9]+", recorded))
  if (length(matched) == 0) NULL else matched[1]
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

  juliaup_binary(version)
}

#' Ask the juliaup launcher where a channel's Julia binary is
#'
#' The launcher knows the depot, platform and exact version a channel
#' resolves to, which a scan of the depot directory would have to guess.
#' @noRd
juliaup_binary <- function(version) {
  exe <- if (.Platform$OS.type == "windows") "julia.exe" else "julia"
  launcher <- file.path(dirname(Sys.which("juliaup")), exe)
  if (!file.exists(launcher)) launcher <- Sys.which("julia")
  out <- with_unset_env(lib_path_vars, tryCatch(
    suppressWarnings(system2(
      launcher,
      c(
        paste0("+", version), "--startup-file=no", "-e",
        shQuote("print(joinpath(Sys.BINDIR, Base.julia_exename()))")
      ),
      stdout = TRUE, stderr = FALSE
    )),
    error = function(e) character()
  ))
  bin <- out[length(out)]
  if (length(bin) == 1 && file.exists(bin)) bin else NULL
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
  needed <- manifest_julia_version(project)
  if (is.null(needed)) return(invisible(NULL))
  bin <- juliaup_julia(needed, verbose)
  if (is.null(bin)) return(invisible(NULL))
  if (verbose) message("Using Julia ", needed, " from ", bin)
  Sys.setenv(JULIACONNECTOR_JULIABIN = bin)
  invisible(needed)
}
