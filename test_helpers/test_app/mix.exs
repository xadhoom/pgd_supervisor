defmodule TestApp.MixProject do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :test_app,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {TestApp.Application, []}
    ]
  end

  defp deps do
    []
  end
end
