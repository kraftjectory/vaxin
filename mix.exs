defmodule Vaxin.MixProject do
  use Mix.Project

  def project() do
    [
      app: :vaxin,
      version: "0.1.0",
      elixir: "~> 1.6",
      deps: deps()
    ]
  end

  def application(), do: []

  defp deps() do
    [
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
