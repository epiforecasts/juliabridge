#' Lazy-init guard for Julia setup
#'
#' Convenience wrapper for the common "call my package's `setup_*()`
#' function the first time any Julia-using function is called" pattern.
#' Idempotent: once `state_env$ready` is `TRUE`, this is a no-op.
#'
#' @param state_env An environment shared with [julia_ready()] used to
#'   track init state. The caller's R package typically owns this
#'   environment.
#' @param init_fn A zero-argument function that performs the package's
#'   one-time setup (typically calling [julia_ready()] and
#'   [julia_load_bridge()]).
#' @return Invisibly `TRUE`.
#' @export
#' @examples
#' \dontrun{
#' # Inside the consuming package:
#' .my_pkg_env <- new.env(parent = emptyenv())
#' setup_my_pkg <- function() {
#'   julia_ready(packages = "MyJuliaPkg", state_env = .my_pkg_env)
#'   julia_load_bridge("mypkg", "bridge.jl")
#' }
#' my_function <- function() {
#'   ensure_julia(.my_pkg_env, setup_my_pkg)
#'   call_julia("MyJuliaPkg.do_something")
#' }
#' }
ensure_julia <- function(state_env, init_fn) {
  if (!isTRUE(state_env$ready)) init_fn()
  invisible(TRUE)
}
