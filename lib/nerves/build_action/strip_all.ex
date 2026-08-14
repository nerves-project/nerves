# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildAction.StripAll do
  @moduledoc """
  Release step that strips debug information out of release binaries

  This replaces functionality from the Nerves 1.x `scrub-otp-release.sh` script.
  """
  use Nerves.BuildAction

  import Bitwise

  alias Nerves.BuildPlan
  alias Nerves.BinInfo
  alias Nerves.MixUtils
  alias Nerves.Paths

  @doc """
  Run the strip all step
  """
  @impl Nerves.BuildAction
  def post_assemble_steps(%BuildPlan{} = build_plan, %Mix.Release{} = release, _opts) do
    strip = BuildPlan.get_interpolated_env(build_plan)["STRIP"]

    if strip == nil do
      Mix.raise(
        "Expecting a Nerves package to provide $STRIP in the environment. Usually this is a toolchain"
      )
    end

    Paths.executable_paths(release.path)
    |> Enum.filter(&(BinInfo.file_type(&1) == :elf))
    |> Enum.each(&run_strip(&1, strip))

    release
  end

  defp make_writable!(path) do
    %{mode: mode} = File.lstat!(path)
    new_mode = mode ||| 0o200
    if new_mode != mode, do: File.chmod!(path, new_mode)
  end

  defp run_strip(path, strip) do
    # Some binaries get installed read-only. This doesn't matter
    # for what will end up as a read-only filesystem, so mark writable
    # so that strip will work.
    make_writable!(path)

    case System.cmd(strip, [path], stderr_to_stdout: true) do
      {_, 0} -> :ok
      _ -> failed_strip(path)
    end
  end

  defp failed_strip(path) do
    MixUtils.warning("""
    WARNING: Can't remove debug symbols from #{path}.

    This is expected for precompiled Rust.
    """)
  end
end
