defmodule CoverHelper.MixProject do
  use Mix.Project

  def project do
    [
      app: :cover_helper,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:tools]
    ]
  end

  defp deps do
    []
  end
end
