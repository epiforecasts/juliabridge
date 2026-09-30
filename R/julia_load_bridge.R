#' Load Julia bridge (.jl) files from a package's `inst/julia/` directory
#'
#' Reads each file as a string and evaluates it via
#' `JuliaConnectoR::juliaEval()` in the running Julia server. Bridge
#' files typically define helper functions used by the wrapping R
#' package; loading them once after package setup makes them available
#' to subsequent `juliaCall()` invocations.
#'
#' @param package Name of the calling R package (used as the `package`
#'   argument to `system.file()`). Files are looked up under
#'   `inst/julia/` of that package.
#' @param files Character vector of `.jl` filenames (no directory).
#' @param verbose If `TRUE`, print a message per loaded file.
#' @return Invisibly the character vector of paths that were loaded.
#' @export
#' @examples
#' \dontrun{
#' julia_load_bridge("ringbpjl",
#'   c("dist_lookup.jl", "simulate.jl", "generation_time.jl"))
#' }
julia_load_bridge <- function(package, files, verbose = FALSE) {
  loaded <- character()
  for (f in files) {
    # base::system.file() because pkgload's replacement rejects the inst/
    # lookup below when juliaready itself is loaded with load_all()
    path <- base::system.file("julia", f, package = package)
    if (!nzchar(path)) {
      # Development package loaded via pkgload: files still live under inst/
      path <- base::system.file("inst", "julia", f, package = package)
    }
    if (!nzchar(path) || !file.exists(path)) {
      stop(
        "Bridge file not found: inst/julia/", f,
        " in package '", package, "'",
        call. = FALSE
      )
    }
    if (verbose) message("Loading Julia bridge: ", f)
    code <- paste(readLines(path), collapse = "\n")
    JuliaConnectoR::juliaEval(code)
    loaded <- c(loaded, path)
  }
  invisible(loaded)
}
