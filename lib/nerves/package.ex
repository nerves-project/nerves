defmodule Nerves.Package do
  @moduledoc """
  Defines a Nerves package struct and helper functions.

  A Nerves package is a Mix application that defines the configuration for a
  Nerves system or Nerves toolchain. For more details, see the Nerves
  [system documentation](https://hexdocs.pm/nerves/systems.html#package-configuration)
  """

  defstruct [app: nil, path: nil, dep: nil, type: nil, version: nil, platform: nil, provider: nil, config: []]

  alias __MODULE__
  alias Nerves.Package.Artifact
  alias Nerves.Package.Artifact.Providers
  alias Nerves.Package

  @type t :: %__MODULE__{app: atom,
                        path: binary,
                        type: :system |
                              :package |
                              :toolchain,
                         dep: :project |
                              :path |
                              :hex |
                              :git,
                    platform: atom,
                    provider: atom,
                     version: Version.t,
                      config: Keyword.t}

  @package_config "nerves.exs"
  @checksum "CHECKSUM"
  @required [:type, :version, :platform]

  @doc """
  Builds the package and produces an artifact. See Nerves.Package.Artifact
  for more information.
  """
  @spec artifact(Nerves.Package.t, Nerves.Package.t) :: :ok
  def artifact(pkg, toolchain) do
    ret =
      case pkg.provider do
        {mod, opts} -> mod.artifact(pkg, toolchain, opts)
        providers when is_list(providers) ->
          Enum.reduce(providers, nil, fn ({mod, opts}, ret) ->
            if ret != :ok do
              mod.artifact(pkg, toolchain, opts)
            else
              ret
            end
          end)
      end

    case ret do
      :ok -> Path.join(Artifact.dir(pkg, toolchain), @checksum)
             |> File.write!(checksum(pkg))
      {:error, error} ->
          Mix.raise """

          Nerves encountered an error while constructing the artifact
          #{error}
          """
    end
  end

  @doc """
  Loads the package config and parses it into a `%Package{}`
  """
  @spec load_config({app :: atom, path :: String.t}) :: Nerves.Package.t
  def load_config({app, path}) do
    config = config(app, path)
    version = config[:version]
    type = config[:nerves_package][:type]
    unless type do
      Mix.shell.error "The Nerves package #{app} does not define a type.\n\n" <>
                      "Verify that the key exists in '#{config_path(path)}'.\n"
      exit({:shutdown, 1})
    end
    platform = config[:nerves_package][:platform]
    provider = provider(config)
    config = Enum.reject(config[:nerves_package], fn({k, _v}) -> k in @required end)

    %Package{
      app: app,
      type: type,
      platform: platform,
      provider: provider,
      dep: dep_type(app),
      path: path,
      version: version,
      config: config}
  end

  @doc """
  Produce a base16 encoded checksum for the package from the list of files
  and expanded folders listed in the checksum config key.
  """
  @spec checksum(Nerves.Package.t) :: String.t
  def checksum(pkg) do
    blob =
      (pkg.config[:checksum] || [])
      |> expand_paths(pkg.path)
      |> Enum.map(& File.read!/1)
      |> Enum.map(& :crypto.hash(:sha256, &1))
      |> Enum.join
    :crypto.hash(:sha256, blob)
    |> Base.encode16
  end

  @doc """
  Cleans the artifacts for the package providers of all packages
  """
  @spec clean(Nerves.Package.t) :: :ok | {:error, term}
  def clean(pkg) do
    Mix.shell.info("Cleaning Nerves Package #{pkg.app}")
    Enum.each(pkg.provider, fn({provider, _}) -> provider.clean(pkg) end)
  end

  @doc """
  Determines if the artifact for a package is stale and needs to be rebuilt.
  """
  @spec stale?(Nerves.Package.t, Nerves.Package.t) :: boolean
  def stale?(pkg, toolchain) do
    if Artifact.env_var?(pkg) do
      false
    else
      exists = Artifact.exists?(pkg, toolchain)
      checksum = match_checksum?(pkg, toolchain)

      !(exists and checksum)
    end
  end

  @doc """
  Starts an interactive shell with the working directory set
  to the package path
  """
  @spec shell(Nerves.Package.t) :: :ok
  def shell(nil) do
    Mix.raise "Package is not loaded in your Nerves Environment."
  end

  def shell(%{platform: nil, app: app}) do
    Mix.raise "Cannot start shell for #{app}"
  end

  def shell(pkg) do
    pkg.provider.shell(pkg)
  end

  @doc """
  Takes the path to the package and returns the path to its package config.
  """
  @spec config_path(String.t) :: String.t
  def config_path(path) do
    Path.join(path, @package_config)
  end

  def config(app, path) do
    project_config =
      if app == Mix.Project.config[:app] do
        Mix.Project.config
      else
        Mix.Project.in_project(app, path, fn(_mod) ->
          Mix.Project.config
        end)
      end
    nerves_package =
      case project_config[:nerves_package] do
        nil ->
          # TODO: Deprecated. Clean up after 1.0
          load_nerves_config(path)
          config = Application.get_env(app, :nerves_env)
          Mix.shell.error """
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
          """
          config
        nerves_package -> nerves_package
      end
    Keyword.put(project_config, :nerves_package, nerves_package)
  end

  defp match_checksum?(pkg, toolchain) do
    artifact_checksum =
      Path.join(Artifact.dir(pkg, toolchain), @checksum)
      |> File.read
    case artifact_checksum do
      {:ok, checksum} ->
        checksum == Package.checksum(pkg)
      _ ->
        false
    end
  end

  defp provider(config) do
    case config[:nerves_package][:provider] do
      nil -> provider_type(config[:nerves_package][:type])
      provider -> 
        provider_opts = config[:nerves_package][:provider_opts] || []
        {provider, provider_opts}
    end
  end

  defp provider_type(:system_platform), do: []
  defp provider_type(:toolchain_platform), do: []
  defp provider_type(:toolchain) do
    mod =
      case :os.type do
        {_, :linux} -> Providers.HTTP
        {_, :darwin} -> Providers.HTTP
        _ -> Providers.Docker
      end
    [{Providers.HTTP, []}, {mod, []}]
  end

  defp provider_type(_) do
    mod =
      case :os.type do
        {_, :linux} -> Providers.Local
        _ -> Providers.Docker
      end
    [{Providers.HTTP, []}, {mod, []}]
  end

  defp load_nerves_config(path) do
    config_path(path)
    |> Mix.Config.read!
    |> Mix.Config.persist
  end

  defp dep_type(pkg) do
    deps_paths = Mix.Project.deps_paths()
    case Map.get(deps_paths, pkg) do
      nil ->
        :project
      path ->
        deps_path =
          File.cwd!
          |> Path.join(Mix.Project.config[:deps_path])
          |> Path.expand
        if String.starts_with?(path, deps_path) do
          :hex
        else
          :path
        end
    end
  end

  defp expand_paths(paths, dir) do
    expand_dir = Path.expand(dir)

    paths
    |> Enum.map(&Path.join(dir, &1))
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.flat_map(&dir_files/1)
    |> Enum.map(&Path.expand/1)
    |> Enum.filter(&File.regular?/1)
    |> Enum.uniq
    |> Enum.map(&Path.relative_to(&1, expand_dir))
  end

  defp dir_files(path) do
    if File.dir?(path) do
      Path.wildcard(Path.join(path, "**"))
    else
      [path]
    end
  end

end
