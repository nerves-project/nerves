# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildAction.NervesV1Toolchain do
  @moduledoc false

  use Nerves.BuildAction
  alias Nerves.BuildPlan
  alias Nerves.TargetTuple

  @impl Nerves.BuildAction
  def pre_download(build_plan, opts) do
    app = Keyword.fetch!(opts, :app)
    artifact_sites = Keyword.fetch!(opts, :artifact_sites)

    update_in(build_plan.packages, fn packages ->
      Enum.map(packages, fn
        %{app: ^app} = package ->
          artifact_path = maybe_override_artifact_path("NERVES_TOOLCHAIN", package.artifact_path)

          if artifact_path == package.artifact_path do
            tuple = TargetTuple.to_nerves_v1_host_tuple(build_plan.config[:host_tuple])

            if tuple == :error do
              Mix.raise("""
              The detected host tuple, #{inspect(build_plan.config[:host_tuple])}, is unknown by Nerves.

              This is an oversight, but may mean that a precompiled toolchain is not
              available. Please file an issue at https://github.com/nerves-project/nerves/issues/new.
              """)
            end

            archive_name =
              "#{app}-#{tuple}-#{package.version}-#{package.source_fingerprint}.tar.xz"

            archive_path = Path.join(package.download_path, archive_name)

            Map.merge(package, %{
              download_validators: [:archive],
              downloads: [
                %{
                  archive_path: archive_path,
                  filename: archive_name,
                  sites: artifact_sites,
                  version: package.version
                }
              ],
              extractors: [{:untar, source: archive_path, destination: artifact_path}]
            })
          else
            Map.merge(package, %{
              artifact_path: artifact_path,
              download_validators: [],
              downloads: [],
              extractors: []
            })
          end

        package ->
          package
      end)
    end)
  end

  @impl Nerves.BuildAction
  def post_extract(build_plan, opts) do
    app = Keyword.fetch!(opts, :app)
    artifact_path = BuildPlan.find_package(build_plan, app).artifact_path
    package_env = opts[:package_env] || []

    build_plan
    |> discover_toolchain(artifact_path)
    |> BuildPlan.merge_env(toolchain_env())
    |> BuildPlan.merge_env(package_env)
  end

  defp maybe_override_artifact_path(env_var_override, default_path) do
    case System.get_env(env_var_override) do
      nil ->
        default_path

      "" ->
        default_path

      path ->
        if File.dir?(path) do
          path
        else
          Mix.raise("$#{env_var_override} must point to an extracted artifact directory")
        end
    end
  end

  defp discover_toolchain(build_plan, artifact_path) do
    bin_path = Path.join(artifact_path, "bin")

    crosscompile =
      bin_path
      |> Path.join("*-gcc")
      |> Path.wildcard()
      |> choose_crosscompile()

    if is_nil(crosscompile) do
      Mix.raise("Could not find a cross-compiler in #{bin_path}")
    end

    build_plan
    |> BuildPlan.merge_env(%{
      "NERVES_TOOLCHAIN" => artifact_path,
      "CROSSCOMPILE" => crosscompile,
      "REBAR_TARGET_ARCH" => Path.basename(crosscompile)
    })
    |> BuildPlan.prepend_path(bin_path)
  end

  defp toolchain_env() do
    [
      {"AR", "${CROSSCOMPILE}-ar"},
      {"AS", "${CROSSCOMPILE}-as"},
      {"CC", "${CROSSCOMPILE}-gcc"},
      {"CXX", "${CROSSCOMPILE}-g++"},
      {"LD", "${CROSSCOMPILE}-ld"},
      {"STRIP", "${CROSSCOMPILE}-strip"}
    ]
  end

  defp choose_crosscompile([]), do: nil

  defp choose_crosscompile(gcc_paths) do
    gcc_paths
    |> Enum.find(List.first(gcc_paths), &String.contains?(&1, "buildroot"))
    |> String.replace_suffix("-gcc", "")
  end
end
