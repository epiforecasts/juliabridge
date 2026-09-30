# Julia version a Manifest was resolved with

A `Manifest.toml` records the Julia version that resolved it and pins
standard-library versions that only exist on that version. A package
shipping a pinned project needs that Julia version to instantiate
cleanly.

## Usage

``` r
manifest_julia_version(project)
```

## Arguments

- project:

  Path to a Julia project directory containing a `Manifest.toml` or
  `Manifest-v<major>.<minor>.toml`.

## Value

The major and minor version as a string (e.g. `"1.12"`), or `NULL` when
there is no manifest or it records no version.

## Details

A versioned manifest (`Manifest-v1.12.toml`, supported from Julia 1.11)
takes precedence over `Manifest.toml` on the Julia version it names.
When any exist, the highest-versioned one is read. If it records no
Julia version, its file name supplies one.

## Examples

``` r
if (FALSE) { # \dontrun{
manifest_julia_version(system.file("julia", package = "MyPkg"))
} # }
```
