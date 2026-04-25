# Contributing to GraphBLAS

## Development Setup

### Local Testing with Docker

To test the CI/CD pipeline locally before pushing:

```bash
./test-ci-local.sh
```

This runs the full test suite (format, lint, compile, tests) in an isolated Docker environment that matches GitHub Actions.

**Requirements**: Docker must be installed and running.

**First run**: The Docker image will be built (~5-10 minutes as it compiles GraphBLAS v9.4.5 from source).

### Manual Local Development

For day-to-day development without Docker:

```bash
# Install dependencies
mix deps.get

# Download Zig (if not already done)
mix zig.get

# Compile with warnings as errors
mix compile --warnings-as-errors

# Run tests
mix test

# Run linter
mix format --check-formatted
mix credo

# Run Dialyzer
mix dialyzer
```

## GitHub Actions Workflows

Three workflows run automatically on push/PR:

### 1. **Lint** (`.github/workflows/lint.yml`)
- **Purpose**: Code quality checks
- **Jobs**:
  - `lint`: Format, Credo, compile, docs, hex audit
  - `dialyzer`: Type checking via Dialyzer (with PLT caching)
- **Duration**: ~2-3 minutes
- **Triggers**: Push, Pull Request

### 2. **Build** (`.github/workflows/elixir-build.yml`)
- **Purpose**: Compile and test the library
- **Matrix**: Elixir 1.18.4 / OTP 27 (coverage enabled)
- **Steps**:
  1. Install build dependencies (clang, cmake, pkg-config, libomp-dev)
  2. Clone & build SuiteSparse:GraphBLAS v9.4.5 from source (cached)
  3. Download Zig toolchain (pinned by Zigler)
  4. Compile Elixir code with warnings as errors
  5. Verify NIFs compiled successfully
  6. Run full test suite (~470 tests)
  7. Generate coverage reports (via `mix coveralls.github`)
- **Duration**: ~11-12 minutes (mostly GraphBLAS build)
- **Caching**:
  - GraphBLAS installation (`/usr/local`) by platform/arch
  - Dependencies (`deps/`, `_build/`)
- **Triggers**: Push, Pull Request

### 3. **Precompiled NIFs** (`.github/workflows/precompiled-nifs.yml`)
- **Purpose**: Build and publish precompiled native code
- **Targets**: 6 platforms (aarch64/x86_64 × macOS/Linux-gnu/Linux-musl)
- **Steps**:
  1. Build NIFs for each target with `EX_GRAPHBLAS_BUILD=1`
  2. Create GitHub Release with NIF artifacts
  3. Publish to Hex.pm (via `mix zigler_precompiled.download`)
- **Duration**: ~30-40 minutes (6 targets in parallel)
- **Caching**: GraphBLAS source per platform
- **Triggers**: Push, Pull Request, Manual via `workflow_dispatch`

## GraphBLAS Build Strategy

GraphBLAS (v9.4.5) is built from source in CI because:

1. **Ubuntu 22.04** apt repos don't include `graphblas.pc` (needed by pkg-config)
2. **Source build** includes pkg-config support via `-DGRAPHBLAS_BUILD_PKGCONFIG=ON`
3. **Caching** at `/usr/local` per platform reduces rebuild time significantly

The `graphblas.pc` file is discovered via:
```bash
find /usr/local -type f -name 'graphblas.pc'
```

And `PKG_CONFIG_PATH` is set for downstream `pkg-config` queries.

## Local Debugging

If tests fail locally:

```bash
# Check compilation errors
mix compile

# Run tests with verbose output
mix test --verbose

# Run dialyzer for type issues
mix dialyzer --explain

# Check specific module/file
mix test test/ex_graphblas/matrix_test.exs
```

## Before Committing

1. **Run tests locally** or via Docker:
   ```bash
   ./test-ci-local.sh
   ```

2. **Format code**:
   ```bash
   mix format
   ```

3. **Check types**:
   ```bash
   mix dialyzer
   ```

4. **Verify warnings**:
   ```bash
   mix compile --warnings-as-errors
   ```

## Commit Message Style

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>
```

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `ci`, `chore`

**Examples**:
- `feat(matrix): add transpose operation`
- `fix(backend): correct type spec for error handling`
- `ci: add Docker setup for local CI testing`

## Release Process

Currently deferred—Phase 8 work in progress. See `.github/workflows/precompiled-nifs.yml` for planned release automation.

---

**Questions?** Open an issue on GitHub.
