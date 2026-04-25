# GraphBLAS Configuration
#
# This configuration file sets application-level defaults.
# Environment-specific overrides go in config/#{env}.exs.
#
# Backend selection:
#   GraphBLAS.Backend.Elixir       - Pure Elixir reference backend.
#                                    Correct but not performant. Suitable for
#                                    testing and development. This is the default
#                                    for safety.
#
#   GraphBLAS.Backend.SuiteSparse  - SuiteSparse:GraphBLAS via Zigler.
#                                    High-performance native backend. Requires
#                                    SuiteSparse:GraphBLAS C library installed.
#
# To override at runtime, set:
#   config :ex_graphblas, :default_backend, GraphBLAS.Backend.Elixir
#
# SuiteSparse include path:
#   Set SUITESPARSE_INCLUDE_PATH env variable or :suitesparse_include_path
#   config key to override the default path for your platform.
#   Defaults:
#     macOS (Homebrew): /opt/homebrew/include/suitesparse
#     Linux:            /usr/include/suitesparse
#     Linux (local):    /usr/local/include/suitesparse

import Config

config :ex_graphblas,
  default_backend: GraphBLAS.Backend.Elixir

import_config "#{config_env()}.exs"
