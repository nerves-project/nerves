# SPDX-FileCopyrightText: 2016 Frank Hunleth
# SPDX-FileCopyrightText: 2016 Justin Schneck
# SPDX-FileCopyrightText: 2017 Dorian Karter
# SPDX-FileCopyrightText: 2017 Greg Mefford
# SPDX-FileCopyrightText: 2018 Wojtek Mach
# SPDX-FileCopyrightText: 2020 Jon Carstens
# SPDX-FileCopyrightText: 2025 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Firmware do
  @shortdoc "Build a firmware bundle"

  @moduledoc """
  Build a firmware image for the selected target platform.

  This is a convenience wrapper around `mix release`. The firmware image
  is created as a release step, so `mix release` produces the same `.fw`
  file when the project is configured with `Nerves.BuildAction` actions.

  ## Command line options

    * `--verbose` - produce detailed output about release assembly

  ## Environment variables

    * `NERVES_SYSTEM`    - may be set to a local directory to specify the Nerves
      system image that is used

    * `NERVES_TOOLCHAIN` - may be set to a local directory to specify the
      Nerves toolchain (C/C++ cross-compiler) that is used
  """
  use Mix.Task

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(args) do
    if Mix.target() == :host do
      Mix.raise("""
      mix firmware requires a Mix target to be set.

      If you want to run locally on host, use the normal Elixir build commands:

          mix compile
          iex -S mix

      If you really wanted to build for a hardware device, set the MIX_TARGET
      like the following:

          MIX_TARGET=rpi0 mix firmware
      """)
    end

    Nerves.HostElixirCheck.check!()

    Mix.Task.run("release", args)
  end
end
