#' Backend-agnostic wrappers around Julia eval / call / import
#'
#' These thin wrappers let consumer packages call into Julia through
#' juliaready alone. If `juliaready` ever switches backend, consumer code
#' keeps working.
#'
#' @name wrappers
NULL

#' Evaluate Julia code
#' @param code A string of Julia code.
#' @return The result, converted to R where reasonable; otherwise a
#'   `JuliaProxy` object.
#' @export
eval_julia <- function(code) {
  JuliaConnectoR::juliaEval(code)
}

#' Call a Julia function by (qualified) name
#'
#' The function name may be module-qualified (e.g. `"Distributions.mean"`).
#' Qualifying the name after `using` makes constructor names resolve
#' unambiguously.
#'
#' @param name Function name, optionally module-qualified.
#' @param ... Arguments passed to the Julia function.
#' @return The Julia function's return value, converted to R where
#'   reasonable.
#' @export
call_julia <- function(name, ...) {
  JuliaConnectoR::juliaCall(name, ...)
}

#' Import a Julia module
#'
#' Returns a list/environment-like object of the module's exported names,
#' callable as R functions. Equivalent to `juliaImport`.
#'
#' @param module Name of the Julia module, e.g. `"Distributions"`.
#' @return A `JuliaModuleImport` object.
#' @export
import_julia <- function(module) {
  JuliaConnectoR::juliaImport(module)
}

# Session-level state, e.g. whether the assign helper has been defined.
.juliaready_state <- new.env(parent = emptyenv())

#' Assign an R value to a name in Julia's `Main` module
#'
#' Equivalent in spirit to `JuliaCall::julia_assign(name, value)`. Useful
#' when porting code that previously used the assign-then-eval pattern.
#' Idiomatic JuliaConnectoR code prefers passing values directly via
#' [call_julia()]; this is provided for migration convenience.
#'
#' Internally defines a small Julia helper `__juliaready_assign__!` on
#' first use and calls it with the (Symbol, value) pair.
#'
#' @param name Variable name to bind in `Main`.
#' @param value R value to convert and assign.
#' @return Invisibly `NULL`.
#' @export
assign_julia <- function(name, value) {
  if (!grepl("^[A-Za-z_][A-Za-z0-9_]*$", name)) {
    stop("Invalid Julia identifier: ", name, call. = FALSE)
  }
  if (!isTRUE(.juliaready_state$assign_helper_loaded)) {
    JuliaConnectoR::juliaEval(
      "function __juliaready_assign__!(name::Symbol, value)
         Core.eval(Main, Expr(:(=), name, value))
         nothing
       end"
    )
    .juliaready_state$assign_helper_loaded <- TRUE
  }
  sym <- JuliaConnectoR::juliaCall("Symbol", name)
  invisible(JuliaConnectoR::juliaCall("__juliaready_assign__!", sym, value))
}

#' Fully translate a Julia value into R
#'
#' [eval_julia()] and [call_julia()] return composite Julia values
#' (structs, Tuples, NamedTuples, Dicts) as proxy objects that reference
#' the value inside the Julia session. This function translates such a
#' proxy into a plain R object, e.g. a NamedTuple into a named list.
#' Values that are already plain R objects pass through unchanged.
#'
#' @param x A Julia proxy object (or an already-translated R value).
#' @return The value fully translated into R data structures.
#' @export
get_julia <- function(x) {
  JuliaConnectoR::juliaGet(x)
}

#' Run a Julia command for its side effects
#'
#' Equivalent in spirit to `JuliaCall::julia_command(code)`: evaluate
#' Julia code without using the return value. Provided for migration
#' convenience; functionally identical to [eval_julia()] called for
#' its side effects.
#'
#' @param code A string of Julia code.
#' @return Invisibly the result of `juliaEval`.
#' @export
command_julia <- function(code) {
  invisible(JuliaConnectoR::juliaEval(code))
}
