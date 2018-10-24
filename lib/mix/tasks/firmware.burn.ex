defmodule Mix.Tasks.Firmware.Burn do
  use Mix.Task

  @shortdoc "Build a firmware bundle and write it to an SDCard"

  @moduledoc """

  This task calls `mix firmware` & `mix burn` to burn a new firmware to a SDCard

  ## Command line options

    * `--device <filename>` - skip SDCard detection and write the image to
      the specified filename. SDCard paths depend on the operating system, but
      have a form like `/dev/sdc` or `/dev/mmcblk0`. You may also specify a
      filename to create an image that can be used with a bulk memory programmer
      or copied to an SDCard manually with a utility like `dd`.

    * `--task <name>` - apply the specified `fwup` task. See the `fwup.conf`
      file that was used to create the firmware image for options. By
      convention, the `complete` task writes everything to the SDCard including
      bootloaders and application data partitions. The `upgrade` task only
      modifies the parts of the SDCard required to run the new software.

    * `--verbose` - produce detailed output about release assembly

  ## Environment variables

    * `NERVES_SYSTEM`    - may be set to a local directory to specify the Nerves
      system image that is used

    * `NERVES_TOOLCHAIN` - may be set to a local directory to specify the
      Nerves toolchain (C/C++ crosscompiler) that is used

  ## Examples

  ```
  # Upgrade the contents of the SDCard at /dev/mmcblk0 using the rpi0 system
  NERVES_SYSTEM=rpi0 mix firmware.burn --device /dev/mmcblk0 --task upgrade
  ```
  """
  def run(args) do
    # Simply delegate to the proper tasks
    Mix.Task.run("firmware", args)
    Mix.Task.run("burn", args)
  end
end
