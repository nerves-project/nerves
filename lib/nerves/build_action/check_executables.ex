# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildAction.CheckExecutables do
  @moduledoc """
  Verify all executables were built for the right architecture

  This catches binaries built for the wrong architecture. In practice, this is almost always
  due to libraries that build to their source directories. Those tend to install host binaries
  on the target which will crash on start.

  This replaces functionality from the Nerves 1.x `scrub-otp-release.sh` script.
  """
  use Nerves.BuildAction

  alias Nerves.BinInfo
  alias Nerves.Paths

  @doc """
  Run the scrub step
  """
  @impl Nerves.BuildAction
  def post_assemble_steps(%Nerves.BuildPlan{} = _build_plan, %Mix.Release{} = release, _opts) do
    check_executable_types!(release.path)

    release
  end

  defp check_executable_types!(release_path) do
    paths = Paths.executable_paths(release_path)
    beam_smp = Enum.find(paths, &String.ends_with?(&1, "beam.smp"))

    if beam_smp == nil do
      Mix.raise("""
      beam.smp not found in release.
      """)
    end

    expected_info = executable_info(beam_smp)

    if expected_info == :error do
      Mix.raise("""
      Error reading beam.smp's header

      It might be corrupt. Try building clean.
      """)
    end

    Enum.each(paths, &check_executable_info!(&1, expected_info))
  end

  defp check_executable_info!(path, expected_type) do
    case executable_info(path) do
      :error -> :ok
      ^expected_type -> :ok
      %{type: :script} -> :ok
      actual_type -> unexpected_executable_type!(path, actual_type, expected_type)
    end
  end

  defp executable_info(path) do
    case BinInfo.read(path) do
      {:ok, info} -> info
      :error -> :error
    end
  end

  @spec unexpected_executable_type!(Path.t(), BinInfo.info(), BinInfo.info()) :: no_return()
  defp unexpected_executable_type!(path, actual_type, expected_type) do
    Mix.raise("""
    Unexpected executable format for '#{path}'

    Got:
     #{inspect(actual_type)}

    Expecting:
     #{inspect(expected_type)}

    This file was compiled for the host or a different target and probably will not work.

    If you are very sure you know what you are doing, place an empty file in the same
    directory as the offending file(s) called '.noscrub'. This disables scrubbing for
    that directory.
    """)
  end
end
