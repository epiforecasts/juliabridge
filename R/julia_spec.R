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
#' Arguments are rendered to Julia as follows: specs and [julia()]
#' expressions are inserted as code, numeric vectors of length one become
#' scalars and longer ones become vectors, unnamed lists become vectors,
#' `NA` becomes `missing`, and character strings become Julia strings.
#' Integers (e.g. `2L`) render as Julia integers and doubles as floats.
#' A `NULL` keyword argument is dropped, so the Julia default applies; a
#' `NULL` positional argument is an error, since dropping it would renumber
#' the arguments that follow. A matrix or array keeps its shape, arriving in
#' Julia as a `Matrix` or `Array` of the same dimensions. A named vector, a
#' named list and an empty value are all refused, since Julia would read them
#' as something the R value did not say.
#'
#' @param .fn Character string. Name of the Julia constructor. It is spelled
#'   with a dot so that a Julia keyword named `f` or `fn` still reaches `...`
#'   rather than being taken for this argument.
#' @param ... Arguments to the constructor. Unnamed arguments are positional
#'   and named arguments become keyword arguments. Keyword names may contain
#'   non-ASCII characters.
#' @param .role Optional character string naming what the spec is, in
#'   whatever vocabulary the calling package uses (for example `"prior"` or
#'   `"model"`). It becomes a class, so [assert_role()] can check that
#'   specs are composed sensibly. `NULL` leaves the spec untyped,
#'   which every role accepts. It is spelled with a dot for the same reason
#'   as `.fn`, so that a Julia keyword named `role` reaches `...`.
#'
#' @return An object of class `julia_spec`, holding the constructor name
#'   in `$fn`, the positional arguments in `$args` and the keyword arguments
#'   in `$kwargs`. A package may read those to inspect or rewrite a call.
#'
#' @examples
#' # Any Julia constructor, by name. R types map across: `10L` is a Julia
#' # integer, `1e-8` a float and `"BFGS"` a Julia string.
#' julia_spec("Solver", 10L, tol = 1e-8, method = "BFGS")
#'
#' # A name may be qualified by its module, and a spec may nest in another
#' julia_spec("MyModule.Problem", julia_spec("Solver", 10L), verbose = TRUE)
#'
#' # A matrix keeps its shape, reaching Julia as a Matrix
#' as_julia(julia_spec("Weights", matrix(1:4, nrow = 2)))
#'
#' # A role lets the calling package check how specs are composed
#' julia_spec("Normal", 0, 1, .role = "prior")
#' @export
julia_spec <- function(.fn, ..., .role = NULL) {
  .assert_name(.fn, ".fn")
  if (!is.null(.role)) .assert_role_name(.role)
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
  keyword_pattern <- "^[\\p{L}_][\\p{L}\\p{N}_!]*\\z"
  bad <- arg_names[named][
    !grepl(keyword_pattern, arg_names[named], perl = TRUE)
  ]
  if (length(bad) > 0) {
    stop(
      "Keyword names must be Julia identifiers: ",
      toString(bad),
      call. = FALSE
    )
  }
  repeated <- unique(arg_names[named][duplicated(arg_names[named])])
  if (length(repeated) > 0) {
    stop(
      "Keyword names must be distinct, since Julia rejects a keyword ",
      "argument given twice in one call: ", toString(repeated),
      call. = FALSE
    )
  }
  structure(
    list(
      fn = .fn,
      args = unname(dots[keep & !named]),
      kwargs = dots[keep & named]
    ),
    class = c(
      if (!is.null(.role)) paste0("julia_", .role), "julia_spec"
    )
  )
}

#' Embed Julia code in a spec
#'
#' Marks a string as Julia source to be inserted verbatim when a spec is
#' rendered, for arguments that cannot be expressed in R, such as functions or
#' objects from other Julia packages.
#'
#' @param code Character string of Julia code.
#' @param .role Optional role (see [julia_spec()]). Without one the
#'   expression is accepted wherever a spec is expected.
#'
#' @return An object of class `julia_code`, which is also a
#'   `julia_spec` and holds the code in `$code`. It has no `$fn`,
#'   `$args` or `$kwargs`, so a package walking a call branches on
#'   `inherits(x, "julia_code")` first.
#'
#' @examples
#' # A Julia function, which has no R equivalent to render
#' julia_spec("Sampler", transform = julia("identity"))
#' @export
julia <- function(code, .role = NULL) {
  if (!is.character(code) || length(code) != 1 || is.na(code) ||
      !nzchar(code)) {
    stop("`code` must be a single non-empty string.", call. = FALSE)
  }
  if (!is.null(.role)) .assert_role_name(.role)
  structure(
    list(code = code),
    class = c(
      if (!is.null(.role)) paste0("julia_", .role),
      "julia_code", "julia_spec"
    )
  )
}

