defmodule Nerves.Package do
  @moduledoc """
  Defines a Nerves package struct and helper functions.

  A Nerves package is a Mix application that defines the configuration for a
  Nerves system or Nerves toolchain. For more details, see the Nerves
  [system documentation](https://hexdocs.pm/nerves/systems.html#package-configuration)
  """

  defstruct app: nil,
            path: nil,
            dep: nil,
            type: nil,
            version: nil,
            platform: nil,
            provider: nil,
            config: []

  alias __MODULE__
  alias Nerves.Artifact

  @type t :: %__MODULE__{
          app: atom,
          path: binary,
          type:
            :system
            | :package
            | :toolchain,
          dep:
            :project
            | :path
            | :hex
            | :git,
          platform: atom,
          provider: atom,
          version: Version.t(),
          config: Keyword.t()
        }

  @package_config "nerves.exs"
  @required [:type, :version, :platform]

  @doc """
  Loads the package config and parses it into a `%Package{}`
  """
  @spec load_config({app :: atom, path :: String.t()}) :: Nerves.Package.t()
  def load_config({app, path}) do
    config = config(app, path)
    version = config[:version]
    type = config[:nerves_package][:type]

    unless type do
      Mix.shell().error(
        "The Nerves package #{app} does not define a type.\n\n" <>
          "Verify that the key exists in '#{config_path(path)}'.\n"
      )

      exit({:shutdown, 1})
    end

    platform = config[:nerves_package][:platform]
    provider = Artifact.provider(config)
    config = Enum.reject(config[:nerves_package], fn {k, _v} -> k in @required end)

    %Package{
      app: app,
      type: type,
      platform: platform,
      provider: provider,
      dep: dep_type(app),
      path: path,
      version: version,
      config: config
    }
  end

  @doc """
  Starts an interactive shell with the working directory set
  to the package path
  """
  @spec shell(Nerves.Package.t()) :: :ok
  def shell(nil) do
    Mix.raise("Package is not loaded in your Nerves Environment.")
  end

  def shell(%{platform: nil, app: app}) do
    Mix.raise("Cannot start shell for #{app}")
  end

  def shell(pkg) do
    pkg.provider.shell(pkg)
  end

  @doc """
  Takes the path to the package and returns the path to its package config.
  """
  @spec config_path(String.t()) :: String.t()
  def config_path(path) do
    Path.join(path, @package_config)
  end

  def config(app, path) do
    project_config =
      if app == Mix.Project.config()[:app] do
        Mix.Project.config()
      else
        Mix.Project.in_project(app, path, fn _mod ->
          Mix.Project.config()
        end)
      end

    nerves_package =
      case project_config[:nerves_package] do
        nil ->
          # TODO: Deprecated. Clean up after 1.0
          load_nerves_config(path)
          config = Application.get_env(app, :nerves_env)

          Mix.shell().error("""
          Nerves config has moved from nerves.exs to mix.exs.

          For Example:

          ## nerves.exs
            config #{project_config[:app]}, :nerves_env,
              type: #{config[:type]}
              # ...

          ## mix.exs

            def project do
              [app: #{project_config[:app]},
               version: #{project_config[:version]},
               nerves_package: nerves_package()
               # ...
              ]
            end

            def nerves_package do
              [type: #{config[:type]}
              # ...
              ]
            end
          """)

          config

        nerves_package ->
          nerves_package
      end

    Keyword.put(project_config, :nerves_package, nerves_package)
  end

  defp load_nerves_config(path) do
    config_path(path)
    |> Mix.Config.read!()
    |> Mix.Config.persist()
  end

  defp dep_type(pkg) do
    deps_paths = Mix.Project.deps_paths()

    case Map.get(deps_paths, pkg) do
      nil ->
        :project

      path ->
        deps_path =
          File.cwd!()
          |> Path.join(Mix.Project.config()[:deps_path])
          |> Path.expand()

        if String.starts_with?(path, deps_path) do
          :hex
        else
          :path
        end
    end
  end
end
