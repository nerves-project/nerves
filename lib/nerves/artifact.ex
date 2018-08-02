defmodule Nerves.Artifact do
  @moduledoc """
  Package artifacts are the product of compiling a package with a
  specific toolchain.

  """
  alias Nerves.Artifact.{Cache, BuildRunners, Resolvers}

  @base_dir Path.expand("~/.nerves/artifacts")
  @checksum_short 7

  @doc """
  Builds the package and produces an  See Nerves.Artifact
  for more information.
  """
  @spec build(Nerves.Package.t(), Nerves.Package.t()) :: :ok
  def build(pkg, toolchain) do
    case pkg.build_runner do
      {build_runner, opts} ->
        case build_runner.build(pkg, toolchain, opts) do
          {:ok, path} ->
            Cache.put(pkg, path)

          {:error, error} ->
            Mix.raise("""
            Nerves encountered an error while constructing the artifact
            #{error}
            """)
        end

      :noop ->
        :ok
    end
  end

  @doc """
  Produces an archive of the package artifact which can be fetched when
  calling `nerves.artifact.get`.
  """
  def archive(%{app: app, build_runner: nil}, _toolchain, _opts) do
    Mix.raise("""
    #{inspect(app)} does not declare a build_runner and therefore cannot
    be used to produce an artifact archive.
    """)
  end

  def archive(pkg, toolchain, opts) do
    Mix.shell().info("Creating Artifact Archive")
    opts = default_archive_opts(pkg, opts)

    case pkg.build_runner do
      {build_runner, _opts} ->
        Code.ensure_compiled(pkg.platform)
        {:ok, archive_path} = build_runner.archive(pkg, toolchain, opts)
        archive_path = Path.expand(archive_path)

        path =
          opts[:path]
          |> Path.expand()
          |> Path.join(download_name(pkg) <> ext(pkg))

        if path != archive_path do
          File.cp!(archive_path, path)
        end

        {:ok, archive_path}

      _ ->
        Mix.shell().info("No build_runner specified for #{pkg.app}")
        :noop
    end
  end

  @doc """
  Cleans the artifacts for the package build_runners of all packages.
  """
  @spec clean(Nerves.Package.t()) :: :ok | {:error, term}
  def clean(pkg) do
    Mix.shell().info("Cleaning Nerves Package #{pkg.app}")

    case pkg.build_runner do
      {build_runner, _opts} ->
        build_runner.clean(pkg)

      _ ->
        Mix.shell().info("No build_runner specified for #{pkg.app}")
        :noop
    end
  end

  @doc """
  Determines if the artifact for a package is stale and needs to be rebuilt.
  """
  @spec stale?(Nerves.Package.t()) :: boolean
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
  @spec name(Nerves.Package.t()) :: String.t()
  def name(pkg) do
    "#{pkg.app}-#{host_tuple(pkg)}-#{pkg.version}"
  end

  @doc """
  Get the artifact download name
  """
  @spec download_name(Nerves.Package.t()) :: String.t()
  def download_name(pkg, opts \\ []) do
    checksum_short = opts[:checksum_short] || @checksum_short
    "#{pkg.app}-#{host_tuple(pkg)}-#{pkg.version}-#{checksum(pkg, short: checksum_short)}"
  end

  def parse_download_name(name) when is_binary(name) do
    name = Regex.run(~r/(.*)-([^-]*)-(.*)-([^-]*)/, name)

    case name do
      [_, app, host_tuple, version, checksum] ->
        {:ok,
         %{
           app: app,
           host_tuple: host_tuple,
           checksum: checksum,
           version: version
         }}

      _ ->
        {:error, "Unable to parse artifact name #{name}"}
    end
  end

  @doc """
  Get the base dir for where an artifact for a package should be stored.

  The base dir for an artifact will point
  to the NERVES_ARTIFACTS_DIR or if undefined, `~/.nerves/artifacts`
  """
  @spec base_dir() :: String.t()
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
        if :erlang.function_exported(platform, :build_path_link, 1) do
          apply(platform, :build_path_link, [pkg])
        else
          build_path(pkg)
        end

      _ ->
        build_path(pkg)
    end
  end

  @doc """
  Produce a base16 encoded checksum for the package from the list of files
  and expanded folders listed in the checksum config key.
  """
  @spec checksum(Nerves.Package.t()) :: String.t()
  def checksum(pkg, opts \\ []) do
    blob =
      (pkg.config[:checksum] || [])
      |> expand_paths(pkg.path)
      |> Enum.map(&File.read!/1)
      |> Enum.map(&:crypto.hash(:sha256, &1))
      |> Enum.join()

    checksum =
      :crypto.hash(:sha256, blob)
      |> Base.encode16()

    case Keyword.get(opts, :short) do
      nil ->
        checksum

      short_len ->
        {checksum_short, _} = String.split_at(checksum, short_len)
        checksum_short
    end
  end

  @doc """
  The full path to the artifact.
  """
  @spec dir(Nerves.Package.t()) :: String.t()
  def dir(pkg) do
    if env_var?(pkg) do
      System.get_env(env_var(pkg)) |> Path.expand()
    else
      base_dir()
      |> Path.join(name(pkg))
    end
  end

  @doc """
  Check to see if the artifact path is being set from the system env.
  """
  @spec env_var?(Nerves.Package.t()) :: boolean
  def env_var?(pkg) do
    name = env_var(pkg)
    dir = System.get_env(name)
    dir != nil and File.dir?(dir)
  end

  @doc """
  Determine the environment variable which would be set to override the path.
  """
  @spec env_var(Nerves.Package.t()) :: String.t()
  def env_var(pkg) do
    case pkg.type do
      :toolchain ->
        "NERVES_TOOLCHAIN"

      :system ->
        "NERVES_SYSTEM"

      _ ->
        pkg.app
        |> Atom.to_string()
        |> String.upcase()
    end
  end

  @doc """
  Expands the sites helpers from `artifact_sites` in the nerves_package config.

  Artifact sites can pass options as a third parameter for adding headers
  or query string parameters. For example, if you are trying to resolve
  artifacts hosted using `:github_releases` in a private repo,
  you can pass a personal access token into the sites helper.

    {:github_releases, "my-organization/my_repository", query_params: %{"access_token" => System.get_env("GITHUB_ACCESS_TOKEN")}}

  You can also use this to add an authorization header for files behind basic auth.

    {:prefix, "http://my-organization.com/", headers: [{"Authorization", "Basic " <> System.get_env("BASIC_AUTH")}}]}

  """
  def expand_sites(pkg) do
    case pkg.config[:artifact_url] do
      nil ->
        # |> Enum.map(&expand_site(&1, pkg))
        # Check entire checksum length
        # This code can be removed sometime after nerves 1.0
        # and instead use the commented line above
        Keyword.get(pkg.config, :artifact_sites, [])
        |> Enum.reduce([], fn site, urls ->
          [expand_site(site, pkg), expand_site(site, pkg, checksum_short: 64) | urls]
        end)

      urls when is_list(urls) ->
        # artifact_url is deprecated and this code can be removed sometime following
        # nerves 1.0
        if Enum.any?(urls, &(!is_binary(&1))) do
          Mix.raise("""
          artifact_urls can only be strings.
          Please use artifact_sites instead.
          """)
        end

        urls

      _invalid ->
        Mix.raise("Invalid artifact_url. Please use artifact_sites instead")
    end
  end

  @doc """
  Get the path to where the artifact archive is downloaded to.
  """
  def download_path(pkg) do
    name = download_name(pkg) <> ext(pkg)

    Nerves.Env.download_dir()
    |> Path.join(name)
    |> Path.expand()
  end

  @doc """
  Get the host_tuple for the package. Toolchains are specifically build to run
  on a host for a target. Other packages are host agnostic for now. They are
  marked as `portable`.
  """
  def host_tuple(%{type: :system}) do
    "portable"
  end

  def host_tuple(_pkg) do
    Nerves.Env.host_os() <> "_" <> Nerves.Env.host_arch()
  end

  @doc """
  Determines the extension for an artifact based off its type.
  Toolchains use xz compression.
  """
  @spec ext(Nerves.Package.t()) :: String.t()
  def ext(%{type: :toolchain}), do: ".tar.xz"
  def ext(_), do: ".tar.gz"

  def build_runner(config) do
    case config[:nerves_package][:build_runner] do
      nil ->
        build_runner_type(config[:nerves_package][:type])

      build_runner ->
        build_runner_opts = config[:nerves_package][:build_runner_opts] || []
        {build_runner, build_runner_opts}
    end
  end

  defp build_runner_type(:system_platform), do: nil
  defp build_runner_type(:toolchain_platform), do: nil
  defp build_runner_type(:toolchain), do: {BuildRunners.Local, []}

  defp build_runner_type(:system) do
    mod =
      case :os.type() do
        {_, :linux} -> BuildRunners.Local
        _ -> BuildRunners.Docker
      end

    {mod, []}
  end

  defp build_runner_type(_), do: {BuildRunners.Local, []}

  defp expand_paths(paths, dir) do
    paths
    |> Enum.map(&Path.join(dir, &1))
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.flat_map(&dir_files/1)
    |> Enum.map(&Path.expand/1)
    |> Enum.filter(&File.regular?/1)
    |> Enum.uniq()
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
    |> Keyword.put_new(:path, File.cwd!())
  end

  defp expand_site(_, _, _ \\ [])

  defp expand_site({:github_releases, org_proj}, pkg, opts) do
    expand_site(
      {:prefix, "https://github.com/#{org_proj}/releases/download/v#{pkg.version}/"},
      pkg,
      opts
    )
  end

  defp expand_site({:prefix, url}, pkg, opts) do
    expand_site({:prefix, url, []}, pkg, opts)
  end

  defp expand_site({:prefix, path, resolver_opts}, pkg, opts) do
    path = Path.join(path, download_name(pkg, opts) <> ext(pkg))
    {Resolvers.URI, {path, resolver_opts}}
  end

  defp expand_site({:github_api, org_proj, resolver_opts}, pkg, opts) do
    resolver_opts =
      Keyword.put(resolver_opts, :artifact_name, download_name(pkg, opts) <> ext(pkg))

    {Resolvers.GithubAPI, {org_proj, resolver_opts}}
  end

  defp expand_site(site, _pkg, _opts),
    do:
      Mix.raise("""
      Unsupported artifact site
      #{inspect(site)}

      Supported artifact sites:
      {:github_releases, "owner/repo"}
      {:github_api, "owner/repo", username: "skroob", token: "1234567", tag: "v0.1.0"}
      {:prefix, "http://myserver.com/artifacts"}
      {:prefix, "http://myserver.com/artifacts", headers: [{"Authorization", "Basic: 1234567=="}]}
      {:prefix, "http://myserver.com/artifacts", query_params: %{"id" => "1234567"}}
      {:prefix, "file:///my_artifacts/"}
      {:prefix, "/users/my_user/artifacts/"}
      """)
end
