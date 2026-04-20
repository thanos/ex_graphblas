defmodule GraphBLAS.MixProject do
  use Mix.Project

  @moduledoc """
  Mix project configuration for GraphBLAS.

  GraphBLAS is an Elixir library for sparse linear algebra and graph
  computation inspired by the GraphBLAS model. It provides idiomatic
  Elixir data structures at the boundary while delegating computation
  to swappable backends (initially SuiteSparse:GraphBLAS via Zigler).
  """

  def project do
    [
      app: :ex_graphblas,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      docs: [
        main: "GraphBLAS",
        extras: ["README.md"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {GraphBLAS.Application, []}
    ]
  end

  defp deps do
    [
      {:zigler, "~> 0.15"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:benchee, "~> 1.3", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
