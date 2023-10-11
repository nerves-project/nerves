defmodule Nerves.Artifact do
  @moduledoc """
  Package artifacts are the product of compiling a package with a
  specific toolchain.
  """
  alias Nerves.Artifact.{BuildRunners, Cache, Resolvers}

  @checksum_short 7

  # credo:disable-for-next-line Credo.Check.Readability.Specs
  def __checksum_short_length__(), do: @checksum_short

  @doc """
  Builds the package and produces an  See Nerves.Artifact
  for more information.
  """
  @spec build(Nerves.Package.t(), Nerves.Package.t()) :: :ok | {:error, File.posix()}
  def build(pkg, toolchain) do
    with {build_runner, opts} <- pkg.build_runner,
         {:ok, path} <- build_runner.build(pkg, toolchain, opts) do
      Cache.put(pkg, path)
    else
      :noop ->
        :ok

      {:error, error} ->
        Mix.raise("""
        Nerves encountered an error while constructing the artifact
        #{if String.valid?(error), do: error, else: inspect(error)}
        """)
    end
  end

  @doc """
  Produces an archive of the package artifact which can be fetched when
  calling `nerves.artifact.get`.
  """
  @spec archive(Nerves.Package.t(), Nerves.Package.t(), keyword()) :: {:ok, String.t()}
  def archive(%{app: app, build_runner: nil}, _toolchain, _opts) do
    Mix.raise("""
    #{inspect(app)} does not declare a build_runner and therefore cannot
    be used to produce an artifact archive.
    """)
  end

  def archive(pkg, toolchain, opts) do
    Mix.shell().info("Creating Artifact Archive")
    opts = default_archive_opts(pkg, opts)

    {build_runner, _opts} = pkg.build_runner
    _ = Code.ensure_compiled(pkg.platform)
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
        {:error, :no_build_runner}
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
  @spec download_name(Nerves.Package.t(), checksum_short: non_neg_integer()) :: String.t()
  def download_name(pkg, opts \\ []) do
    checksum_short = opts[:checksum_short] || @checksum_short
    "#{pkg.app}-#{host_tuple(pkg)}-#{pkg.version}-#{checksum(pkg, short: checksum_short)}"
  end

  @doc """
  Get the base dir for where an artifact for a package should be stored.

  The directory for artifacts will be found in the directory returned
  by `Nerves.Env.data_dir/0` (i.e. `"#{Nerves.Env.data_dir()}/artifacts/"`).
  This location can be overriden by the environment variable `NERVES_ARTIFACTS_DIR`.
  """
  @spec base_dir() :: String.t()
  def base_dir() do
    case System.get_env("NERVES_ARTIFACTS_DIR") do
      nil -> Path.join(Nerves.Env.data_dir(), "artifacts")
      dir -> dir
    end
  end

  @doc """
  Get the path to where the artifact is built
  """
  @spec build_path(Nerves.Package.t()) :: binary
  def build_path(pkg) do
    Path.join([pkg.path, ".nerves", "artifacts", name(pkg)])
  end

  @doc """
  Get the path where the global artifact will be linked to.
  This path is typically a location within build_path, but can be
  vary on different build platforms.
  """
  @spec build_path_link(Nerves.Package.t()) :: Path.t()
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
  @spec checksum(Nerves.Package.t(), short: non_neg_integer()) :: String.t()
  def checksum(pkg, opts \\ []) do
    blob =
      (pkg.config[:checksum] || [])
      |> expand_paths(pkg.path)
      |> Enum.map(&File.read!/1)
      |> Enum.map(&:crypto.hash(:sha256, &1))

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
  artifacts hosted in a private Github repo, use `:github_api` and
  pass a user, tag, and personal access token into the sites helper:

  ```elixir
  {:github_api, "owner/repo", username: "skroob", token: "1234567", tag: "v0.1.0"}
  ```

  Or pass query parameters for the URL:

  ```elixir
  {:prefix, "https://my-organization.com", query_params: %{"id" => "1234567", "token" => "abcd"}}
  ```

  You can also use this to add an authorization header for files behind basic auth.

  ```elixir
  {:prefix, "http://my-organization.com/", headers: [{"Authorization", "Basic " <> System.get_env("BASIC_AUTH")}}]}
  ```
  """
  @spec expand_sites(Nerves.Package.t()) :: [
          {Resolvers.URI | Resolvers.GithubAPI, {Path.t(), Keyword.t()}}
        ]
  def expand_sites(pkg) do
    case pkg.config[:artifact_url] do
      nil ->
        Keyword.get(pkg.config, :artifact_sites, [])
        |> Enum.map(&expand_site(&1, pkg))

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
  @spec download_path(Nerves.Package.t()) :: String.t()
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
  @spec host_tuple(Nerves.Package.t()) :: String.t()
  def host_tuple(%{type: :system}) do
    "portable"
  end

  def host_tuple(_pkg) do
    (Nerves.Env.host_os() <> "_" <> Nerves.Env.host_arch())
    |> normalize_osx()
  end

  # Workaround for OTP 24 returning 'aarch64-apple-darwin20.4.0'
  # and OTP 23 and earlier returning 'arm-apple-darwin20.4.0'.
  #
  # The current Nerves tooling naming uses "arm".
  defp normalize_osx("darwin_aarch64"), do: "darwin_arm"
  defp normalize_osx(other), do: other

  @doc """
  Determines the extension for an artifact based off its type.
  Toolchains use xz compression.
  """
  @spec ext(Nerves.Package.t()) :: String.t()
  def ext(%{type: :toolchain}), do: ".tar.xz"
  def ext(_), do: ".tar.gz"

  @spec build_runner(keyword()) :: {module(), keyword()}
  def build_runner(config) do
    opts = config[:nerves_package][:build_runner_opts] || []

    mod =
      config[:nerves_package][:build_runner] || build_runner_type(config[:nerves_package][:type])

    {mod, opts}
  end

  defp build_runner_type(:system_platform), do: nil
  defp build_runner_type(:toolchain_platform), do: nil
  defp build_runner_type(:toolchain), do: BuildRunners.Local

  defp build_runner_type(:system) do
    case :os.type() do
      {_, :linux} -> BuildRunners.Local
      _ -> BuildRunners.Docker
    end
  end

  defp build_runner_type(_), do: BuildRunners.Local

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
    opts =
      opts
      |> Keyword.put(:artifact_name, download_name(pkg, opts) <> ext(pkg))
      |> Keyword.put(:public?, true)
      |> update_in([:tag], &(&1 || "v#{pkg.version}"))

    {Resolvers.GithubAPI, {org_proj, opts}}
  end

  defp expand_site({:gitea_releases, repo_uri}, pkg, opts) when is_binary(repo_uri),
    do: expand_site({:gitea_releases, URI.parse(repo_uri)}, pkg, opts)

  defp expand_site({:gitea_releases, repo_uri}, pkg, opts)
       when is_nil(repo_uri.scheme) and is_nil(repo_uri.host),
       do: expand_site({:gitea_releases, URI.parse("https://#{repo_uri.path}")}, pkg, opts)

  defp expand_site({:gitea_releases, repo_uri}, pkg, opts) do
    repo_uri = URI.parse(repo_uri)
    base_url = %{repo_uri | path: "/"} |> to_string()
    org_proj = repo_uri.path |> String.trim_leading("/")

    opts =
      opts
      |> Keyword.put(:base_url, base_url)
      |> Keyword.put(:artifact_name, download_name(pkg, opts) <> ext(pkg))
      |> Keyword.put(:public?, true)
      |> update_in([:tag], &(&1 || "v#{pkg.version}"))

    {Resolvers.GiteaAPI, {org_proj, opts}}
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

  defp expand_site({:gitea_api, org_proj, resolver_opts}, pkg, opts) do
    resolver_opts =
      Keyword.put(resolver_opts, :artifact_name, download_name(pkg, opts) <> ext(pkg))

    {Resolvers.GiteaAPI, {org_proj, resolver_opts}}
  end

  defp expand_site(site, _pkg, _opts),
    do:
      Mix.raise("""
      Unsupported artifact site
      #{inspect(site)}

      Supported artifact sites:
      {:github_releases, "owner/repo"}
      {:github_api, "owner/repo", username: "skroob", token: "1234567", tag: "v0.1.0"}
      {:gitea_releases, "host/owner/repo"},
      {:gitea_api, "owner/repo", base_url: "https://gitea.com", token: "123456", tag: "v0.1.0"}
      {:prefix, "http://myserver.com/artifacts"}
      {:prefix, "http://myserver.com/artifacts", headers: [{"Authorization", "Basic: 1234567=="}]}
      {:prefix, "http://myserver.com/artifacts", query_params: %{"id" => "1234567"}}
      {:prefix, "file:///my_artifacts/"}
      {:prefix, "/users/my_user/artifacts/"}
      """)
end
