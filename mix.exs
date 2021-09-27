defmodule HXL.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/drowzy/hcl"
  def project do
    [
      app: :hxl,
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      description: "HCL implementation for Elixir",
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    %{
      files: ["lib", "src", "mix.exs", "README.md"],
      maintainers: ["Simon Thörnqvist"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url
      }
    }
  end

  defp docs do
    [
      main: "HXL",
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_parsec, "~> 1.1"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false}
    ]
  end
end
