# SPDX-FileCopyrightText: 2020 Frank Hunleth
# SPDX-FileCopyrightText: 2024 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Firmware.Metadata do
  @shortdoc "Print out metadata for the current firmware"

  @moduledoc """
  This task calls `fwup` to report the firmware stored in the currently built
  firmware bundle. No firmware is built, so this task will fail if the firmware
  bundle doesn't exist.

  Note: Rebuilding firmware will almost certainly change the UUID if the build
  is not [reproducible](https://reproducible-builds.org/).

  ## Command line options

    * `--firmware <name>` - (Optional) The path to the fw file to use.
      Defaults to `<image_path>/<otp_app>.fw`

  ## Examples

  ```
  $ mix firmware.metadata
  meta-product="my_firmware"
  meta-description="A description"
  meta-version="1.0.0"
  meta-author="me"
  meta-platform="rpi"
  meta-architecture="arm"
  meta-creation-date="2020-01-31T21:15:25Z"
  meta-uuid="62f80587-ce82-59c4-4200-9c92df9849fd"
  ```
  """
  use Mix.Task
  alias Nerves.MixUtils
  alias Nerves.Preflight

  @switches [firmware: :string]
  @aliases [i: :firmware]

  @impl Mix.Task
  def run(argv) do
    Preflight.check!()
    MixUtils.debug_info("Nerves Metadata")

    {opts, _argv, _} = OptionParser.parse(argv, switches: @switches, aliases: @aliases)

    fw =
      cond do
        opts[:firmware] ->
          Path.expand(opts[:firmware])

        Mix.target() != :host ->
          Nerves.build_plan().config[:firmware_path]

        true ->
          Mix.raise(
            "Either specify a firmware path via --firmware or set MIX_TARGET to a supported target"
          )
      end

    if not File.exists?(fw) do
      Mix.raise("Firmware not found at #{fw} run `mix firmware` to build")
    end

    MixUtils.shell("fwup", ["-m", "-i", fw])
  end
end
