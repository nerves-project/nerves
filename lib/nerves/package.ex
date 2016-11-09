defmodule Nerves.Package do
  defstruct [app: nil, path: nil, dep: nil, type: nil, version: nil, platform: nil, provider: nil, compiler: nil, config: []]

  alias __MODULE__
  alias Nerves.Package.{Artifact, Providers}
  alias Nerves.Package
  alias Nerves.Utils.Shell

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
  @artifacts_dir Path.expand("~/.nerves/artifacts")
  @required [:type, :version, :platform]

  def artifact(pkg, toolchain) do
    {mod, opts} = pkg.provider
    mod.artifact(pkg, toolchain, opts)
    Path.join(Artifact.dir(pkg, toolchain), @checksum)
    |> File.write!(checksum(pkg))
  end

  def load_config({app, path}) do
    load_nerves_config(path)
    config = Application.get_env(app, :nerves_env)
    version = config[:version]
    unless version, do: Shell.warn "The Nerves package #{app} does not define its version"
    type = config[:type]
    unless type, do: Shell.warn "The Nerves package #{app} does not define a type"
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

  def config_path(path) do
    Path.join(path, @package_config)
  end

  def stale?(pkg, toolchain) do
    if match_env?(pkg, toolchain) do
      false
    else
      exists = Artifact.exists?(pkg, toolchain)
      checksum = match_checksum?(pkg, toolchain)

      !(exists and checksum)
    end
  end

  defp match_env?(pkg, _toolchain) do
    name =
      case pkg.type do
        :toolchain -> "NERVES_TOOLCHAIN"
        :system -> "NERVES_SYSTEM"
        _ ->
          pkg.name
          |> Atom.to_string
          |> String.upcase
      end
    name = name <> "_ARTIFACT"
    dir = System.get_env(name)

    dir != nil and
    File.dir?(dir)
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

  def shell(nil) do
    Mix.raise "Package is not loaded in your Nerves Environment."
  end

  def shell(%{platform: nil, app: app}) do
    Mix.raise "Cannot start shell for #{app}"
  end

  def shell(pkg) do
    pkg.provider.shell(pkg)
  end

  defp provider(app, type) do
    config = Mix.Project.config[:artifacts] || []

    case Keyword.get(config, app) do
      nil -> {provider_mod(type), []}
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
    deps_paths = Mix.Project.deps_paths
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
