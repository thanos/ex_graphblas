import Config

config :ex_graphblas,
  default_backend: GraphBLAS.Backend.Elixir

# Tests use the Elixir reference backend by default and don't require
# NIFs to be built. Precompiled NIFs will be downloaded if needed for
# SuiteSparse backend tests, but we don't force local builds in test mode.
config :zigler_precompiled,
  force_build_all: true

config :zigler_precompiled, :force_build, ex_graphblas: true
