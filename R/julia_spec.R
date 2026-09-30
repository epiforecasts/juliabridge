# A Julia call is held in R as a lazy specification and rendered to Julia
# source only when it is run. Rendering is pure R, so a consumer package can
# build, print and inspect a call without starting Julia.

#' Describe a Julia constructor call
#'
#' Records a call to a Julia constructor as an R object, rendered to Julia
#' source only when it is run. A package wrapping a Julia library builds its
#' own constructors on top of this, and exposes it directly so that users can
#' reach anything it has not wrapped.
#'
#' Arguments are rendered to Julia as follows: components and [julia()]
#' expressions are inserted as code, numeric vectors of length one become
#' scalars and longer ones become vectors, unnamed lists become vectors,
#' `NA` becomes `missing`, and character strings become Julia strings.
#' Integers (e.g. `2L`) render as Julia integers and doubles as floats.
#' A `NULL` keyword argument is dropped, so the Julia default applies; a
#' `NULL` positional argument is an error, since dropping it would renumber
#' the arguments that follow.
#'
#' @param fn Character string. Name of the Julia constructor.
#' @param ... Arguments to the constructor. Unnamed arguments are positional
#'   and named arguments become keyword arguments. Keyword names may contain
#'   non-ASCII characters.
#' @param role Optional character string naming what the component is, in
#'   whatever vocabulary the calling package uses (for example `"prior"` or
#'   `"model"`). It becomes a class, so [assert_role()] can check that
#'   components are composed sensibly. `NULL` leaves the component untyped,
#'   which every role accepts.
#'
#' @return An object of class `julia_component`.
#'
#' @examples
#' component("Normal", 0, 1, role = "prior")
#'
#' # Keyword arguments, and a component nested inside another
#' component("Truncated", component("Normal", 0, 1), lower = 0)
#' @export
component <- function(fn, ..., role = NULL) {
  .assert_name(fn, "fn")
  if (!is.null(role)) .assert_role_name(role)
  dots <- list(...)
  arg_names <- names(dots)
  if (is.null(arg_names)) arg_names <- rep("", length(dots))
  keep <- !vapply(dots, is.null, logical(1))
  named <- nzchar(arg_names)
  if (any(!keep & !named)) {
    stop(
      "A positional argument is `NULL`. Dropping it would renumber the ",
      "arguments that follow, so pass a value or use a keyword argument, ",
      "which takes the Julia default when `NULL`.",
      call. = FALSE
    )
  }
  # Julia identifiers may hold letters from any script, as its own models do
  # with Greek ones, so letters are matched rather than ASCII.
  bad <- arg_names[named][
    !grepl("^[\\p{L}_][\\p{L}\\p{N}_!]*$", arg_names[named], perl = TRUE)
  ]
  if (length(bad) > 0) {
    stop(
      "Keyword names must be Julia identifiers: ",
      toString(bad),
      call. = FALSE
    )
  }
  structure(
    list(
      fn = fn,
      args = unname(dots[keep & !named]),
      kwargs = dots[keep & named]
    ),
    class = c(
      if (!is.null(role)) paste0("julia_", role), "julia_component"
    )
  )
}

#' Embed Julia code in a model
#'
#' Marks a string as Julia source to be inserted verbatim when a component is
#' rendered, for arguments that cannot be expressed in R, such as functions or
#' objects from other Julia packages.
#'
#' @param code Character string of Julia code.
#' @param role Optional role (see [component()]). Without one the expression
#'   is accepted wherever a component is expected.
#'
#' @return An object of class `julia_julia`.
#'
#' @examples
#' # A Julia function, which has no R equivalent to render
#' component("Sampler", transform = julia("identity"))
#' @export
julia <- function(code, role = NULL) {
  if (!is.character(code) || length(code) != 1 || is.na(code) ||
      !nzchar(code)) {
    stop("`code` must be a single non-empty string.", call. = FALSE)
  }
  if (!is.null(role)) .assert_role_name(role)
  structure(
    list(code = code),
    class = c(
      if (!is.null(role)) paste0("julia_", role),
      "julia_code", "julia_component"
    )
  )
}

