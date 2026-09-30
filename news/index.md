# Changelog

## juliabridge 0.1.0

- Renamed from juliaready, ahead of the package also taking on the
  building of Julia calls from R objects. Consumers need to update both
  their `juliaready::` call sites and the `juliaready` entry in
  `Imports`/`Remotes`: installing from the old repository still works
  through GitHub’s redirect, but installs a package named `juliabridge`,
  so [`library(juliaready)`](https://github.com/sbfnk/juliaready) then
  reports that no such package exists.
- Initial version.
