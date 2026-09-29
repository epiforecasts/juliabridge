#' Hold a Julia object from R
#'
#' Some Julia results are too big, or too Julia-shaped, to convert: an
#' MCMC chain a later call will sample from, a simulation state later
#' summarised. The Julia side keeps such an object in a registry and
#' returns an integer handle, and R keeps the handle in an environment
#' whose finaliser queues it for release once nothing refers to it.
#'
#' Two hazards come with that, and these functions exist for them.
#'
#' Handles are numbered per session, so one from a session that has gone
#' away names whatever object now holds that number. Every handle is
#' therefore paired with a token identifying the session that made it, and
#' both sides compare tokens before acting.
#'
#' Saving an R object copies the environment by value while leaving the
#' finaliser behind, so a reloaded object names a Julia object it does not
#' own. The environment records which state environment created it, and a
#' copy no longer matches, which is what [julia_handle_owned()] reports.
#'
#' The Julia side needs three things, which a consumer package's own
#' module provides (keeping them there lets them precompile):
#'
#' ```julia
#' const HANDLES = Dict{Int, Any}()
#' const NEXT_HANDLE = Ref(0)
#' const SESSION = Ref("")
#'
#' function __init__()
#'     SESSION[] = string(rand(Random.RandomDevice(), UInt128); base = 16)
#'     return nothing
#' end
#'
#' function keep!(x)
#'     NEXT_HANDLE[] += 1
#'     HANDLES[NEXT_HANDLE[]] = x
#'     return NEXT_HANDLE[]
#' end
#'
#' function release!(handle::Integer, session::AbstractString)
#'     session == SESSION[] && delete!(HANDLES, Int(handle))
#'     return nothing
#' end
#' ```
#'
#' A function returning a handle returns `SESSION[]` alongside it, and one
#' acting on a handle takes the token and refuses a mismatch.
#'
#' @param handle Integer handle returned by the Julia side.
#' @param session Token identifying the Julia session that made it.
#' @param state_env The environment given to [julia_ready()].
#' @return An environment holding `handle`, `session` and the owning
#'   `state_env`.
#' @export
#' @examples
#' \dontrun{
#' result <- call_julia("MyBridge.fit", data)
#' fit <- list(
#'   draws = result$draws,
#'   julia = julia_handle(result$handle, result$session, .my_pkg_env)
#' )
#' }
julia_handle <- function(handle, session, state_env) {
  env <- new.env(parent = emptyenv())
  env$handle <- handle
  env$session <- session
  env$owner <- state_env
  env$setup <- state_env$setup
  reg.finalizer(env, function(e) {
    if (!identical(e$owner, state_env)) return(invisible(NULL))
    state_env$released <- c(
      state_env$released,
      list(list(handle = e$handle, session = e$session, setup = e$setup))
    )
  })
  env
}

#' Does this R session own the Julia object behind a handle?
#'
#' `FALSE` for a handle that arrived by saving and reloading, which names
#' a Julia object belonging to the session that created it, and for one
#' created before [julia_ready()] last set Julia up, whose object went
#' with the old Julia server. Callers use this to say so, rather than
#' reporting the object as missing.
#'
#' @param x A handle from [julia_handle()].
#' @inheritParams julia_handle
#' @return `TRUE` when the current setup of `state_env` created the handle.
#' @export
#' @examples
#' \dontrun{
#' if (!julia_handle_owned(fit$julia, .my_pkg_env)) {
#'   stop("This fit was loaded from disk; refit it to continue.")
#' }
#' }
julia_handle_owned <- function(x, state_env) {
  identical(x$owner, state_env) && identical(x$setup, state_env$setup)
}

#' Release the Julia objects of collected handles
#'
#' Finalisers run at arbitrary points, including partway through another
#' Julia call, so they queue rather than call Julia. Flushing the queue
#' from a known-safe point is this function's job: call it immediately
#' before a Julia call of your own.
#'
#' Only handles from the current setup of `state_env` are released. The
#' queue is dropped when `state_env` is not set up, and so are handles
#' from an earlier setup, because their objects went with the old Julia
#' server. A release that fails stays queued for the next call.
#'
#' @inheritParams julia_handle
#' @param release Name of the Julia function releasing a handle, taking
#'   the handle and the session token.
#' @return Invisibly the number of handles released.
#' @export
#' @examples
#' \dontrun{
#' julia_release_pending(.my_pkg_env, "MyBridge.release!")
#' call_julia("MyBridge.forecast", handle, horizon)
#' }
julia_release_pending <- function(state_env, release) {
  pending <- state_env$released
  state_env$released <- NULL
  if (!isTRUE(state_env$ready)) return(invisible(0L))
  current <- Filter(function(e) identical(e$setup, state_env$setup), pending)
  failed <- Filter(function(entry) {
    inherits(
      try(call_julia(release, entry$handle, entry$session), silent = TRUE),
      "try-error"
    )
  }, current)
  if (length(failed) > 0) {
    state_env$released <- c(state_env$released, failed)
  }
  invisible(length(current) - length(failed))
}