#' Render a component as Julia code
#'
#' @param x A component from [component()] or [julia()].
#' @param ascii Logical. If `TRUE`, keyword names with non-ASCII characters
#'   are written with Unicode escapes, as string literals always are. Code
#'   supplied through [julia()] is inserted verbatim either way. The default
#'   gives the more readable form that can be pasted into Julia.
#'
#' @return A character string of Julia code that constructs the component.
#'
#' @examples
#' as_julia(component("Gamma", 6.5, 0.62))
#'
#' # A keyword name outside ASCII travels as an escape, so the code is ASCII
#' greek <- list(1)
#' names(greek) <- "\u03f5_t"
#' as_julia(do.call(component, c("Process", greek)), ascii = TRUE)
#' @export
as_julia <- function(x, ascii = FALSE) {
  .render(x, ascii = ascii)
}

#' Render an R value as Julia code
#'
#' @param x An R value or component.
#' @param ascii Logical. See [as_julia()].
#' @return A character string of Julia code.
#' @noRd
.render <- function(x, ascii = TRUE) {
  if (inherits(x, "julia_code")) {
    return(x$code)
  }
  if (inherits(x, "julia_component")) {
    return(.render_call(
      x$fn,
      vapply(x$args, .render, character(1), ascii = ascii),
      .render_kwargs(x$kwargs, ascii)
    ))
  }
  # A class of the calling package's own is asked how it renders, before the
  # structure underneath it is read: most such classes are built on a list or
  # a vector, which would otherwise be rendered as one.
  if (!is.null(attr(x, "class"))) {
    return(.render(as_julia_value(x), ascii = ascii))
  }
  if (is.list(x)) {
    if (!is.null(names(x)) && any(nzchar(names(x)))) {
      stop("Named lists cannot be rendered as Julia values.", call. = FALSE)
    }
    return(.render_vector(vapply(x, .render, character(1), ascii = ascii)))
  }
  .render_atomic(x)
}

#' Render an atomic vector as a Julia scalar or vector
#'
#' @param x An atomic vector.
#' @return A character string of Julia code.
#' @noRd
.render_atomic <- function(x) {
  if (length(x) == 0) {
    stop("Cannot render an empty value as Julia code.", call. = FALSE)
  }
  scalars <- if (is.logical(x)) {
    vapply(x, .render_logical, character(1), USE.NAMES = FALSE)
  } else if (is.integer(x)) {
    vapply(x, .render_integer, character(1), USE.NAMES = FALSE)
  } else if (is.numeric(x)) {
    vapply(x, .render_float, character(1), USE.NAMES = FALSE)
  } else if (is.character(x)) {
    vapply(x, .render_string, character(1), USE.NAMES = FALSE)
  } else {
    stop(
      "Cannot render an object of class '", class(x)[1], "' as Julia code.",
      call. = FALSE
    )
  }
  if (length(scalars) == 1) scalars else .render_vector(scalars)
}

#' Render one logical value
#'
#' @param x A logical scalar.
#' @return A character string.
#' @noRd
.render_logical <- function(x) {
  if (is.na(x)) {
    return("missing")
  }
  if (x) "true" else "false"
}

#' Render one integer value
#'
#' @param x An integer scalar.
#' @return A character string.
#' @noRd
.render_integer <- function(x) {
  if (is.na(x)) "missing" else as.character(x)
}

#' Render a value of a class this package does not know
#'
#' The extension point for a calling package with its own way of describing a
#' value, such as a distribution object. Write a method returning either a
#' component from [component()] or a plain R value, and it renders wherever
#' the value appears.
#'
#' @param x The value to render.
#' @param ... Passed to methods.
#' @return A component or an R value that renders on its own.
#' @export
#' @examples
#' # A package with its own distribution class renders it like this:
#' as_julia_value.my_normal <- function(x, ...) {
#'   component("Normal", x$mean, x$sd)
#' }
as_julia_value <- function(x, ...) {
  UseMethod("as_julia_value")
}

#' @export
as_julia_value.default <- function(x, ...) {
  stop(
    "Cannot render an object of class '", class(x)[1], "' as Julia code. ",
    "Supply an `as_julia_value()` method for it.",
    call. = FALSE
  )
}

#' Assemble a Julia call from rendered pieces
#'
#' @param fn Function name.
#' @param args Character vector of rendered positional arguments.
#' @param kwargs Character vector of rendered keyword arguments.
#' @return A character string.
#' @noRd
.render_call <- function(fn, args, kwargs) {
  inner <- toString(args)
  if (length(kwargs) > 0) {
    inner <- paste0(inner, "; ", toString(kwargs))
  }
  paste0(fn, "(", inner, ")")
}

#' Assemble a Julia vector from rendered elements
#'
#' @param elements Character vector of rendered elements.
#' @return A character string.
#' @noRd
.render_vector <- function(elements) {
  paste0("[", toString(elements), "]")
}

