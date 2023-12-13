defmodule PgdSupervisor.MixProject do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :pgd_supervisor,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      # elixirc_options: [warnings_as_errors: true],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      source_url: "https://github.com/VoiSmart/pgd_supervisor.git",
      homepage_url: "https://github.com/VoiSmart/pgd_supervisor.git",
      description: description(),
      name: "PgdSupervisor",
      docs: docs(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp aliases do
    [
      test: "test --no-start"
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description do
    """
    A dynamic, distributed supervisor for clustered Elixir applications.
    """
  end

  defp package do
    [
      maintainers: [
        "Flavio Grossi <flavio.grossi@voismart.it>",
        "Matteo Brancaleoni <matteo.brancaleoni@voismart.it>"
      ],
      licenses: ["LGPL-3.0-only"],
      links: %{"GitHub" => "https://github.com/VoiSmart/pgd_supervisor.git"},
      files: ~w"lib mix.exs README.md LICENSE.md"
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "LICENSE.md"]
    ]
  end

  defp deps do
    [
      {:syn, "~> 3.3"},
      {:libring, "~> 1.6"},
      {:uuid, "~> 1.1"},
      {:local_cluster, "~> 1.2", only: [:test]},
      {:ex_doc, "~> 0.30", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:test_app, path: "test_helpers/test_app", only: [:test]}
    ]
  end
end
