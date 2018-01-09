defmodule Nerves.Package.Artifact do
  @moduledoc """
  Package artifacts are the product of compiling a package with a
  specific toolchain.

  """
  alias Nerves.Package.Artifact.Providers

  @base_dir Path.expand("~/.nerves/artifacts")
  @checksum "CHECKSUM"

  @doc """
  Builds the package and produces an  See Nerves.Package.Artifact
  for more information.
  """
  @spec build(Nerves.Package.t, Nerves.Package.t) :: :ok
  def build(pkg, toolchain) do
    case pkg.provider do
      {provider, opts} ->
        case provider.build(pkg, toolchain, opts) do
          {:ok, path} ->
            Path.join(path, @checksum)
            |> File.write!(checksum(pkg))
          {:error, error} ->
            Mix.raise """
            Nerves encountered an error while constructing the artifact
            #{error}
            """
        end
      :noop -> :ok
    end
  end

  def archive(pkg, toolchain, opts) do
    Mix.shell.info("Creating Artifact Archive")
    opts = default_archive_opts(pkg, opts)
    results = 
      Enum.map(pkg.provider, fn({provider, _}) -> provider.archive(pkg, toolchain, opts) end)

    {:ok, archive_path} = Enum.find(results, fn
      ({:ok, _}) -> true 
      _ -> false
    end)
    if opts[:path] != archive_path do
      File.cp!(archive_path, opts[:path])
    end

    File.write!(opts[:checksum_path], archive_checksum(archive_path))
  end

  def archive_checksum(archive_path) do
    archive = File.read!(archive_path)
    :crypto.hash(:sha256, archive)
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
    if env_var?(pkg) do
      false
    else
      exists = exists?(pkg, toolchain)
      checksum = match_checksum?(pkg, toolchain)

      !(exists and checksum)
    end
  end

  @doc """
  Get the artifact name

  Requires the package and toolchain package to be supplied
  """
  @spec name(Nerves.Package.t, Nerves.Package.t) :: String.t
  def name(pkg, toolchain) do
    target_tuple =
      case pkg.type do
        :toolchain ->
          Nerves.Env.host_platform <> "-" <>
          Nerves.Env.host_arch
        _ ->
        toolchain.config[:target_tuple]
        |> to_string
      end
    "#{pkg.app}-#{pkg.version}.#{target_tuple}"
  end

  @doc """
  Get the base dir for where an artifact for a package should be stored.

  If a package is pulled in from hex, the base dir for an artifact will point
  to the NERVES_ARTIFACT_DIR or if undefined, `~/.nerves/artifacts`

  Packages which were obtained through other Mix SCM's such as path will
  have a base_dir local to the package path
  """
  @spec base_dir(Nerves.Package.t) :: String.t
  def base_dir(pkg) do
    case pkg.dep do
      local when local in [:path, :project] ->
        pkg.path
        |> Path.join(".nerves/artifacts")
      _ ->
        System.get_env("NERVES_ARTIFACTS_DIR") || @base_dir
    end

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
  The full path to the artifact
  """
  @spec dir(Nerves.Package.t, Nerves.Package.t) :: String.t
  def dir(pkg, toolchain) do
    if env_var?(pkg) do
      System.get_env(env_var(pkg)) |> Path.expand
    else
      base_dir(pkg)
      |> Path.join(name(pkg, toolchain))
    end
  end

  @doc """
  Determines if an artifact exists at its artifact dir.
  """
  @spec exists?(Nerves.Package.t, Nerves.Package.t) :: boolean
  def exists?(pkg, toolchain) do
    dir(pkg, toolchain)
    |> File.dir?
  end

  @doc """
  Check to see if the artifact path is being set from the system env
  """
  @spec env_var?(Nerves.Package.t) :: boolean
  def env_var?(pkg) do
    name = env_var(pkg)
    dir = System.get_env(name)
    dir != nil and File.dir?(dir)
  end

  @doc """
  Determine the environment variable which would be set to override the path
  """
  @spec env_var(Nerves.Package.t) :: String.t
  def env_var(pkg) do
    case pkg.type do
      :toolchain -> "NERVES_TOOLCHAIN"
      :system -> "NERVES_SYSTEM"
      _ ->
        pkg.name
        |> Atom.to_string
        |> String.upcase
    end
  end

  @doc """
  Determines the extension for an artifact based off its type.
  Toolchains use xz compression
  """
  @spec ext(Nerves.Package.t) :: String.t
  def ext(%{type: :toolchain}), do: "tar.xz"
  def ext(_), do: "tar.gz"

  def provider(config) do
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
    {mod, []}
  end

  defp provider_type(_) do
    mod =
      case :os.type do
        {_, :linux} -> Providers.Local
        _ -> Providers.Docker
      end
    {mod, []}
  end

  defp match_checksum?(pkg, toolchain) do
    artifact_checksum =
      Path.join(dir(pkg, toolchain), @checksum)
      |> File.read
    case artifact_checksum do
      {:ok, checksum} ->
        checksum == checksum(pkg)
      _ ->
        false
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

  defp default_archive_opts(pkg, opts) do
    name = opts[:name] || "#{pkg.app}-v#{pkg.version}.#{ext(pkg)}"
    opts
    |> Keyword.put_new(:name, name)
    |> Keyword.put_new(:path, Path.join(File.cwd!(), name))
    |> Keyword.put_new(:checksum_path, Path.join(File.cwd!(), "ARTIFACT_CHECKSUM"))
  end
end
