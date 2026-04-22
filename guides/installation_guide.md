# Installation Guide

This guide covers installing ex_graphblas and its native dependencies.

## Prerequisites

- Elixir >= 1.18
- Erlang/OTP >= 27
- A C compiler (gcc or clang)
- Zig (managed by Zigler dependency)
- SuiteSparse:GraphBLAS (for native backend only)

## Basic installation (Elixir backend only)

If you only need the pure Elixir reference backend, no C dependencies are required:

```elixir
# mix.exs
def deps do
  [{:ex_graphblas, "~> 0.2.0"}]
end
```

```bash
mix deps.get
mix compile
```

The Elixir backend is the default. It works without any native libraries.

## SuiteSparse native backend installation

The SuiteSparse backend provides high-performance sparse operations via the SuiteSparse:GraphBLAS C library. It requires additional system-level dependencies.

### macOS (Homebrew)

```bash
brew install suite-sparse
```

SuiteSparse headers install to `/opt/homebrew/include/suitesparse`. This is the default include path.

### Linux (Debian/Ubuntu)

```bash
sudo apt-get install libsuitesparse-dev
```

Headers install to `/usr/include/suitesparse`.

### Linux (Fedora/RHEL)

```bash
sudo dnf install suitesparse-devel
```

### Linux (Nix)

```nix
# shell.nix
with import <nixpkgs> {};
mkShell {
  buildInputs = [ elixir suitesparse ];
  SUITESPARSE_INCLUDE_PATH = "${suitesparse}/include/suitesparse";
}
```

### From source

If SuiteSparse is not available via package manager:

```bash
git clone https://github.com/DrTimothyAldenDavis/SuiteSparse.git
cd SuiteSparse
make library
sudo make install
```

Default install prefix is `/usr/local`. Headers go to `/usr/local/include/suitesparse`.

## Configuring the include path

The SuiteSparse include path is configured via an environment variable read at compile time.

### Default paths

The library checks the following defaults based on platform:

| Platform | Default path |
|----------|-------------|
| macOS (Homebrew) | `/opt/homebrew/include/suitesparse` |
| macOS (Homebrew, Intel) | `/usr/local/include/suitesparse` |
| Linux | `/usr/include/suitesparse` |
| Linux (local install) | `/usr/local/include/suitesparse` |

### Override via environment variable

If SuiteSparse is installed to a non-standard location:

```bash
SUITESPARSE_INCLUDE_PATH=/custom/path/include/suitesparse mix compile
```

### Override via config

In `config/config.exs`:

```elixir
config :ex_graphblas,
  suitesparse_include_path: "/custom/path/include/suitesparse"
```

## Selecting a backend

### Default backend (config)

```elixir
# config/config.exs
config :ex_graphblas,
  default_backend: GraphBLAS.Backend.Elixir       # default, no native dependency
  # default_backend: GraphBLAS.Backend.SuiteSparse  # requires SuiteSparse
```

### Per-call backend

```elixir
# Use SuiteSparse for a specific operation
{:ok, m} = GraphBLAS.Matrix.from_coo(100, 100, entries, :int64,
  backend: GraphBLAS.Backend.SuiteSparse
)
```

## Verifying the installation

### Check Elixir backend

```elixir
iex -S mix
{:ok, m} = GraphBLAS.Matrix.from_coo(3, 3, [{0, 1, 1}, {1, 2, 2}], :int64)
{:ok, entries} = GraphBLAS.Matrix.to_coo(m)
# Should return [{0, 1, 1}, {1, 2, 2}]
```

### Check SuiteSparse backend

```elixir
iex -S mix
{:ok, m} = GraphBLAS.Matrix.from_coo(3, 3, [{0, 1, 1}, {1, 2, 2}], :int64,
  backend: GraphBLAS.Backend.SuiteSparse
)
{:ok, entries} = GraphBLAS.Matrix.to_coo(m)
# Should return [{0, 1, 1}, {1, 2, 2}]
GraphBLAS.Backend.SuiteSparse.matrix_free(m)
```

If the SuiteSparse backend fails to load, verify:
1. SuiteSparse:GraphBLAS is installed (`ldconfig -p | grep graphblas` on Linux)
2. The include path is correct
3. Zigler can find the C headers at compile time

## Troubleshooting

### "SuiteSparse headers not found"

The Zigler NIF cannot find `GraphBLAS.h`. Set the include path:

```bash
SUITESPARSE_INCLUDE_PATH=/usr/include/suitesparse mix compile
```

### "undefined NIF function"

The native library did not compile or load. Run:

```bash
mix compile --force
```

Check the compilation output for Zig/C errors. Common causes:
- SuiteSparse not installed
- Wrong include path
- Incompatible SuiteSparse version (requires >= 7.0)

### "function clause error" on Vector.nvals with SuiteSparse

This was a bug in earlier versions where inspection functions dispatched to the wrong backend. Fixed in 0.2.0 via the `backend` field in structs. Ensure you are running >= 0.2.0.

### BEAM VM crashes during SuiteSparse operations

SuiteSparse NIFs run on dirty CPU schedulers. If the BEAM VM crashes:
1. Ensure your Erlang runtime has dirty scheduler support (OTP >= 20)
2. Check that `erl +SDcpu` is not set to 0
3. The NIF may be accessing freed resources -- ensure `maybe_free/2` is called correctly in iterative algorithms

## Running the benchmarks

```bash
# All benchmarks
mix run bench/run_all.exs

# Specific benchmark
mix run bench/phase6_algorithms_benchmarks.exs
mix run bench/core_ops_benchmarks.exs
```

Benchmarks require both backends to be operational.
