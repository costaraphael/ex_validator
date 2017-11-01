defmodule Validator.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_validator,
      version: "0.1.1",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),

      # Coverage
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.detail": :test, "coveralls.html": :test],

      # Docs
      name: "ExValidator",
      source_url: "https://github.com/costaraphael/ex_validator"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:excoveralls, "~> 0.7", only: :test, runtime: false},
      {:ex_doc, "~> 0.16", only: :dev, runtime: false},
      {:dialyxir, "~> 0.5", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Helpers for validating and normalizing Elixir data structures.
    """
  end

  defp package do
    [
      name: "ex_validator",
      maintainers: ["Raphael Costa"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/costaraphael/ex_validator"}
    ]
  end
end
