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
      build_script: "",
      shell_setup_script: ""
    }
  end

  @spec delete_env(String.t()) :: :ok
  def delete_env(name) when is_binary(name) do
    case System.get_env(name) do
      nil ->
        :ok

      value ->
        System.delete_env(name)
        on_exit(fn -> System.put_env(name, value) end)
    end
  end

  @spec put_env(String.t(), String.t() | nil) :: :ok
  def put_env(name, value) when is_binary(name) and is_binary(value) do
    case System.get_env(name) do
      nil -> on_exit(fn -> System.delete_env(name) end)
      old_value -> on_exit(fn -> System.put_env(name, old_value) end)
    end

    System.put_env(name, value)
  end

  def put_env(name, nil), do: delete_env(name)

  @spec put_env(map()) :: :ok
  def put_env(map) do
    Enum.each(map, fn {k, v} -> put_env(k, v) end)
  end

  @spec host_tuple() :: String.t()
  def host_tuple() do
    {_, os} = :os.type()

    arch =
      :erlang.system_info(:system_architecture)
      |> to_string()
      |> String.split("-")
      |> List.first()

    case "#{os}_#{arch}" do
      "darwin_aarch64" -> "darwin_arm"
      host -> host
    end
  end
end
