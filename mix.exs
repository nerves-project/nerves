defmodule Nerves.Mixfile do
  use Mix.Project

  def project do
    [app: :nerves,
     name: "Nerves",
     source_url: "https://github.com/nerves-project/nerves",
     homepage_url: "http://nerves-project.org/",
     version: "0.5.1",
     archives: [nerves_bootstrap: "~> 0.3.0"],
     elixir: "~> 1.4.0",
     elixirc_paths: elixirc_paths(Mix.env),
     deps: deps(),
     description: description(),
     package: package(),
     aliases: ["docs": ["docs", &copy_images/1]],
     docs: docs()]
  end

  def application do
    [extra_applications: [:ssl, :inets]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp deps do
    [
      {:distillery, "~> 1.0"},
      {:earmark, "~> 1.0", only: :dev},
      {:ex_doc, "~> 0.14", only: :dev},
      {:nerves_bootstrap, path: "bootstrap", only: [:test, :dev]}
    ]
  end

  defp docs do
    [main: "getting-started",
     logo: "resources/logo.png",
     extras: [
        "docs/Installation.md",
        "docs/Getting Started.md",
        "docs/FAQ.md",
        "docs/Targets.md",
        "docs/Systems.md",
        "docs/User Interfaces.md",
        "docs/Advanced Configuration.md"
    ]]
  end

  # Copy the images referenced by docs, since ex_doc doesn't do this.
  defp copy_images(_) do
    File.cp_r "resources", "doc/resources"
  end

  defp description do
    """
    Nerves - Create firmware for embedded devices like Raspberry Pi, BeagleBone Black, and more
    """
  end

  defp package do
    [maintainers: ["Frank Hunleth", "Garth Hitchens", "Justin Schneck", "Greg Mefford"],
     files: ["lib", "LICENSE", "mix.exs", "README.md", "template", "scripts", "priv"],
     licenses: ["Apache 2.0"],
     links: %{"Github" => "https://github.com/nerves-project/nerves"}]
  end
end
