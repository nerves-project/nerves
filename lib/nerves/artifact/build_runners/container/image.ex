# SPDX-FileCopyrightText: 2026 Thomas Winkler
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.BuildRunners.Container.Image do
  @moduledoc false
  import Nerves.Artifact.BuildRunners.Container.Utils

  @doc false
  @spec create(Path.t(), String.t()) :: :ok
  def create(containerfile, tag) do
    path = Path.dirname(containerfile)
    args = ["build", "--tag", tag, path]
    shell_info("Create image")

    if Mix.shell().yes?("The Nerves container build_runner needs to create the image.\nProceed? ") do
      case Mix.Nerves.Utils.shell("container", args) do
        {_, 0} -> :ok
        _ -> Mix.raise("Nerves container build_runner could not create image #{tag}")
      end
    else
      Mix.raise("Unable to use Nerves container build_runner without image")
    end
  end

  @doc false
  @spec pull(String.t()) :: boolean()
  def pull(tag) do
    shell_info("Trying to pull image")

    case Nerves.Port.cmd("container", ["image", "pull", tag], stderr_to_stdout: true) do
      {_, 0} -> true
      {_reason, _} -> false
    end
  end

  @doc false
  @spec exists?(String.t()) :: boolean()
  def exists?(tag) do
    case System.cmd("container", ["image", "inspect", tag], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  end
end
