# SPDX-FileCopyrightText: 2016 Justin Schneck
# SPDX-FileCopyrightText: 2017 Frank Hunleth
# SPDX-FileCopyrightText: 2017 Greg Mefford
# SPDX-FileCopyrightText: 2022 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Package do
  @moduledoc """
  Defines a Nerves package struct and helper functions.

  A Nerves package is a Mix application that defines the configuration for a
  Nerves system or Nerves toolchain. For more details, see the Nerves
  [system documentation](https://hexdocs.pm/nerves/systems.html#package-configuration)
  """

  alias Nerves.Artifact

  defstruct app: nil,
            path: nil,
            dep: nil,
            env: [],
            type: nil,
            version: nil,
            platform: nil,
            build_runner: nil,
            compilers: [],
            dep_opts: [],
            config: []

  @type t :: %__MODULE__{
          app: atom,
          path: binary,
          env: %{String.t() => String.t()},
          type:
            :system
            | :package
            | :toolchain
            | :system_platform
            | :toolchain_platform,
          dep:
            :project
            | :path
            | :hex
            | :git,
          platform: atom,
          build_runner: {module(), Keyword.t()},
          compilers: [atom],
          dep_opts: Keyword.t(),
          version: Version.t(),
          config: Keyword.t()
        }

  @required [:type, :platform]

  @doc """
  Loads the Nerves package configuration for an app
  """
  @spec load_config({Application.app(), Path.t()}) :: Nerves.Package.t()
  def load_config({app, path}) do
    config = config(app, path)

    type = config[:nerves_package][:type]
    platform = config[:nerves_package][:platform]
    nerves_package_config = Enum.reject(config[:nerves_package], fn {k, _v} -> k in @required end)

    if !type do
      Mix.shell().error(
        "The Nerves package #{app} does not define a type.\n\n" <>
          "Verify that the key exists.\n"
      )

      exit({:shutdown, 1})
    end

    %__MODULE__{
      app: app,
      version: config[:version],
      type: type,
      platform: platform,
      env: Map.new(nerves_package_config[:env] || %{}),
      build_runner: Artifact.build_runner(config),
      compilers: config[:compilers] || Mix.compilers(),
      dep_opts: nerves_options_on_dep(app),
      dep: dep_type(app),
      path: path,
      config: nerves_package_config
    }
  end

  # Return the nerves options that the user specified on the dependency
  # E.g.,
  #  {:nerves_system_rpi4, "~> 1.28", runtime: false, targets: :rpi4, nerves: [compile: true]}
  #                                                                           ^^^^^^^^^^^^^^^
  defp nerves_options_on_dep(app) do
    load_env_deps()
    |> Enum.find(%{}, &(&1.app == app))
    |> Map.get(:opts, [])
    |> Keyword.get(:nerves, [])
  end

  if Version.match?(System.version(), ">= 1.16.0") do
    defp load_env_deps() do
      Mix.Dep.Converger.converge(env: Mix.env())
    end
  else
    defp load_env_deps() do
      # deprecated in Elixir >= 1.16.0
      Mix.Dep.load_on_environment(env: Mix.env())
    end
  end

  @doc """
  Starts an interactive shell with the working directory set
  to the package path
  """
  @spec shell(Nerves.Package.t() | nil) :: :ok
  def shell(nil) do
    Mix.raise("Package is not loaded in your Nerves Environment.")
  end

  def shell(%{platform: nil, app: app}) do
    Mix.raise("Cannot start shell for #{app}")
  end

  def shell(pkg) do
    pkg.build_runner.shell(pkg)
  end

  @doc """
  Get Mix.Project config for an application
  """
  @spec config(Application.app(), Path.t()) :: Keyword.t()
  def config(app, path) do
    case Mix.Project.config()[:app] do
      ^app -> Mix.Project.config()
      _other_app -> Mix.Project.in_project(app, path, fn _mod -> Mix.Project.config() end)
    end
  end

  defp dep_type(pkg) do
    deps_paths = Mix.Project.deps_paths()

    case Map.get(deps_paths, pkg) do
      nil ->
        :project

      path ->
        deps_path =
          File.cwd!()
          |> Path.join(Mix.Project.config()[:deps_path])
          |> Path.expand()

        if String.starts_with?(path, deps_path) do
          :hex
        else
          :path
        end
    end
  end
end
