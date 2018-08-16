defmodule Nerves.Mixfile do
  use Mix.Project

  def project do
    [
      app: :nerves,
      name: "Nerves",
      source_url: "https://github.com/nerves-project/nerves",
      homepage_url: "http://nerves-project.org/",
      version: "1.3.0",
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      description: description(),
      package: package(),
      aliases: [docs: ["docs", &copy_images/1]],
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:ssl, :inets]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:distillery, "~> 2.0"},
      {:jason, "~> 1.0", optional: true},
      {:ex_doc, "~> 0.18.0", only: [:test, :dev]},
      {:nerves_bootstrap, "~> 1.0", only: [:test, :dev]},
      {:plug, "~> 1.4", only: :test},
      {:cowboy, "~> 1.1", only: :test}
    ]
  end

  defp docs do
    [
      main: "getting-started",
      logo: "resources/logo.png",
      extras: [
        "docs/Installation.md",
        "docs/Getting Started.md",
        "docs/FAQ.md",
        "docs/Targets.md",
        "docs/Systems.md",
        "docs/User Interfaces.md",
        "docs/Advanced Configuration.md",
        "docs/Updating Projects.md",
        "docs/Internals.md"
      ]
    ]
  end

  # Copy the images referenced by docs, since ex_doc doesn't do this.
  defp copy_images(_) do
    File.cp_r("resources", "doc/resources")
  end

  defp description do
    """
    Nerves - Create firmware for embedded devices like Raspberry Pi, BeagleBone Black, and more
    """
  end

  defp package do
    [
      maintainers: ["Justin Schneck", "Frank Hunleth", "Greg Mefford"],
      files: [
        "CHANGELOG.md",
        "lib",
        "LICENSE",
        "mix.exs",
        "README.md",
        "scripts",
        "priv"
      ],
      licenses: ["Apache 2.0"],
      links: %{"Github" => "https://github.com/nerves-project/nerves"}
    ]
  end
end
