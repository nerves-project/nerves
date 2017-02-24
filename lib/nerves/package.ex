defmodule Nerves.Package do
  @moduledoc """
  Defines a Nerves package struct and helper functions.

  A Nerves package is an application which defines a Nerves package
  configuration file at the root of the application path. The configuration
  file is `nerves.exs` and uses Mix.Config to list configuration values.

  ## Example Configuration
  ```
    use Mix.Config

    version =
      Path.join(__DIR__, "VERSION")
      |> File.read!
      |> String.strip

    pkg =

    config pkg, :nerves_env,
      type: :system,
      version: version,
      compiler: :nerves_package,
      artifact_url: [
        "https://github.com/nerves-project/\#{pkg}/releases/download/v\#{version}/\#{pkg}-v\#{version}.tar.gz",
      ],
      platform: Nerves.System.BR,
      platform_config: [
        defconfig: "nerves_defconfig",
      ],
      checksum: [
        "linux",
        "rootfs-additions",
        "uboot",
        "bbb-busybox.config",
        "fwup.conf",
        "nerves_defconfig",
        "nerves.exs",
        "post-createfs.sh",
        "uboot-script.cmd",
        "VERSION"
      ]
  ```

  ## Keys

  ** Required **

    * `:type` - The Nerves package type. Can be any one of the following
      * `:system` - A Nerves system.
      * `:system_platform` - A set of build tools for a Nerves system.
      * `:toolchain` - A Nerves toolchain
      * `:toolchain_platform` - A set of build tools for a Nerves toolchain.
    * `:version` - The package version

  ** Optional **

    * `:compiler` - The Mix.Project compiler for the package. Example: `:nerves_package`
    * `:platform` - The application which is the packages build platform.
    * `:checksum` - A list of files and top level folders to expand paths for use when calculating the checksum of the package source.
  """

  defstruct [app: nil, path: nil, dep: nil, type: nil, version: nil, platform: nil, provider: nil, compiler: nil, config: []]

  alias __MODULE__
  alias Nerves.Package.{Artifact, Providers}
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
                    compiler: atom,
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
        _ -> :error
    end
  end

  @doc """
  Loads the package config and parses it into a `%Package{}`
  """
  @spec load_config({app :: atom, path :: String.t}) :: Nerves.Package.t
  def load_config({app, path}) do
    load_nerves_config(path)
    config = Application.get_env(app, :nerves_env)
    version = config[:version]
    unless version, do: Mix.shell.error "The Nerves package #{app} does not define its version"
    type = config[:type]
    unless type, do: Mix.shell.error "The Nerves package #{app} does not define a type"
    platform = config[:platform]
    provider = provider(app, type)
    compiler = config[:compiler]
    config = Enum.reject(config, fn({k, _v}) -> k in @required end)

    %Package{
      app: app,
      type: type,
      platform: platform,
      provider: provider,
      dep: dep_type(app),
      path: path,
      version: version,
      compiler: compiler,
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

  defp provider(app, type) do
    config = Mix.Project.config[:artifacts] || []

    case Keyword.get(config, app) do
      nil -> [{Providers.HTTP, []}, {provider_mod(type), []}]
      opts -> provider_opts(opts)
    end
  end

  defp provider_mod(:toolchain) do
    case :os.type do
      {_, :linux} -> Providers.HTTP
      {_, :darwin} -> Providers.HTTP
      _ -> Providers.Docker
    end
  end

  defp provider_mod(_) do
    case :os.type do
      {_, :linux} -> Providers.Local
      _ -> Providers.Docker
    end
  end

  defp provider_opts(mod) when is_atom(mod), do: {mod, []}
  defp provider_opts(opts) when is_list(opts) do
    mod =
      cond do
        opts[:path] != nil -> Providers.Path
        opts[:url] != nil -> Providers.HTTP
        true -> Mix.raise "Invalid artifact options"
      end
    {mod, opts}
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