#' Render keyword arguments
#'
#' In ASCII mode, names with non-ASCII characters are splatted in as `Symbol`
#' pairs built from Unicode escapes, so the code survives transfer to Julia on
#' any platform.
#'
#' @param kwargs Named list of R values.
#' @param ascii Logical. See [as_julia()].
#' @return Character vector of rendered keyword arguments.
#' @noRd
.render_kwargs <- function(kwargs, ascii) {
  if (length(kwargs) == 0) {
    return(character())
  }
  kw_names <- names(kwargs)
  values <- vapply(kwargs, .render, character(1), ascii = ascii)
  out <- paste0(kw_names, " = ", values)
  escape <- ascii & grepl("[^ -~]", kw_names)
  out[escape] <- sprintf(
    "(Symbol(%s) => %s,)...",
    vapply(kw_names[escape], .render_string, character(1)), values[escape]
  )
  out
}

#' Render a double as a Julia float literal
#'
#' @param x A numeric scalar.
#' @return A character string.
#' @noRd
.render_float <- function(x) {
  if (is.nan(x)) {
    return("NaN")
  }
  if (is.na(x)) {
    return("missing")
  }
  if (is.infinite(x)) {
    return(if (x > 0) "Inf" else "-Inf")
  }
  out <- sprintf("%.15g", x)
  if (as.numeric(out) != x) out <- sprintf("%.17g", x)
  if (!grepl("[.e]", out)) out <- paste0(out, ".0")
  out
}

#' Render a string as an ASCII Julia string literal
#'
#' @param x A character scalar.
#' @return A character string.
#' @noRd
.render_string <- function(x) {
  codes <- utf8ToInt(enc2utf8(x))
  if (anyNA(codes)) {
    stop("Cannot render a string that is not valid UTF-8.", call. = FALSE)
  }
  chars <- vapply(codes, function(code) {
    if (code %in% c(34L, 36L, 92L)) {
      paste0("\\", intToUtf8(code))
    } else if (code >= 32L && code <= 126L) {
      intToUtf8(code)
    } else if (code <= 0xFFFFL) {
      sprintf("\\u%04x", code)
    } else {
      # Julia's \u takes at most four hex digits, so anything above the basic
      # plane needs the eight-digit escape.
      sprintf("\\U%08x", code)
    }
  }, character(1))
  paste0("\"", paste(chars, collapse = ""), "\"")
}

#' Format a component as indented Julia code
#'
#' Calls that fit within `width` stay on one line; longer ones put each
#' argument on its own line.
#'
#' @param x A component or R value.
#' @param width Maximum line width.
#' @param indent Current indentation level.
#' @return Character vector of lines.
#' @noRd
.format_code <- function(x, width = 78L, indent = 0L) {
  # As in `.render()`: a consumer's class is asked how it renders before the
  # structure underneath it is read, so a broken-up print agrees with the
  # code that would be sent to Julia.
  if (!inherits(x, "julia_component") && !is.null(attr(x, "class"))) {
    return(.format_code(as_julia_value(x), width = width, indent = indent))
  }
  pad <- strrep("    ", indent)
  flat <- .render(x, ascii = FALSE)
  is_vector <- is.list(x) && !inherits(x, "julia_component")
  breakable <- is_vector || inherits(x, "julia_component")
  if (nchar(pad) + nchar(flat) <= width || inherits(x, "julia_code") ||
      !breakable) {
    return(paste0(pad, flat))
  }
  if (is_vector) {
    elements <- lapply(x, .format_code, width = width, indent = indent + 1L)
    return(c(paste0(pad, "["), .join_lines(elements), paste0(pad, "]")))
  }
  .format_call(x, width, indent, pad)
}

#' Format a component call over several lines
#'
#' @inheritParams .format_code
#' @param pad The indentation of the call itself.
#' @return Character vector of lines.
#' @noRd
.format_call <- function(x, width, indent, pad) {
  inner_pad <- strrep("    ", indent + 1L)
  positional <- lapply(
    x$args, .format_code, width = width, indent = indent + 1L
  )
  kwargs <- Map(function(name, value) {
    formatted <- .format_code(value, width - nchar(name) - 3L, indent + 1L)
    formatted[1] <- paste0(inner_pad, name, " = ", trimws(formatted[1], "left"))
    formatted
  }, names(x$kwargs), x$kwargs)
  opening <- if (length(positional) == 0 && length(kwargs) > 0) "(;" else "("
  c(
    paste0(pad, x$fn, opening),
    .join_lines(positional, if (length(kwargs) > 0) ";" else ""),
    .join_lines(unname(kwargs)),
    paste0(pad, ")")
  )
}

