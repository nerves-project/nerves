defmodule Mix.Tasks.Firmware.Image do
  use Mix.Task
  import Mix.Nerves.Utils

  @shortdoc "Create a firmware image file"

  @moduledoc """
  Create a firmware image file that can be copied byte-for-byte to an SDCard
  or other memory device.

  ## Usage

      mix firmware.image [my_image.img]

  If not supplied, the output image file will be based off the OTP application
  name.

  ## Example

  ```
  # Create the image file
  mix firmware.image my_image.img

  # Write it to a MicroSD card in Linux
  dd if=my_image.img of=/dev/sdc bs=1M
  ```
  """
  def run([file]) do
    preflight()
    debug_info("Nerves Firmware Image")

    config = Mix.Project.config()
    otp_app = config[:app]
    target = config[:target]

    images_path = Mix.Tasks.Firmware.images_path(config)

    check_nerves_system_is_set!()

    check_nerves_toolchain_is_set!()

    fw = Mix.Tasks.Firmware.fw_path(images_path, otp_app)

    unless File.exists?(fw) do
      Mix.raise("Firmware for target #{target} not found at #{fw} run `mix firmware` to build")
    end

    file = Path.expand(file)

    image(fw, file)
  end

  def run([]) do
    otp_app = Mix.Project.config()[:app]
    file = "#{otp_app}.img"
    run([file])
  end

  def run(_args) do
    Mix.raise("""
    mix firmware.image [my_image.img]

    See mix help firmware.image for more info
    """)

    Mix.Task.run("help", ["firmware.image"])
  end

  defp image(fw, file) do
    Mix.shell().info("Writing to #{file}...")
    args = ["-a", "-i", fw, "-t", "complete", "-d", file]
    cmd = "fwup"
    shell(cmd, args)
  end
end
