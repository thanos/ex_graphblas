defmodule GraphBLAS.MixProject do
  use Mix.Project

  @moduledoc """
  Mix project configuration for GraphBLAS.

  GraphBLAS is an Elixir library for sparse linear algebra and graph
  computation inspired by the GraphBLAS model. It provides idiomatic
  Elixir data structures at the boundary while delegating computation
  to swappable backends (initially SuiteSparse:GraphBLAS via Zigler).
  """

  @version "0.2.0-dev"
  @source_url "https://github.com/thanos/ex_graphblas"

  def project do
    [
      app: :ex_graphblas,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: [
        verify: &verify/1
      ],
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/project.plt"},
        plt_add_apps: [:mix]
      ],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      docs: [
        main: "GraphBLAS",
        extras: ["README.md", "LICENSE"]
      ],
      package: package(),
      description: description(),
      homepage_url: "https://github.com/thanos/ex_graphblas"
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
      {:zigler_precompiled, "~> 0.1"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:benchee, "~> 1.3", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:stream_data, "~> 1.1", only: [:dev, :test]},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "bench"]
  defp elixirc_paths(_), do: ["lib"]

  defp description do
    "Sparse linear algebra and graph computation in Elixir, inspired by the GraphBLAS standard."
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      maintainers: ["Thanos Vassilakis"],
      links: %{"GitHub" => @source_url},
      # files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md),
      exclude_patterns: ["bench", "docs", "guides", "plans", "prompts"]
    ]
  end

  defp verify(_) do
    steps = [
      # ["precommit", :dev],
      {"compile --warnings-as-errors", :dev},
      {"format --check-formatted", :dev},
      {"credo --strict", :dev},
      # {"sobelow --config", :dev},
      {"dialyzer", :dev},
      {"test --cover", :test},
      {"docs --warnings-as-errors", :dev}
    ]

    Enum.each(steps, fn {task, env} ->
      Mix.shell().info(IO.ANSI.format([:bright, "==> mix #{task}", :reset]))

      mix_executable =
        System.find_executable("mix") ||
          Mix.raise("Could not find `mix` executable on PATH")

      {_, exit_code} =
        System.cmd(mix_executable, String.split(task),
          env: [{"MIX_ENV", to_string(env)}],
          into: IO.stream(:stdio, :line),
          stderr_to_stdout: true
        )

      if exit_code != 0 do
        Mix.raise("mix #{task} failed (exit code #{exit_code})")
      end
    end)

    Mix.shell().info(
      IO.ANSI.format([:green, :bright, "\nAll verification checks passed!", :reset])
    )
  end
end
