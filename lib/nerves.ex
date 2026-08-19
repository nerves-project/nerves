# SPDX-FileCopyrightText: 2016 Justin Schneck
# SPDX-FileCopyrightText: 2022 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves do
  @moduledoc """
  Nerves tooling for building embedded Elixir

  Please see the [getting started guides](getting-started.html) for using Nerves.
  """

  alias Nerves.BuildPlan
  alias Nerves.MixPackage
  alias Nerves.MixUtils

  @build_plan_key {__MODULE__, :build_plan}

  @doc false
  @spec export_env() :: :ok
  def export_env() do
    _build_plan =
      build_plan()
      |> Nerves.ArtifactResolver.resolve()
      |> BuildPlan.run_planning_actions(:post_extract)
      |> BuildPlan.validate!()
      |> sync_env()
      |> cache_build_plan(true)

    :ok
  end

  @doc """
  Get the current Nerves build plan

  If you're writing a custom `Nerves.BuildAction`, use the `build_plan` that's passed
  to the callbacks. This is handy for situations where the plan isn't easily accessible
  and for debug.
  """
  @spec build_plan() :: BuildPlan.t()
  def build_plan() do
    case :persistent_term.get(@build_plan_key, nil) do
      nil ->
        MixPackage.nerves_packages_in_compile_order()
        |> create_build_plan()
        |> cache_build_plan(false)

      {build_plan, _} ->
        build_plan
    end
  end

  @doc """
  Inject Nerves release steps

  This makes sure that the Nerves tooling is available to affect the
  Mix release process.

  This call belongs in your project's `mix.exs`'s `release/0` function:

  ```
  def release do
    [
      ...
      steps: [&Nerves.init_release/1, :assemble],
      ...
    ]
  end
  ```
  """
  @spec init_release(Mix.Release.t()) :: Mix.Release.t()
  def init_release(%Mix.Release{steps: steps, options: options} = release) do
    new_steps =
      steps
      |> insert_before(:assemble, &Nerves.pre_assemble/1)
      |> insert_after(:assemble, &Nerves.post_assemble/1)

    new_options =
      Keyword.merge(options,
        quiet: true,
        include_executables_for: []
      )

    _ = File.rm_rf!(release.path)

    %{release | steps: new_steps, options: new_options}
  end

  defp insert_after(steps, match, step) do
    Enum.flat_map(steps, fn current ->
      if current == match, do: [current, step], else: [current]
    end)
  end

  defp insert_before(steps, match, step) do
    Enum.flat_map(steps, fn current ->
      if current == match, do: [step, current], else: [current]
    end)
  end

  @doc """
  Return the ERTS path for the release

  On target builds, returns the path to the cross-compiled ERTS from the
  Nerves system artifact. On host, returns `true` to use the host ERTS.

  This call belongs in your project's `mix.exs`'s `release/0` function:

  ```
  def release do
    [
      ...
      include_erts: &Nerves.erts/0,
      ...
    ]
  end
  ```
  """
  @spec erts() :: boolean() | Path.t()
  def erts() do
    build_plan = build_plan()

    cond do
      Mix.target() == :host ->
        :ok

      build_plan.erts != true ->
        :ok

      build_plan.packages == [] ->
        message = """
        Mix target is set, but there aren't any Nerves-aware libraries available

        Please check your project's `mix.exs` to make sure that `:#{Mix.target()}`git  is
        the right spelling and that there are dependencies that use it.
        """

        raise Nerves.InvalidPlan, message: message

      true ->
        message = """
        No Nerves package is supplying an Erlang runtime

        Here are the Nerves packages for Mix target #{Mix.target()}:

        #{Enum.map_join(build_plan.packages, "\n", fn package -> to_string(package.app) end)}
        """

        raise Nerves.InvalidPlan, message: message
    end

    build_plan.erts
  end

  # Mix release step
  @doc false
  @spec pre_assemble(Mix.Release.t()) :: Mix.Release.t()
  def pre_assemble(%Mix.Release{} = release) do
    # TODO - make this prettier
    run_release_actions(release, build_plan(), :pre_assemble_steps)
  end

  @doc false
  @spec post_assemble(Mix.Release.t()) :: Mix.Release.t()
  def post_assemble(%Mix.Release{} = release) do
    build_plan = build_plan()

    MixUtils.info("Building firmware...")

    new_release =
      release
      |> run_release_actions(build_plan, :post_assemble_steps)
      |> run_release_actions(build_plan, :rootfs_creation_steps)

    BuildPlan.run_simple_actions(build_plan, :pre_image_creation)
    BuildPlan.run_simple_actions(build_plan, :image_creation)
    BuildPlan.run_simple_actions(build_plan, :post_image_creation)

    new_release
  end

  defp run_release_actions(release, build_plan, step) do
    BuildPlan.run_release_actions(build_plan, release, step)
  end

  @doc false
  @spec create_build_plan([MixPackage.t()]) :: BuildPlan.t()
  def create_build_plan(all_packages) do
    %BuildPlan{}
    |> add_base_configuration(all_packages)
    |> add_per_package_plans(all_packages)
    |> BuildPlan.run_planning_actions(:pre_download)
  end

  defp default_os_env() do
    %{
      "PATH" => System.get_env("PATH", ""),
      "AR_FOR_BUILD" => "ar",
      "AS_FOR_BUILD" => "as",
      "CC_FOR_BUILD" => "cc",
      "GCC_FOR_BUILD" => "gcc",
      "CXX_FOR_BUILD" => "g++",
      "LD_FOR_BUILD" => "ld",
      "CPPFLAGS_FOR_BUILD" => "",
      "CFLAGS_FOR_BUILD" => "",
      "CXXFLAGS_FOR_BUILD" => "",
      "LDFLAGS_FOR_BUILD" => ""
    }
  end

  defp add_base_configuration(build_plan, packages) do
    package_infos =
      for dep <- packages do
        config = dep.config
        fingerprint_files = fingerprint_files(config)

        %{
          app: dep.app,
          path: dep.dest,
          version: config[:version],
          deps: dep.deps,
          artifact_path: Nerves.Paths.artifact_dir(dep.app, config[:version]),
          download_path: Nerves.Paths.download_dir(dep.app, config[:version]),
          download_validators: [],
          downloads: [],
          extractors: [],
          source_fingerprint: Nerves.Fingerprint.fingerprint(fingerprint_files, dep.dest),
          source_fingerprint_files: fingerprint_files,
          validated_files: []
        }
      end

    # Merge in user configurations from the app environment
    firmware_config = Application.get_env(:nerves, :firmware) || []

    user_app_config =
      [
        source_date_epoch: Application.get_env(:nerves, :source_date_epoch),
        fwup_conf: firmware_config[:fwup_conf],
        fwup_provisioning_conf: firmware_config[:provisioning],
        rootfs_overlay: firmware_config[:rootfs_overlay]
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Map.new()

    config =
      [
        Nerves.BuildAction.Rootfs.default_config(),
        Nerves.BuildAction.Firmware.default_config(),
        user_app_config
      ]
      |> Enum.reduce(%{}, &Map.merge(&2, &1))

    %{
      build_plan
      | packages: package_infos,
        config: config,
        env: default_os_env(),
        actions: []
    }
  end

  defp fingerprint_files(config) do
    # The package author specifies the files to use for the fingerprint. Fall
    # back to the Nerves 1.x way
    config[:nerves][:source_fingerprint_files] ||
      config[:nerves_package][:source_fingerprint_files] ||
      config[:nerves_package][:checksum] || []
  end

  defp add_per_package_plans(build_plan, packages) do
    Enum.reduce(packages, build_plan, &add_to_plan/2)
  end

  defp add_to_plan(package, build_plan) do
    nerves_config =
      package.config[:nerves] ||
        convert_nerves_v1_package(package.app, package.config[:nerves_package])

    add_configuration(build_plan, nerves_config)
  end

  defp convert_nerves_v1_package(app, legacy_config) do
    case nerves_v1_action(legacy_config[:type]) do
      nil ->
        []

      action ->
        [
          actions: [
            {action,
             app: app,
             artifact_sites: legacy_config[:artifact_sites] || [],
             package_env: legacy_config[:env] || []}
          ]
        ]
    end
  end

  defp nerves_v1_action(:system), do: Nerves.BuildAction.NervesV1System
  defp nerves_v1_action(:toolchain), do: Nerves.BuildAction.NervesV1Toolchain
  defp nerves_v1_action(_), do: nil

  # TODO: Move this to BuildPlan somehow since it's tightly coupled to that code.
  defp add_configuration(%BuildPlan{} = build_plan, nerves_config) do
    build_plan = merge_declared_fields(build_plan, nerves_config)

    case nerves_config[:plan_callback] do
      callback when is_function(callback, 1) -> callback.(build_plan)
      nil -> build_plan
    end
  end

  defp merge_declared_fields(build_plan, nerves_config) do
    build_plan
    |> merge_lists(nerves_config)
    |> maybe_merge_env(nerves_config[:env])
    |> merge_packages(nerves_config[:packages])
  end

  @list_fields [
    :actions
  ]
  defp merge_lists(build_plan, nerves_config) do
    Enum.reduce(@list_fields, build_plan, fn field, plan ->
      case nerves_config[field] do
        nil -> plan
        values when is_list(values) -> Map.update!(plan, field, &(&1 ++ values))
      end
    end)
  end

  defp maybe_merge_env(build_plan, nil), do: build_plan
  defp maybe_merge_env(build_plan, env), do: BuildPlan.merge_env(build_plan, env)

  defp merge_packages(build_plan, nil), do: build_plan

  defp merge_packages(build_plan, packages) do
    indexed_packages = Map.new(packages, fn package -> {package.app, package} end)

    # build_plan.packages' order must be preserved here.
    merged =
      Enum.map(build_plan.packages, fn package ->
        case Map.get(indexed_packages, package.app) do
          nil -> package
          updates -> Map.merge(package, updates)
        end
      end)

    %{build_plan | packages: merged}
  end

  defp cache_build_plan(%BuildPlan{} = build_plan, finalized?) do
    case :persistent_term.get(@build_plan_key, nil) do
      {_, true} -> raise RuntimeError, message: "No more updates allowed to build plan!"
      _ -> :ok
    end

    :persistent_term.put(@build_plan_key, {build_plan, finalized?})

    build_plan
  end

  defp sync_env(%BuildPlan{} = build_plan) do
    BuildPlan.fetch_interpolated_env!(build_plan) |> System.put_env()

    build_plan
  end

  @doc """
  Returns the Nerves version as a binary
  """
  @spec version() :: String.t()
  def version() do
    Application.spec(:nerves, :vsn) |> to_string()
  end
end
