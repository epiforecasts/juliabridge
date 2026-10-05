# Changelog

## juliabridge 0.1.0

- Renamed from juliaready, ahead of the package also taking on the
  building of Julia calls from R objects. Consumers need to update both
  their `juliaready::` call sites and the `juliaready` entry in
  `Imports`/`Remotes`: installing from the old repository still works
  through GitHub’s redirect, but installs a package named `juliabridge`,
  so [`library(juliaready)`](https://github.com/sbfnk/juliaready) then
  reports that no such package exists.
- Added
  [`julia_spec()`](https://epiforecasts.io/juliabridge/reference/julia_spec.md),
  [`julia()`](https://epiforecasts.io/juliabridge/reference/julia.md),
  [`as_julia()`](https://epiforecasts.io/juliabridge/reference/as_julia.md),
  [`assert_role()`](https://epiforecasts.io/juliabridge/reference/assert_role.md)
  and the
  [`as_julia_value()`](https://epiforecasts.io/juliabridge/reference/as_julia_value.md)
  extension point, which describe a Julia constructor call in R and
  render it to Julia source. Moved here from composableIDModelR, where
  the same code builds composable epidemiological models, with the roles
  now supplied by the calling package rather than fixed.
- Initial version.
