defmodule Nerves.Artifact do
  @moduledoc """
  Package artifacts are the product of compiling a package with a
  specific toolchain.

  """
  alias Nerves.Artifact.{Cache, Providers}

  @base_dir Path.expand("~/.nerves/artifacts")
  

  @doc """
  Builds the package and produces an  See Nerves.Artifact
  for more information.
  """
  @spec build(Nerves.Package.t, Nerves.Package.t) :: :ok
  def build(pkg, toolchain) do
    case pkg.provider do
      {provider, opts} ->
        case provider.build(pkg, toolchain, opts) do
          {:ok, path} ->
            Cache.put(pkg, path)
          {:error, error} ->
            Mix.raise """
            Nerves encountered an error while constructing the artifact
            #{error}
            """
        end
      :noop -> :ok
    end
  end

  @doc """
  Produces an artifact which can be fetched when calling `nerves.artifact.get`.
  """
  def archive(%{type: type} = pkg, toolchain, opts) when type in [:toolchain, :system] do
    Mix.shell.info("Creating Artifact Archive")
    opts = default_archive_opts(pkg, opts)
    case pkg.provider do
      {provider, _opts} ->
        {:ok, archive_path} = provider.archive(pkg, toolchain, opts)

        if opts[:path] != archive_path do
          File.cp!(archive_path, opts[:path])
        end
        {:ok, archive_path}
      _ ->
        Mix.shell.info("No provider specified for #{pkg.app}")
        :noop
    end
  end
  def archive(%{type: type}, _toolchain, _opts) do
    Mix.raise """
    mix artifact
    Has not been implemented for #{inspect type} packages. 
    """
  end

  @doc """
  Cleans the artifacts for the package providers of all packages.
  """
  @spec clean(Nerves.Package.t) :: :ok | {:error, term}
  def clean(pkg) do
    Mix.shell.info("Cleaning Nerves Package #{pkg.app}")
    case pkg.provider do
      {provider, _opts} ->
        provider.clean(pkg)
      _ ->
        Mix.shell.info("No provider specified for #{pkg.app}")
        :noop
    end
  end

  @doc """
  Determines if the artifact for a package is stale and needs to be rebuilt.
  """
  @spec stale?(Nerves.Package.t) :: boolean
  def stale?(pkg) do
    if env_var?(pkg) do
      false
    else
      !Cache.valid?(pkg)
    end
  end

  @doc """
  Get the artifact name
  """
  @spec name(Nerves.Package.t) :: String.t
  def name(pkg) do
    "#{pkg.app}-#{host_tuple(pkg)}-#{pkg.version}"
  end

  @doc """
  Get the artifact download name
  """
  @spec download_name(Nerves.Package.t) :: String.t
  def download_name(pkg) do
    "#{pkg.app}-#{host_tuple(pkg)}-#{pkg.version}-#{checksum(pkg)}"
  end
  
  def parse_download_name(name) when is_binary(name) do
    name = Regex.run(~r/(.*)-([^-]*)-(.*)-([^-]*)/, name)
    case name do
      [_, app, host_tuple, version, checksum] ->
        {:ok, %{
          app: app, 
          host_tuple: host_tuple,
          checksum: checksum,
          version: version
        }}
      _->
        {:error, "Unable to parse artifact name #{name}"}
    end
  end

  @doc """
  Get the base dir for where an artifact for a package should be stored.

  The base dir for an artifact will point
  to the NERVES_ARTIFACT_DIR or if undefined, `~/.nerves/artifacts`
  """
  @spec base_dir() :: String.t
  def base_dir() do
    System.get_env("NERVES_ARTIFACTS_DIR") || @base_dir
  end

  @doc """
  Get the path to where the artifact is built
  """
  def build_path(pkg) do
    pkg.path
    |> Path.join(".nerves")
    |> Path.join("artifacts")
    |> Path.join(name(pkg))
  end

  @doc """
  Get the path where the global artifact will be linked to.
  This path is typically a location within build_path, but can be 
  vary on different build platforms.
  """
  def build_path_link(pkg) do
    case pkg.platform do
      platform when is_atom(platform) ->
        platform.build_path_link(pkg)
      _ ->
        build_path(pkg)
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
  The full path to the artifact.
  """
  @spec dir(Nerves.Package.t) :: String.t
  def dir(pkg) do
    if env_var?(pkg) do
      System.get_env(env_var(pkg)) |> Path.expand
    else
      base_dir()
      |> Path.join(name(pkg))
    end
  end

  @doc """
  Check to see if the artifact path is being set from the system env.
  """
  @spec env_var?(Nerves.Package.t) :: boolean
  def env_var?(pkg) do
    name = env_var(pkg)
    dir = System.get_env(name)
    dir != nil and File.dir?(dir)
  end

  @doc """
  Determine the environment variable which would be set to override the path.
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
  Expands the sites helpers from `artifact_sites` in the nerves_package config.
  """
  def expand_sites(pkg) do
    case pkg.config[:artifact_url] do
      nil -> 
        Keyword.get(pkg.config, :artifact_sites, [])
        |> Enum.map(&expand_site(&1, pkg))
      urls when is_list(urls) -> 
        urls
      _invalid -> 
        Mix.raise "Invalid artifact_url. Please use artifact_sites instead"
    end
  end

  @doc """
  Get the path to where the artifact archive is downloaded to.
  """
  def download_path(pkg) do
    name = name(pkg) <> ext(pkg)
    Nerves.Env.download_dir()
    |> Path.join(name)
    |> Path.expand
  end

  @doc """
  Get the host_tuple for the package. Toolchains are specifically build to run
  on a host for a target. Other packages are host agnostic for now. They are 
  marked as `portable`.
  """
  def host_tuple(%{type: :toolchain}) do 
    Nerves.Env.host_os <> "_" <>
    Nerves.Env.host_arch
  end  
  def host_tuple(_pkg) do
    "portable"
  end 

  @doc """
  Determines the extension for an artifact based off its type.
  Toolchains use xz compression.
  """
  @spec ext(Nerves.Package.t) :: String.t
  def ext(%{type: :toolchain}), do: ".tar.xz"
  def ext(_), do: ".tar.gz"

  def provider(config) do
    case config[:nerves_package][:provider] do
      nil -> provider_type(config[:nerves_package][:type])
      provider -> 
        provider_opts = config[:nerves_package][:provider_opts] || []
        {provider, provider_opts}
    end
  end

  defp provider_type(:system_platform), do: nil
  defp provider_type(:toolchain_platform), do: nil
  defp provider_type(:toolchain), do: {Providers.Local, []}

  defp provider_type(_) do
    mod =
      case :os.type do
        {_, :linux} -> Providers.Local
        _ -> Providers.Docker
      end
    {mod, []}
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
    
  end

  defp dir_files(path) do
    if File.dir?(path) do
      Path.wildcard(Path.join(path, "**"))
    else
      [path]
    end
  end

  defp default_archive_opts(pkg, opts) do
    name = download_name(pkg) <> ext(pkg)
    opts
    |> Keyword.put_new(:name, name)
    |> Keyword.put_new(:path, Path.join(File.cwd!(), name))
  end

  defp expand_site({:github_releases, org_proj}, pkg) do
    expand_site({:prefix, "https://github.com/#{org_proj}/releases/download/v#{pkg.version}/"}, pkg)
  end
  defp expand_site({:prefix, path}, pkg) do
    Path.join(path, download_name(pkg) <> ext(pkg))
  end

  defp expand_site(loc, _pkg) when is_binary(loc), 
    do: Nerves.Utils.Shell.warn """
    Unsupported artifact site
    #{inspect loc}
    
    Supported artifact sites:
    {:github_releases, "orginization/project"}
    {:prefix, "http://myserver.com/artifacts"}
    {:prefix, "file:///my_artifacts/"}
    {:prefix, "/users/my_user/artifacts/"}
    """
 

end
