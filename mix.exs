defmodule Nerves.Mixfile do
  use Mix.Project

  def project do
    [app: :nerves,
     name: "Nerves",
     source_url: "https://github.com/nerves-project/nerves",
     homepage_url: "http://nerves-project.org/",
     version: "0.2.0",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     description: description,
     package: package,
     docs: [logo: "resources/logo.png",
          extras: ["README.md"]]]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    []
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:exrm, "~> 1.0"},
      {:earmark, "~> 0.1", only: :dev},
      {:ex_doc, "~> 0.11", only: :dev},
      {:porcelain, "~> 2.0"}
    ]
  end

  defp description do
    """
    Nerves - Create firmware for embedded devices like Raspberry Pi, BeagleBone Black, and more
    """
  end

  defp package do
    [maintainers: ["Frank Hunleth", "Garth Hitchens", "Justin Schneck"],
     licenses: ["Apache 2.0"],
     links: %{"Github" => "https://github.com/nerves-project/nerves"}]
  end
end
