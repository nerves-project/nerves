# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildPlan do
  @moduledoc """
  Nerves firmware build plan

  This struct gets filled in by Nerves and Nerves-aware packages
  before compilation starts. It then gets passed around during the
  firmware build process to guide everything from pre-compiled
  artifact downloads to building root filesystems and final
  firmware assembly. If you'd like to adjust the firmware build process,
  this is usually the place to look.
  """

  alias Nerves.InvalidPlan

  @typedoc """
  How to download a file

  ## URL

  Raw strings are interpreted as URLs. Schemes may be `file`, `http`, or `https`

  ## GitHub Releases

  Public GitHub repositories may use URLs to download release artifacts, but using
  the `:github_releases` or `:github_api` download strategies enables GitHub authentication. In addition to supporting private GitHub repositories, this can also help
  get past unauthenticated download errors.

  The `:github_releases` strategy supports unauthenticated GitHub downloads. If GitHub
  auth tokens aren't available, it still tries. This is good for public repositories.

  The `:github_api` strategy uses the GitHub API to find the release artifact. It will
  fail with GitHub auth tokens aren't available.

  GitHub auth tokens are found in this order:

  1. `GITHUB_TOKEN` environment variable
  2. `GH_TOKEN` environment variable
  3. `:custom_auth_token` option
  4. Calling out to `gh` if the `:use_gh_cli?` option is `true`

  Options:
    - `:github_url` - the main GitHub URL (defaults to https://github.com)
    - `:github_api_url` - the GitHub API endpoint (defaults to https://api.github.com)
    - `:org` - the GitHub organization (required)
    - `:repo` - the GitHub repository (required)
    - `:tag` - the release tag (required)
    - `:filename` - the filename to download (required)
    - `:custom_auth_token` - specify an auth token. This is rarely needed.
    - `:use_gh_cli?` - allow the `gh` CLI utility to be used to get auth tokens. Defaults to `true`

  ## Gitea Releases

  Gitea support is very similar to GitHub support with the exception of the URLs
  and naming of auth tokens. It is similar in that `:gitea_releases` is intended
  for public assets that don't require authentication and `:gitea_api` works for
  private release assets.

  Gitea auth tokens are found in this order:

  1. `GITEA_TOKEN` environment variable
  2. `:token` option

  Options:
    - `:base_url` - the base Gitea URL (required)
    - `:org` - the Gitea organization (required)
    - `:repo` - the Gitea repository (required)
    - `:tag` - the release tag (required)
    - `:filename` - the filename to download (required)
    - `:token` - specify an auth token
  """
  @type download_spec() ::
          String.t()
          | {:github_releases, keyword()}
          | {:github_api, keyword()}
          | {:gitea_releases, keyword()}
          | {:gitea_api, keyword()}

  @typedoc """
  Download validation strategy

  Nerves doesn't allow unvalidated downloads to proceed to subsequent build steps.
  One size doesn't fit all when it comes to validation, so Nerves-aware packages
  can customize it to their needs.

  ## Skip

  If the download step suffices in getting trusted binaries, then validation isn't
  needed. It is still necessary to explicitly skip trusted binaries.

  Options:

  - `:filename` - the filename to skip validation on

  ## OpenSSL Signature

  This is the simplest type of validation that can be done using the `openssl` command
  line tool. To create a public/private key pair, run:

  ```sh
  openssl genrsa -aes128 -passout pass:<passphrase> -out private.pem 2048
  openssl rsa -in private.pem -passin pass:<passphrase> -pubout -out public.pem
  ```

  Then to sign a file, run:

  ```sh
  openssl dgst -sha256 -sign $privatekey -out /tmp/$filename.out $filename
  openssl base64 -in /tmp/$filename.out -out $filename.sig
  rm /tmp/$filename.out
  ```

  To manually verify a file, run:

  ```sh
  openssl base64 -d -in $filename.sig -out /tmp/$filename.out
  openssl dgst -sha256 -verify $publickey -signature /tmp/$filename.out $filename
  rm /tmp/$filename.out
  ```

  Options:
    - `:filename` - the file to verify (required)
    - `:signature` - the signature file (defaults to `<filename>.sig`)
    - `:public_keys` - a list of public keys in PEM form and as strings
  """
  @type download_validator() :: :archive | {:openssl_signature, keyword()} | {:skip, keyword()}

  @typedoc """
  Specify how download files are processed

  The normal procedure is to untar the file that was downloaded. This
  is not always the case, and this option allows other processing to
  be done.

  ## Untar

  Run `tar` to extract the contents into the artifact directory.

  Options:
    - `:filename` - the file to untar (required)
  """
  @type extractor_spec() :: {:untar, keyword()}

  @typedoc """
  Per-package information that's kept in the BuildPlan

  * `:app` - the name of the package
  * `:artifact_path` - Path to where artifacts can be extracted and custom files added
  * `:build_script` - A script to run in the container for `mix nerves.artifact.build`
  * `:shell_setup_script` - A script to run in the container for `mix nerves.artifact.shell`
  * `:deps` - List of Nerves-aware packages that this one depends on
  * `:download_path` - Path to where to download any files for this package
  * `:download_validators` - A list of validators for checking the package's download. Post-download steps may only access validated files.
  * `:downloads` - a list of download plans
  * `:extractors` - a list of extractors for expanding archives into the artifact_path
  * `:path` - path to package source under the deps directory
  * `:source_fingerprint` - calculated source fingerprints. The fingerprint catches configs that diverge from artifact inputs.
  * `:source_fingerprint_files` - List of files included in the fingerprint.
  * `:validated_files` - a map of download files that have passed validation keyed by package name
  * `:version` - the version of this package
  """
  @type package_info() :: %{
          app: atom(),
          path: Path.t(),
          version: String.t(),
          deps: [atom()],
          artifact_path: Path.t(),
          download_path: Path.t(),
          downloads: [download_spec()],
          download_validators: [download_validator()],
          extractors: [extractor_spec()],
          source_fingerprint: String.t(),
          source_fingerprint_files: [Path.t()],
          validated_files: [Path.t()],
          shell_setup_script: String.t(),
          build_script: String.t()
        }

  @typedoc """
  The Nerves.BuildPlan struct has the following fields:

  * `:config` - a map of key-value pairs containing the overall configuration
  * `:env` - a map of key-value pairs that are exported in the OS environment to guide
    cross-compilation
  * `:host_build?` - true if building for the host
  * `:packages` - package-specific plans and config. List is ordered by compilation order.
  * `:actions` - a list of build actions for creating the firmware
  * `:rootfs_overlays` - a list of paths or `.tar` files that get overlaid to create the root filesystem
  * `:erts` - Path to the version of erts to include in releases
  """
  defstruct host_build?: false,
            packages: [],
            config: %{},
            env: %{},
            actions: [],
            rootfs_overlays: [],
            erts: true

  @type t :: %__MODULE__{
          host_build?: boolean,
          packages: [package_info()],
          config: map(),
          env: map(),
          actions: [module() | {module(), keyword()}],
          rootfs_overlays: [Path.t()],
          erts: Path.t() | boolean()
        }

  @doc """
  Validate the build plan to detect issues that may cause problems later

  Returns the build plan for use in pipelines
  """
  @spec validate!(t()) :: t()
  defdelegate validate!(build_plan), to: Nerves.BuildPlan.Checks

  @doc """
  Find build plan information about a package
  """
  @spec find_package(t(), atom()) :: package_info() | nil
  def find_package(%__MODULE__{} = build_plan, app) when is_atom(app) do
    Enum.find(build_plan.packages, &(&1.app == app))
  end

  @doc """
  Replace the specified package info
  """
  @spec replace_package(t(), package_info()) :: t()
  def replace_package(%__MODULE__{} = build_plan, %{app: app} = package) do
    new_packages =
      Enum.map(build_plan.packages, fn pkg ->
        if pkg.app == app, do: package, else: pkg
      end)

    %{build_plan | packages: new_packages}
  end

  @doc """
  Merge a new set of OS environment variables into the plan

  Variables should be passed either as a map or a list of key/value tuples. Variables
  overwrite ones with the same keys.

  Values support interpolation using `${VAR_NAME}` syntax. Interpolation is postponed
  until later so it's fine to set values that can't be interpolated until a future
  variable gets added. Unlike a Unix shell, though, values referencing unknown values
  raise rather than substitute an empty string.

  Except for `$PATH` handling, the user's OS environment is ignored.
  """
  @spec merge_env(t(), Enumerable.t()) :: t()
  def merge_env(%__MODULE__{} = build_plan, env) do
    %{build_plan | env: Map.merge(build_plan.env, Map.new(env))}
  end

  @doc """
  Prepend a path to the PATH environment variable

  If the path already exists in $PATH, then this is a no-op.
  """
  @spec prepend_path(t(), Path.t()) :: t()
  def prepend_path(%__MODULE__{} = build_plan, path) do
    expanded_path = Path.expand(path)
    current_path = Map.get(build_plan.env, "PATH", "")

    cond do
      expanded_path in String.split(current_path, ":") ->
        build_plan

      current_path == "" ->
        %{build_plan | env: Map.put(build_plan.env, "PATH", expanded_path)}

      true ->
        %{build_plan | env: Map.put(build_plan.env, "PATH", "#{expanded_path}:#{current_path}")}
    end
  end

  @doc """
  Return a map of environment variables with all values interpolated

  Raises `KeyError` on undefined variables or self-referential variables
  """
  @spec fetch_interpolated_env!(t()) :: %{String.t() => String.t()}
  def fetch_interpolated_env!(%__MODULE__{} = build_plan) do
    Enum.reduce(build_plan.env, %{}, fn {key, value}, acc ->
      Map.put(acc, key, interpolate(value, build_plan.env))
    end)
  end

  @doc """
  Return the interpolated value for the specified key

  Raises `KeyError` on undefined variables or self-referential variables
  """
  @spec fetch_interpolated_env!(t(), String.t()) :: String.t()
  def fetch_interpolated_env!(%__MODULE__{} = build_plan, key) do
    Map.fetch!(build_plan.env, key) |> interpolate(build_plan.env)
  end

  @doc """
  Return the interpolated value for the specified key

  This is a non-raising version of `fetch_interpolated_env/2`.
  """
  @spec fetch_interpolated_env(t(), String.t()) :: {:ok, String.t()} | :error
  def fetch_interpolated_env(%__MODULE__{} = build_plan, key) do
    {:ok, fetch_interpolated_env!(build_plan, key)}
  rescue
    KeyError -> :error
  end

  defp interpolate(value, env) do
    Regex.replace(~r/\$\{([^}]+)\}/, value, fn _match, variable ->
      interpolate(Map.fetch!(env, variable), Map.delete(env, variable))
    end)
  end

  @spec merge_config(t(), Enumerable.t()) :: t()
  def merge_config(%__MODULE__{} = build_plan, config) do
    %{build_plan | config: Map.merge(build_plan.config, Map.new(config))}
  end

  @spec run_planning_actions(t(), atom()) :: t()
  def run_planning_actions(%__MODULE__{} = build_plan, fun)
      when fun in [:post_extract, :pre_download] do
    # Since planning actions can add actions, keep iterating until they
    # all have been processed.
    repeat_running_planning_actions([], build_plan, &call_planning_action(&1, fun, &2))
  end

  defp repeat_running_planning_actions(already_run, build_plan, call_fun) do
    actions = build_plan.actions -- already_run

    if actions == [] do
      build_plan
    else
      new_build_plan = Enum.reduce(actions, build_plan, call_fun)
      repeat_running_planning_actions(already_run ++ actions, new_build_plan, call_fun)
    end
  end

  defp call_planning_action(hook, fun, build_plan) do
    new_plan = call_action(hook, fun, [build_plan])

    if not is_struct(new_plan, __MODULE__) do
      raise InvalidPlan, message: "Expecting a #{inspect(hook)} to return a Nerves.BuildPlan"
    end

    new_plan
  end

  @spec run_simple_actions(t(), atom()) :: :ok
  def run_simple_actions(%__MODULE__{} = build_plan, fun)
      when fun in [:pre_image_creation, :image_creation, :post_image_creation] do
    Enum.each(build_plan.actions, &run_simple_action(&1, fun, build_plan))
  end

  defp run_simple_action(action, fun, build_plan) do
    result = call_action(action, fun, [build_plan])

    if result != :ok do
      raise InvalidPlan, message: "Expecting #{inspect(action)} to return :ok from #{fun}"
    end

    :ok
  end

  @spec run_release_actions(t(), Mix.Release.t(), atom()) :: Mix.Release.t()
  def run_release_actions(%__MODULE__{} = build_plan, %Mix.Release{} = release, fun)
      when fun in [:pre_assemble_steps, :post_assemble_steps, :rootfs_creation_steps] do
    Enum.reduce(build_plan.actions, release, fn action, rel ->
      run_release_action(action, fun, build_plan, rel)
    end)
  end

  defp run_release_action(action, fun, build_plan, release) do
    new_rel = call_action(action, fun, [build_plan, release])

    if not is_struct(new_rel, Mix.Release) do
      raise InvalidPlan,
        message: "Expecting a %Mix.Release{} from #{inspect(action)} for #{fun}"
    end

    new_rel
  end

  defp call_action(m, fun, args) when is_atom(m), do: apply(m, fun, args ++ [[]])
  defp call_action({m, opts}, fun, args) when is_atom(m), do: apply(m, fun, args ++ [opts])
end
