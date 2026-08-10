# SPDX-FileCopyrightText: 2016 Justin Schneck
# SPDX-FileCopyrightText: 2017 Connor Rigby
# SPDX-FileCopyrightText: 2017 Frank Hunleth
# SPDX-FileCopyrightText: 2018 Wojtek Mach
# SPDX-FileCopyrightText: 2019 Greg Mefford
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Firmware.Image do
  @shortdoc "Create a firmware image file"

  @moduledoc """
  Create a firmware image file that can be copied byte-for-byte to an SDCard
  or other memory device.

  ## Usage

      mix firmware.image [my_image.img]

  If not supplied, the output image file will be based off the OTP application
  name.

  ## Examples

  ```
  # Create the image file
  mix firmware.image my_image.img

  # Write it to a MicroSD card in Linux
  dd if=my_image.img of=/dev/sdc bs=1M
  ```
  """
  use Mix.Task
  alias Nerves.MixUtils
  alias Nerves.Preflight

  @impl Mix.Task
  def run(args) do
    Preflight.check!()
    MixUtils.debug_info("Nerves Firmware Image")

    # Call "mix firmware" to ensure that the firmware bundle is up-to-date
    Mix.Task.run("firmware", [])

    build_plan = Nerves.build_plan()
    fw = build_plan.config[:firmware_path]

    if !File.exists?(fw) do
      Mix.raise(
        "Firmware for target #{Mix.target()} not found at #{fw} run `mix firmware` to build"
      )
    end

    output =
      case args do
        [path] -> path
        _ -> Path.expand(Path.basename(fw, ".fw") <> ".img")
      end

    image(fw, output)
  end

  defp image(fw, file) do
    MixUtils.info("Writing to #{file}...")
    args = ["-a", "-i", fw, "-t", "complete", "-d", file]
    cmd = "fwup"
    MixUtils.shell(cmd, args)
  end
end
