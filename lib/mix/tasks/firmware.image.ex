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
  import Mix.Nerves.Utils
  alias Mix.Nerves.Preflight

  @impl Mix.Task
  def run([file]) do
    Preflight.check!()
    debug_info("Nerves Firmware Image")

    # Call "mix firmware" to ensure that the firmware bundle is up-to-date
    Mix.Task.run("firmware", [])

    config = Mix.Project.config()
    otp_app = config[:app]
    target = mix_target()

    images_path =
      (config[:images_path] || Path.join([Mix.Project.build_path(), "nerves", "images"]))
      |> Path.expand()

    _ = check_nerves_system_is_set!()

    _ = check_nerves_toolchain_is_set!()

    fw = "#{images_path}/#{otp_app}.fw"

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
