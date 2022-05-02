defmodule Nerves.MixProject do
  use Mix.Project

  @version "1.7.16"
  @source_url "https://github.com/nerves-project/nerves"

  def project do
    [
      app: :nerves,
      version: @version,
      elixir: "~> 1.11.2 or ~> 1.12.0 or ~> 1.13.0",
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
      dialyzer: [plt_add_apps: [:mix]],
      preferred_cli_env: %{
        credo: :test,
        docs: :docs,
        "hex.publish": :docs,
        "hex.build": :docs
      }
    ]
  end

  def application do
    [extra_applications: [:ssl, :inets, :eex]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:castore, "~> 0.1"},
      {:elixir_make, "~> 0.6", runtime: false},
      {:jason, "~> 1.2", optional: true},
      {:credo, "~> 1.6", only: :test, runtime: false},
      {:ex_doc, "~> 0.22", only: :docs, runtime: false},
      {:dialyxir, "~> 1.0", only: [:test, :dev], runtime: false},
      {:nerves_bootstrap, "~> 1.8", only: [:test, :dev, :docs]},
      {:plug, "~> 1.10", only: :test},
      {:mime, "~> 1.6", only: :test},
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
        "docs/IEx with Nerves.md",
        "docs/User Interfaces.md",
        "docs/Environment Variables.md",
        "docs/Compiling Non-BEAM Code.md",
        "docs/Advanced Configuration.md",
        "docs/Updating Projects.md",
        "docs/Internals.md",
        "docs/Customizing Systems.md",
        "docs/Experimental Features.md",
        "CHANGELOG.md"
      ],
      groups_for_functions: [
        "Used By NervesBootstrap": &(&1[:used_by] == NervesBootstrap)
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
        "src",
        "Makefile"
      ],
      licenses: ["Apache-2.0"],
      links: %{
        "Home page" => "https://www.nerves-project.org/",
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      }
    ]
  end
end
