# GraphBLAS Configuration
#
# This configuration file sets application-level defaults.
# Environment-specific overrides go in config/#{env}.exs.
#
# Backend selection:
#   :reference  - Pure Elixir reference backend (no native dependency).
#                  Correct but not performant. Suitable for testing and
#                  development. This is the default for safety.
#
#   :suite_sparse - SuiteSparse:GraphBLAS via Zigler (Phase 2).
#                    High-performance native backend. Not yet available.
#
# To override at runtime, set:
#   config :ex_graphblas, :default_backend, GraphBLAS.Backend.Elixir

import Config

config :ex_graphblas,
  default_backend: GraphBLAS.Backend.Elixir

import_config "#{config_env()}.exs"
