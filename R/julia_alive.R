#' Is the Julia session still usable?
#'
#' [julia_ready()] records that setup has run, and returns immediately on
#' a later call. That leaves a session stuck once its Julia process goes
#' away, whether it was stopped, interrupted or died: the packages are no
#' longer loaded, while the flag still says they are.
#'
#' This checks the running session and clears the flag when the check
#' fails, so the next [julia_ready()] call sets Julia up again. The
#' environment itself is kept, because callers may use its identity.
#'
#' @param state_env The environment given to [julia_ready()].
#' JuliaConnectoR starts a new server whenever its connection has gone,
#' so the check itself may start Julia. The default probe is `FALSE` in
#' such a server, because only the server [julia_ready()] ran in holds the
#' token it recorded.
#'
#' @param probe Julia code returning a `Bool`, evaluated to decide whether
#'   the session still holds what the caller needs. The default checks
#'   that this is the server `state_env` was set up in. A caller can ask
#'   for something more specific, e.g. `"isdefined(Main, :MyBridge)"`.
#' @return `TRUE` when the session is usable, otherwise `FALSE`.
#' @export
#' @examples
#' \dontrun{
#' if (!julia_alive(.my_pkg_env, "isdefined(Main, :MyBridge)")) {
#'   setup_my_pkg()
#' }
#' }
julia_alive <- function(state_env, probe = NULL) {
  if (!isTRUE(state_env$ready)) return(FALSE)
  if (is.null(probe)) probe <- setup_probe(state_env)
  running <- tryCatch(
    isTRUE(JuliaConnectoR::juliaEval(probe)),
    error = function(e) FALSE
  )
  if (!running) state_env$ready <- FALSE
  running
}
