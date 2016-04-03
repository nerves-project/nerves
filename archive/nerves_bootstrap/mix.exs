defmodule Nerves.Bootstrap.Mixfile do
  use Mix.Project

  def project do
    [app: :nerves_bootstrap,
     version: "0.0.1",
     elixir: "~> 1.2"]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: []]
  end

end
