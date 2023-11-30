defmodule PgdSupervisor.MixProject do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :pgd_supervisor,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:libring, "~> 1.6"},
      {:local_cluster, "~> 1.2", only: [:test]},
      {:ex_doc, "~> 0.30", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