#' Render a spec as Julia code
#'
#' @param x A spec from [julia_spec()] or [julia()].
#' @param ascii Logical. If `TRUE`, keyword names with non-ASCII characters
#'   are written with Unicode escapes, as string literals always are. Code
#'   supplied through [julia()] is inserted verbatim either way. The default
#'   gives the more readable form that can be pasted into Julia.
#'
#' @return A character string of Julia code that constructs the spec.
#'
#' @examples
#' as_julia(julia_spec("Solver", 10L, tol = 1e-8))
#'
#' # A keyword name outside ASCII travels as an escape, so the code is ASCII
#' greek <- list(1)
#' names(greek) <- "\u03f5_t"
#' as_julia(do.call(julia_spec, c("Process", greek)), ascii = TRUE)
#' @export
as_julia <- function(x, ascii = FALSE) {
  .render(x, ascii = ascii)
}

#' Render an R value as Julia code
#'
#' @param x An R value or spec.
#' @param ascii Logical. See [as_julia()].
#' @return A character string of Julia code.
#' @noRd
.render <- function(x, ascii = TRUE) {
  if (inherits(x, "julia_code")) {
    return(x$code)
  }
  if (inherits(x, "julia_spec")) {
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
    if (length(x) == 0) {
      stop("Cannot render an empty value as Julia code.", call. = FALSE)
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
  # R keeps an all-NULL `dimnames` on a matrix that carries no names, which
  # is what stripping names with `rownames(x) <- NULL` leaves behind.
  axis_names <- dimnames(x)
  labelled <- !is.null(axis_names) &&
    !all(vapply(axis_names, is.null, logical(1)))
  if (!is.null(names(x)) || labelled) {
    stop(
      "Named vectors and arrays cannot be rendered as Julia values, since ",
      "Julia reads them as a plain vector or array and the names would be ",
      "lost. Drop the names, or pass the pieces separately.",
      call. = FALSE
    )
  }
  scalars <- if (is.logical(x)) {
    vapply(x, .render_logical, character(1), USE.NAMES = FALSE)
  } else if (is.integer(x)) {
    vapply(x, .render_integer, character(1), USE.NAMES = FALSE)
  } else if (is.numeric(x)) {
    vapply(x, .render_float, character(1), USE.NAMES = FALSE)
  } else if (is.character(x)) {
    vapply(x, .render_character, character(1), USE.NAMES = FALSE)
  } else {
    stop(
      "Cannot render an object of class '", class(x)[1], "' as Julia code.",
      call. = FALSE
    )
  }
  if (!is.null(dim(x))) {
    # R stores an array column-major, as Julia does, so the elements go
    # across as they are and `reshape` restores the shape.
    return(paste0(
      "reshape(", .render_vector(scalars), ", (", toString(dim(x)), "))"
    ))
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
#' spec from [julia_spec()] or a plain R value, and it renders wherever
#' the value appears.
#'
#' @param x The value to render.
#' @param ... Passed to methods.
#' @return A spec or an R value that renders on its own.
#' @export
#' @examples
#' # A package with a value class of its own renders it like this:
#' as_julia_value.my_interval <- function(x, ...) {
#'   julia_spec("Interval", x$lower, x$upper)
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

#' Render one character value, which may be missing
#'
#' @param x A character scalar.
#' @return A character string.
#' @noRd
.render_character <- function(x) {
  if (is.na(x)) "missing" else .render_string(x)
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

#' Format a spec as indented Julia code
#'
#' Calls that fit within `width` stay on one line; longer ones put each
#' argument on its own line.
#'
#' @param x A spec or R value.
#' @param width Maximum line width.
#' @param indent Current indentation level.
#' @return Character vector of lines.
#' @noRd
.format_code <- function(x, width = 78L, indent = 0L) {
  # As in `.render()`: a consumer's class is asked how it renders before the
  # structure underneath it is read, so a broken-up print agrees with the
  # code that would be sent to Julia.
  if (!inherits(x, "julia_spec") && !is.null(attr(x, "class"))) {
    return(.format_code(as_julia_value(x), width = width, indent = indent))
  }
  pad <- strrep("    ", indent)
  flat <- .render(x, ascii = FALSE)
  is_vector <- is.list(x) && !inherits(x, "julia_spec")
  if (.fits(pad, flat, width, x, is_vector)) {
    return(paste0(pad, flat))
  }
  if (is_vector) {
    return(.format_vector(x, width, indent, pad))
  }
  .format_call(x, width, indent, pad)
}

#' Does a value belong on one line?
#'
#' Either because it fits, or because there is nothing to break it into:
#' verbatim Julia code and plain values render as they are.
#'
#' @inheritParams .format_code
#' @param pad The indentation of the value.
#' @param flat The value rendered on one line.
#' @param is_vector Whether the value renders as a Julia vector.
#' @return `TRUE` when the value goes on one line.
#' @noRd
.fits <- function(pad, flat, width, x, is_vector) {
  breakable <- is_vector || inherits(x, "julia_spec")
  nchar(pad) + nchar(flat) <= width || inherits(x, "julia_code") || !breakable
}

#' Format a vector over several lines
#'
#' @inheritParams .format_code
#' @param pad The indentation of the vector itself.
#' @return Character vector of lines.
#' @noRd
.format_vector <- function(x, width, indent, pad) {
  elements <- lapply(seq_along(x), function(i) {
    .format_code(
      x[[i]], width = .arg_width(width, i, length(x), ""),
      indent = indent + 1L
    )
  })
  c(paste0(pad, "["), .join_lines(elements), paste0(pad, "]"))
}

#' The width available to one argument of several
#'
#' `.join_lines()` appends a separator to every argument but the last, so an
#' argument that gains one has a character less to play with than the line
#' width allows.
#'
#' @inheritParams .format_code
#' @param i Position of this argument.
#' @param n Number of arguments.
#' @param last_sep Separator after the final argument.
#' @return The width this argument may occupy.
#' @noRd
.arg_width <- function(width, i, n, last_sep) {
  if (i < n || nzchar(last_sep)) width - 1L else width
}

#' Format a spec call over several lines
#'
#' @inheritParams .format_code
#' @param pad The indentation of the call itself.
#' @return Character vector of lines.
#' @noRd
.format_call <- function(x, width, indent, pad) {
  inner_pad <- strrep("    ", indent + 1L)
  n_args <- length(x$args)
  n_kwargs <- length(x$kwargs)
  args_sep <- if (n_kwargs > 0) ";" else ""
  positional <- lapply(seq_len(n_args), function(i) {
    .format_code(
      x$args[[i]], width = .arg_width(width, i, n_args, args_sep),
      indent = indent + 1L
    )
  })
  kw_names <- names(x$kwargs)
  kwargs <- lapply(seq_len(n_kwargs), function(i) {
    budget <- .arg_width(width, i, n_kwargs, "") - nchar(kw_names[i]) - 3L
    formatted <- .format_code(x$kwargs[[i]], budget, indent + 1L)
    formatted[1] <- paste0(
      inner_pad, kw_names[i], " = ", trimws(formatted[1], "left")
    )
    formatted
  })
  opening <- if (n_args == 0 && n_kwargs > 0) "(;" else "("
  c(
    paste0(pad, x$fn, opening),
    .join_lines(positional, args_sep),
    .join_lines(kwargs),
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

#' Check that an argument is a spec of an accepted role
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
#' transform <- julia_spec("LogTransform", .role = "transform")
#' assert_role(transform, "transform")
#' try(assert_role(transform, "model"))
assert_role <- function(
  x, roles, null_ok = FALSE, arg_name = deparse(substitute(x)), labels = NULL
) {
  # A spec or an expression with no role says nothing about what it is,
  # so any role accepts it: the caller has said what it is by writing it.
  untyped <- identical(class(x), c("julia_code", "julia_spec")) ||
    identical(class(x), "julia_spec")
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
  paste(article, role, "spec")
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
      !grepl("^[\\p{L}_][\\p{L}\\p{N}_.]*\\z", role, perl = TRUE)) {
    stop(
      "`.role` must be a single name, such as \"prior\" or \"model\", ",
      "using letters, digits, `.` and `_`.",
      call. = FALSE
    )
  }
  # A role becomes a class suffix, and these two are the package's own.
  if (role %in% c("code", "spec")) {
    stop(
      "`.role` cannot be \"", role, "\", which juliabridge uses for its own ",
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
  # Letters from any script, as for keyword names, and a dot only between two
  # identifiers, so that a module-qualified name passes while `F.`, which
  # Julia reads as a broadcast call, does not.
  identifier <- "[\\p{L}_][\\p{L}\\p{N}_!]*"
  # Anchored with `\\z`, since PCRE's `$` also matches before a final
  # newline, and a name ending in one renders two Julia expressions.
  pattern <- paste0("^", identifier, "(\\.", identifier, ")*\\z")
  if (!is.character(x) || length(x) != 1 || is.na(x) ||
      !grepl(pattern, x, perl = TRUE)) {
    stop(
      "`", arg_name, "` must be a single name that Julia can read, ",
      "such as \"Normal\" or \"MyModule.build\".",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' @export
format.julia_spec <- function(x, width = 78L, ...) {
  .format_code(x, width = width)
}

#' @export
print.julia_spec <- function(x, ...) {
  role <- sub("^julia_", "", class(x)[1])
  label <- switch(role,
    code = "code",
    spec = "spec",
    paste(role, "spec")
  )
  cat("<julia ", label, ">\n", sep = "")
  # Through `format()`, so that a package registering a method for its own
  # role class sees it used here too.
  cat(format(x, ...), sep = "\n")
  invisible(x)
}
