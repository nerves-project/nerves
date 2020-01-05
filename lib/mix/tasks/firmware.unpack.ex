defmodule Mix.Tasks.Firmware.Unpack do
  use Mix.Task
  import Mix.Nerves.Utils
  alias Mix.Nerves.Preflight

  @shortdoc "Unpack a firmware bundle for inspection"

  @moduledoc """
  Unpack the firmware so that its contents can be inspected locally.

  ## Usage

      mix firmware.unpack [output directory]

  If not supplied, the output directory will be based off the OTP application
  name.

  ## Examples

  ```
  # Create a firmware bundle. It will be under the _build directory
  mix firmware

  # Unpack it
  mix firmware.unpack firmware_contents

  # Inspect it
  ls firmware_contents
  ```
  """

  @impl true
  def run([output_path]) do
    Preflight.check!()
    debug_info("Nerves Firmware Unpack")

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

    unpack(fw, output_path)
  end

  def run([]) do
    config = Mix.Project.config()
    otp_app = config[:app]
    target = mix_target()

    file = "#{otp_app}-#{target}"
    run([file])
  end

  def run(_args) do
    Mix.raise("""
    mix firmware.unpack [output path]

    See mix help firmware.unpack for more info
    """)

    Mix.Task.run("help", ["firmware.unpack"])
  end

  defp unpack(fw, output_path) do
    abs_output_path = Path.expand(output_path)
    rootfs_output_path = Path.join(abs_output_path, "rootfs")
    rootfs_image = Path.join([abs_output_path, "data", "rootfs.img"])

    Mix.shell().info("Unpacking to #{output_path}...")

    _ = File.rm_rf!(abs_output_path)

    File.mkdir_p!(abs_output_path)

    {_, 0} = shell("unzip", [fw, "-d", abs_output_path])

    {_, 0} = shell("unsquashfs", ["-d", rootfs_output_path, rootfs_image])

    :ok
  end
end
