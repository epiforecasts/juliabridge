#' Find the Julia binary
#'
#' Resolves the Julia binary path, used by `julia_subprocess()` to run
#' subprocess work (installing packages into the default depot) before
#' starting the JuliaConnectoR server.
#'
#' Detection order:
#'   1. `JULIACONNECTOR_JULIABIN` env var (JuliaConnectoR's preferred
#'      mechanism).
#'   2. `JULIA_BINDIR` env var (Julia's own; `joinpath(JULIA_BINDIR, "julia")`).
#'   3. `Sys.which("julia")` — fallback to PATH.
#'
#' @return Absolute path to the Julia executable, or `""` if not found.
#' @export
julia_bin <- function() {
  override <- Sys.getenv("JULIACONNECTOR_JULIABIN", unset = "")
  if (nzchar(override) && file.exists(override)) return(override)

  bindir <- Sys.getenv("JULIA_BINDIR", unset = "")
  if (nzchar(bindir)) {
    exe <- if (.Platform$OS.type == "windows") "julia.exe" else "julia"
    bin <- file.path(bindir, exe)
    if (file.exists(bin)) return(bin)
  }
  Sys.which("julia")
}

#' Run a Julia command in a subprocess
#'
#' Launches a fresh `julia` process for one-shot work such as `Pkg.add`
#' or `Pkg.precompile`. This is *not* the JuliaConnectoR server — it's a
#' transient process for installation work that runs before the server
#' is started.
#'
#' Strips library-path env vars that R may set (`LD_LIBRARY_PATH`,
#' `DYLD_LIBRARY_PATH`, `DYLD_FALLBACK_LIBRARY_PATH`), because those
#' point at R's own libraries and can cause Julia to segfault when
#' loaded into the subprocess.
#'
#' @param code Julia code to evaluate.
#' @param check If `TRUE`, error on non-zero exit. If `FALSE`, return
#'   `TRUE`/`FALSE` for success/failure.
#' @param bin Julia binary path; defaults to [julia_bin()].
#' @return When `check = FALSE`, a logical. When `check = TRUE`, invisible
#'   `TRUE` on success (errors otherwise).
#' @noRd
julia_subprocess <- function(code, check = TRUE, bin = julia_bin()) {
  check_julia_bin(bin)
  res <- with_unset_env(
    c("LD_LIBRARY_PATH", "DYLD_LIBRARY_PATH", "DYLD_FALLBACK_LIBRARY_PATH"),
    suppressWarnings(system2(
      bin,
      args = c("--startup-file=no", "-e", shQuote(code)),
      stdout = if (check) "" else FALSE,
      stderr = if (check) "" else FALSE
    ))
  )
  status <- if (is.numeric(res)) res else attr(res, "status")
  ok <- is.null(status) || status == 0
  if (check && !ok) {
    stop(
      "Julia subprocess failed (exit ", status, "). Code:\n", code,
      call. = FALSE
    )
  }
  if (check) invisible(TRUE) else ok
}

#' Error if the Julia binary is missing
#' @noRd
check_julia_bin <- function(bin) {
  if (!nzchar(bin) || !file.exists(bin)) {
    stop(
      "Julia not found. Install Julia (juliaup recommended: ",
      "https://github.com/JuliaLang/juliaup) or set JULIA_BINDIR.",
      call. = FALSE
    )
  }
  invisible(bin)
}

#' Evaluate an expression with environment variables unset
#'
#' The variables are restored to their previous values (or left unset)
#' afterwards, even on error.
#' @noRd
with_unset_env <- function(vars, expr) {
  saved <- vapply(vars, Sys.getenv, character(1), unset = NA)
  on.exit({
    for (v in vars) {
      if (is.na(saved[[v]])) {
        Sys.unsetenv(v)
      } else {
        do.call(Sys.setenv, stats::setNames(list(saved[[v]]), v))
      }
    }
  }, add = TRUE)
  Sys.unsetenv(vars)
  expr
}
