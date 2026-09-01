# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildPlanHelpers do
  @moduledoc false
  import ExUnit.Callbacks

  alias Nerves.MixPackage

  @spec reset_plan() :: :ok
  def reset_plan() do
    :persistent_term.erase({Nerves, :build_plan})

    on_exit(fn ->
      :persistent_term.erase({Nerves, :build_plan})
    end)
  end

  @spec load_package(atom()) :: MixPackage.t()
  def load_package(app) do
    path = Path.expand("test/fixtures/build_plans/#{app}")

    Mix.Project.in_project(app, path, fn _ ->
      config = Mix.Project.config()

      %MixPackage{
        app: app,
        config: config,
        dest: path,
        deps: []
      }
    end)
  end

  @spec package_info(atom(), String.t(), String.t()) :: map()
  def package_info(app, package_path, artifact_path) do
    %{
      app: app,
      path: package_path,
      version: "1.0.0",
      artifact_path: artifact_path,
      deps: [],
      download_path: "/downloads/#{app}",
      download_validators: [],
      downloads: [],
      extractors: [],
      source_fingerprint: "ABC123",
      source_fingerprint_files: ["mix.exs"],
      validated_files: [],
      dockerfile: nil
    }
  end
end
