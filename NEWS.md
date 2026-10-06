# juliabridge 0.1.0

* Renamed from juliaready, ahead of the package also taking on the
  building of Julia calls from R objects. Consumers need to update both
  their `juliaready::` call sites and the `juliaready` entry in
  `Imports`/`Remotes`: installing from the old repository still works
  through GitHub's redirect, but installs a package named `juliabridge`,
  so `library(juliaready)` then reports that no such package exists.
* Added `julia_spec()`, `julia()`, `as_julia()`, `assert_role()` and the
  `as_julia_value()` extension point, which describe a Julia constructor call
  in R and render it to Julia source. Moved here from composableIDModelR,
  where the same code builds composable epidemiological models, with the roles
  now supplied by the calling package rather than fixed.
* A keyword argument of a spec can be read back and set by name with `$`, as
  in `julia_spec("Solver", tol = 1e-8)$tol`. It used to read as `NULL`, since
  the spec holds its keyword arguments in `$kwargs` (#17).
* Initial version.
