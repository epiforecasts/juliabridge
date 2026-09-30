#' Julia version a Manifest was resolved with
#'
#' A `Manifest.toml` records the Julia version that resolved it and pins
#' standard-library versions that only exist on that version. A
#' package shipping a pinned project needs that Julia version to
#' instantiate cleanly.
#'
#' A versioned manifest (`Manifest-v1.12.toml`, supported from Julia 1.11)
#' takes precedence over `Manifest.toml` on the Julia version it names.
#' When any exist, the highest-versioned one is read. If it records no
#' Julia version, its file name supplies one.
#'
#' @param project Path to a Julia project directory containing a
#'   `Manifest.toml` or `Manifest-v<major>.<minor>.toml`.
#' @return The major and minor version as a string (e.g. `"1.12"`), or
#'   `NULL` when there is no manifest or it records no version.
#' @export
#' @examples
#' \dontrun{
#' manifest_julia_version(system.file("julia", package = "MyPkg"))
#' }
manifest_julia_version <- function(project) {
  # nolint start: nonportable_path_linter. These are version patterns.
  version_pattern <- "[0-9]+\\.[0-9]+"
  versioned <- list.files(
    project, pattern = "^Manifest-v[0-9]+\\.[0-9]+\\.toml$"
  )
  # nolint end
  if (length(versioned) > 0) {
    named <- regmatches(versioned, regexpr(version_pattern, versioned))
    newest <- order(numeric_version(named), decreasing = TRUE)[1]
    manifest <- file.path(project, versioned[newest])
    fallback <- named[newest]
  } else {
    manifest <- file.path(project, "Manifest.toml")
    if (!file.exists(manifest)) return(NULL)
    fallback <- NULL
  }
  recorded <- grep(
    "^julia_version", readLines(manifest, warn = FALSE), value = TRUE
  )
  matched <- regmatches(recorded, regexpr(version_pattern, recorded))
  if (length(matched) == 0) fallback else matched[1]
}

#' Install a Julia version with juliaup and return its binary
#'
#' The user's default channel stays as it is. The caller uses the returned
#' binary, typically through `JULIACONNECTOR_JULIABIN`.
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
        "Keeping the current Julia; see ",
        "https://github.com/JuliaLang/juliaup"
      )
    }
    return(NULL)
  }
  status <- tryCatch(
    system2("juliaup", c("add", version), stdout = FALSE, stderr = FALSE),
    error = function(e) 1L
  )
  if (!identical(as.integer(status), 0L)) {
    if (verbose) {
      message(
        "juliaup could not install Julia ", version, " (exit status ",
        status, "). Keeping the current Julia."
      )
    }
    return(NULL)
  }

  bin <- juliaup_binary(version)
  if (is.null(bin) && verbose) {
    message(
      "juliaup installed Julia ", version, " but its binary could not be ",
      "located. Keeping the current Julia."
    )
  }
  bin
}

#' Ask the juliaup launcher where a channel's Julia binary is
#'
#' The launcher resolves the channel to an exact version in the right
#' depot and for the right platform.
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
#' sets `JULIACONNECTOR_JULIABIN`. A binary the user chose, through
#' `JULIACONNECTOR_JULIABIN` or `JULIA_BINDIR`, is left alone. A value
#' juliabridge set itself for an earlier package can be replaced. A
#' JuliaConnectoR server that is already running keeps its Julia.
#'
#' @inheritParams manifest_julia_version
#' @param verbose If `TRUE`, print progress messages.
#' @return Invisibly the version used, or `NULL` when none was selected.
#' @noRd
match_manifest_julia <- function(project, verbose = TRUE) {
  if (user_juliabin() || nzchar(bindir_julia())) return(invisible(NULL))
  needed <- manifest_julia_version(project)
  if (is.null(needed)) return(invisible(NULL))
  bin <- juliaup_julia(needed, verbose)
  if (is.null(bin)) return(invisible(NULL))
  if (verbose) message("Using Julia ", needed, " from ", bin)
  set_juliabin(bin)
  invisible(needed)
}

#' Set `JULIACONNECTOR_JULIABIN`, remembering that juliabridge set it
#' @noRd
set_juliabin <- function(bin) {
  # Sys.which() returns a named string. identical() against Sys.getenv()
  # needs it unnamed.
  bin <- unname(bin)
  Sys.setenv(JULIACONNECTOR_JULIABIN = bin)
  .juliabridge_state$juliabin <- bin
}

#' Whether `JULIACONNECTOR_JULIABIN` holds a binary the user chose
#'
#' A path that does not exist counts as unset. [julia_bin()] skips such a
#' path. juliabridge overwrites it.
#' @noRd
user_juliabin <- function() {
  current <- Sys.getenv("JULIACONNECTOR_JULIABIN")
  nzchar(current) && file.exists(current) &&
    !identical(current, .juliabridge_state$juliabin)
}
