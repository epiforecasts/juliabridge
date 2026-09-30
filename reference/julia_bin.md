# Find the Julia binary

Resolves the Julia binary path, used by `julia_subprocess()` to run
subprocess work (installing packages into the default depot) before
starting the JuliaConnectoR server.

## Usage

``` r
julia_bin()
```

## Value

Absolute path to the Julia executable, or `""` if not found.

## Details

Detection order:

1.  `JULIACONNECTOR_JULIABIN` env var (JuliaConnectoR's preferred
    mechanism).

2.  `JULIA_BINDIR` env var (Julia's own;
    `joinpath(JULIA_BINDIR, "julia")`).

3.  The `julia` on the `PATH` (`Sys.which("julia")`).
