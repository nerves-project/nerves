defmodule Nerves.MixProject do
  use Mix.Project

  @version "1.6.3"
  @source_url "https://github.com/nerves-project/nerves"

  def project do
    [
      app: :nerves,
      version: @version,
      elixir: "~> 1.7.3 or ~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      description: description(),
      package: package(),
      build_embedded: true,
      compilers: [:elixir_make | Mix.compilers()],
      make_targets: ["all"],
      make_clean: ["clean"],
      aliases: [docs: ["docs", &copy_images/1]],
      docs: docs(),
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  def application do
    [extra_applications: [:ssl, :inets]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:elixir_make, "~> 0.6", runtime: false},
      {:distillery, "~> 2.1", optional: true, runtime: false},
      {:jason, "~> 1.2", optional: true},
      {:ex_doc, "~> 0.22", only: [:test, :dev], runtime: false},
      {:dialyxir, "~> 1.0", only: [:test, :dev], runtime: false},
      {:nerves_bootstrap, "~> 1.8", only: [:test, :dev]},
      {:plug, "~> 1.10", only: :test},
      {:plug_cowboy, "~> 1.0 or ~> 2.0", only: :test}
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
        "docs/Internals.md",
        "docs/Customizing Systems.md",
        "CHANGELOG.md"
      ],
      source_ref: "v#{@version}",
      source_url: @source_url,
      skip_undefined_reference_warnings_on: ["docs/Updating Projects.md", "CHANGELOG.md"]
    ]
  end

  # Copy the images referenced by docs, since ex_doc doesn't do this.
  defp copy_images(_) do
    File.cp_r("resources", "doc/resources")
  end

  defp description do
    "Craft and deploy bulletproof embedded software"
  end

  defp package do
    [
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
      links: %{"Home page" => "https://www.nerves-project.org/", "GitHub" => @source_url}
    ]
  end
end
