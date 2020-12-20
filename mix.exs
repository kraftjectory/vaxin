defmodule Vaxin.MixProject do
  use Mix.Project

  @name "Vaxin"
  @version "0.1.0"
  @source_url "https://github.com/kraftjectory/vaxin"

  def project() do
    [
      app: :vaxin,
      version: @version,
      elixir: "~> 1.6",
      deps: deps(),
      description: descriptions(),
      package: package(),
      name: @name,
      docs: [
        main: @name,
        source_ref: "v#{@version}",
        source_url: @source_url,
        extras: [
          "README.md",
          "CHANGELOG.md"
        ]
      ]
    ]
  end

  defp package() do
    [
      licenses: ["ISC"],
      links: %{"GitHub" => "https://github.com/kraftjectory/vaxin"}
    ]
  end

  def application(), do: []

  defp descriptions() do
    "A data validator combinator library for Elixir"
  end

  defp deps() do
    [
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
