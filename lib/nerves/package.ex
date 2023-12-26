defmodule Nerves.Package do
  @moduledoc """
  Defines a Nerves package struct and helper functions.

  A Nerves package is a Mix application that defines the configuration for a
  Nerves system or Nerves toolchain. For more details, see the Nerves
  [system documentation](https://hexdocs.pm/nerves/systems.html#package-configuration)
  """

  alias Nerves.Artifact

  defstruct app: nil,
            path: nil,
            dep: nil,
            env: [],
            type: nil,
            version: nil,
            platform: nil,
            build_runner: nil,
            compilers: [],
            dep_opts: [],
            config: []

  @type t :: %__MODULE__{
          app: atom,
          path: binary,
          env: %{String.t() => String.t()},
          type:
            :system
            | :package
            | :toolchain
            | :system_platform
            | :toolchain_platform,
          dep:
            :project
            | :path
            | :hex
            | :git,
          platform: atom,
          build_runner: {module(), Keyword.t()},
          compilers: [atom],
          dep_opts: Keyword.t(),
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
    compilers = config[:compilers] || Mix.compilers()
    env = Map.new(config[:nerves_package][:env] || %{})

    unless type do
      Mix.shell().error(
        "The Nerves package #{app} does not define a type.\n\n" <>
          "Verify that the key exists in '#{config_path(path)}'.\n"
      )

      exit({:shutdown, 1})
    end

    platform = config[:nerves_package][:platform]
    build_runner = Artifact.build_runner(config)
    config = Enum.reject(config[:nerves_package], fn {k, _v} -> k in @required end)

    dep_opts =
      load_env_deps()
      |> Enum.find(%{}, &(&1.app == app))
      |> Map.get(:opts, [])
      |> Keyword.get(:nerves, [])

    %__MODULE__{
      app: app,
      type: type,
      env: env,
      platform: platform,
      build_runner: build_runner,
      compilers: compilers,
      dep_opts: dep_opts,
      dep: dep_type(app),
      path: path,
      version: version,
      config: config
    }
  end

  if Version.match?(System.version(), ">= 1.16.0") do
    defp load_env_deps() do
      Mix.Dep.Converger.converge(env: Mix.env())
    end
  else
    defp load_env_deps() do
      # deprecated in Elixir >= 1.16.0
      Mix.Dep.load_on_environment(env: Mix.env())
    end
  end

  @doc """
  Starts an interactive shell with the working directory set
  to the package path
  """
  @spec shell(Nerves.Package.t() | nil) :: :ok
  def shell(nil) do
    Mix.raise("Package is not loaded in your Nerves Environment.")
  end

  def shell(%{platform: nil, app: app}) do
    Mix.raise("Cannot start shell for #{app}")
  end

  def shell(pkg) do
    pkg.build_runner.shell(pkg)
  end

  @doc """
  Takes the path to the package and returns the path to its package config.
  """
  @spec config_path(String.t()) :: String.t()
  def config_path(path) do
    Path.join(path, @package_config)
  end

  @doc """
  Get Mix.Project config for an application
  """
  @spec config(Application.app(), Path.t()) :: Keyword.t()
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
          Mix.shell().raise("""
          Nerves configuration has moved from nerves.exs to mix.exs.

          Use `mix nerves.new` to regenerate your project's mix.exs and merge
          your code into the new project.
          """)

        nerves_package ->
          nerves_package
      end

    Keyword.put(project_config, :nerves_package, nerves_package)
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