#' Join formatted arguments with separators
#'
#' @param pieces List of character vectors, one per argument.
#' @param last_sep Separator after the final argument.
#' @return Character vector of lines.
#' @noRd
.join_lines <- function(pieces, last_sep = "") {
  unlist(lapply(seq_along(pieces), function(i) {
    formatted <- pieces[[i]]
    n <- length(formatted)
    sep <- if (i < length(pieces)) "," else last_sep
    formatted[n] <- paste0(formatted[n], sep)
    formatted
  }))
}

#' Check that an argument is a component of an accepted role
#'
#' Composition errors are worth catching in R, where the argument can be
#' named, rather than in Julia, where the error arrives from inside a
#' constructor. A [julia()] expression with no role is accepted for any role,
#' since the caller has said what it is by writing the code.
#'
#' @param x Object to check.
#' @param roles Character vector of accepted roles.
#' @param null_ok Logical. Whether `NULL` is accepted.
#' @param arg_name Name used in error messages.
#' @param labels Optional named character vector describing each role, used
#'   in the error message, for instance
#'   `c(prior = "a prior (e.g. `Normal()`)")`. Roles without an entry are
#'   described by their own name.
#' @return Invisibly `TRUE`.
#' @export
#' @examples
#' prior <- component("Normal", 0, 1, role = "prior")
#' assert_role(prior, "prior")
#' try(assert_role(prior, "model"))
assert_role <- function(
  x, roles, null_ok = FALSE, arg_name = deparse(substitute(x)), labels = NULL
) {
  # A component or an expression with no role says nothing about what it is,
  # so any role accepts it: the caller has said what it is by writing it.
  untyped <- identical(class(x), c("julia_code", "julia_component")) ||
    identical(class(x), "julia_component")
  if ((is.null(x) && null_ok) || untyped ||
      inherits(x, paste0("julia_", roles))) {
    return(invisible(TRUE))
  }
  described <- vapply(
    roles, .role_label, character(1), labels = labels, USE.NAMES = FALSE
  )
  stop(
    "`", arg_name, "` must be ", paste(described, collapse = " or "), ".",
    call. = FALSE
  )
}

#' Describe one role for an error message
#'
#' @param role The role name.
#' @param labels Named character vector of descriptions, or `NULL`.
#' @return A character string.
#' @noRd
.role_label <- function(role, labels) {
  if (!is.null(labels) && role %in% names(labels)) {
    return(labels[[role]])
  }
  article <- if (grepl("^[aeiouAEIOU]", role)) "an" else "a"
  paste(article, role, "component")
}

#' Check a role name
#'
#' A role becomes a class, so it needs to be a single name, but it is never
#' rendered into Julia and may say whatever the calling package means by it.
#'
#' @param role The role to check.
#' @return Invisibly `TRUE`.
#' @noRd
.assert_role_name <- function(role) {
  if (!is.character(role) || length(role) != 1 || is.na(role) ||
      !grepl("^[\\p{L}_][\\p{L}\\p{N}_.]*$", role, perl = TRUE)) {
    stop(
      "`role` must be a single name, such as \"prior\" or \"model\", ",
      "using letters, digits, `.` and `_`.",
      call. = FALSE
    )
  }
  # A role becomes a class suffix, and these two are the package's own.
  if (role %in% c("code", "component")) {
    stop(
      "`role` cannot be \"", role, "\", which juliabridge uses for its own ",
      "classes. Pick another name for it.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' Check a name that is rendered into Julia source
#'
#' @param x The name to check.
#' @param arg_name Name used in error messages.
#' @return Invisibly `TRUE`.
#' @noRd
.assert_name <- function(x, arg_name) {
  if (!is.character(x) || length(x) != 1 || is.na(x) ||
      !grepl("^[A-Za-z_][A-Za-z0-9_.!]*$", x)) {
    stop(
      "`", arg_name, "` must be a single name that Julia can read, ",
      "such as \"Normal\" or \"MyModule.build\".",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' @export
print.julia_component <- function(x, ...) {
  role <- sub("^julia_", "", class(x)[1])
  label <- switch(role,
    code = "Julia code",
    component = "untyped component",
    paste(role, "component")
  )
  cat("<julia ", label, ">\n", sep = "")
  cat(.format_code(x), sep = "\n")
  invisible(x)
}
