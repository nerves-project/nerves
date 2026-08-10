# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildAction.Trimmer do
  @moduledoc """
  Release step that trims out unneeded files in the release

  Examples of unneeded files are:
  * Start scripts for Windows and Linux
  * Source for boot scripts (only the term_to_binary version is actually used)

  This replaces functionality from the Nerves 1.x `scrub-otp-release.sh` script.
  """

  use Nerves.BuildAction

  @doc """
  Run the file trimmer step
  """
  @impl Nerves.BuildAction
  def post_assemble_steps(%Nerves.BuildPlan{} = _build_plan, %Mix.Release{} = release, _opts) do
    if not File.dir?(Path.join(release.path, "releases")) do
      Mix.raise("Expecting '#{release.path}' to contain an Erlang/OTP release")
    end

    remove_release_files!(release.path)

    release
  end

  defp remove_release_files!(release_path) do
    # Erase things like elixir.bat, env.sh, start.script, etc.
    Path.wildcard("#{release_path}/releases/**/*.{sh,bat,ps1,gz,script}")
    |> Enum.each(&File.rm!/1)

    # No Windows scripts
    Path.wildcard("#{release_path}/bin/*.bat")
    |> Enum.each(&File.rm!/1)

    # Remove build tools and script support
    Path.wildcard(
      "#{release_path}/erts-*/bin/{ct_run,dialyzer,erlc,escript,typer,yielding_c_fun}"
    )
    |> Enum.each(&File.rm!/1)
  end
end
