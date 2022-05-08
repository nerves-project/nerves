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
  import Mix.Nerves.Utils
  alias Mix.Nerves.Preflight

  @switches [firmware: :string]
  @aliases [i: :firmware]

  @impl Mix.Task
  def run(argv) do
    Preflight.check!()
    debug_info("Nerves Metadata")

    {opts, _argv, _} = OptionParser.parse(argv, switches: @switches, aliases: @aliases)

    target = mix_target()

    _ = check_nerves_system_is_set!()

    _ = check_nerves_toolchain_is_set!()

    fw = firmware_file(opts)

    unless File.exists?(fw) do
      Mix.raise("Firmware for target #{target} not found at #{fw} run `mix firmware` to build")
    end

    shell("fwup", ["-m", "-i", fw])
  end

  @spec firmware_file(keyword()) :: String.t()
  def firmware_file(opts) do
    with {:ok, fw} <- Keyword.fetch(opts, :firmware),
         fw <- Path.expand(fw),
         true <- File.exists?(fw) do
      fw
    else
      false ->
        fw = Keyword.get(opts, :firmware)

        Mix.raise("The firmware file #{fw} does not exist")

      _ ->
        Nerves.Env.firmware_path()
    end
  end
end
