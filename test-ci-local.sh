#!/bin/bash
# Test CI/CD locally with Docker

set -e

DOCKER_IMAGE="ex_graphblas:ci-test"
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "Building Docker image for CI testing..."
docker build -f "$REPO_ROOT/Dockerfile.ci" -t "$DOCKER_IMAGE" "$REPO_ROOT"

echo ""
echo "Running CI tests in Docker container..."
docker run --rm \
  -v "$REPO_ROOT:/src:ro" \
  -w /workspace \
  -e MIX_ENV=test \
  -e PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig" \
  "$DOCKER_IMAGE" \
  bash -c '
    set -e

    # Work on a clean copy of the repo so host _build/ and deps/ from
    # a different OTP/Elixir dont confuse protocol compilation.
    mkdir -p /workspace
    cp -R /src/. /workspace

    echo "Installing Elixir dependencies..."
    mix deps.get --force
    
    echo "Downloading Zig..."
    mix zig.get
    
    echo "Compiling with warnings as errors..."
    mix compile --warnings-as-errors
    
    echo "Verifying NIFs compiled..."
    find _build -maxdepth 5 -type f \( -name "*.so" -o -name "*.dylib" \) -print || echo "No prebuilt NIFs found"
    
    echo "Running tests..."
    mix test
  '

echo ""
echo "✓ CI tests passed locally!"
