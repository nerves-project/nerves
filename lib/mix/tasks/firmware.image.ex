defmodule Mix.Tasks.Firmware.Image do
  use Mix.Task
  import Mix.Nerves.Utils

  @moduledoc """
  Writes the generated firmware image to an output file.

  ## Examples

  ```
  # Create an image file from a .fw file for use with dd(1)
  mix firmware.image my_image.img
  ```
  """
  def run([file]) do
    preflight()
    debug_info "Nerves Firmware Image"

    config = Mix.Project.config
    otp_app = config[:app]
    target = config[:target]
    images_path =
      (config[:images_path] || Path.join([Mix.Project.build_path, "nerves", "images"]))
      |> Path.expand

    System.get_env("NERVES_SYSTEM") || raise """
      Environment variable $NERVES_SYSTEM is not set
    """

    System.get_env("NERVES_TOOLCHAIN") || raise """
      Environment variable $NERVES_TOOLCHAIN is not set
    """

    fw = "#{images_path}/#{otp_app}.fw"
    unless File.exists?(fw) do
      Mix.raise "Firmware for target #{target} not found at #{fw} run `mix firmware` to build"
    end

    file = Path.expand(file)

    image(fw, file)
  end

  def run(_args) do
    Mix.raise """
    mix firmware.image takes a single argument
    See mix help firmware.image for more info
    """
    Mix.Task.run "help", ["firmware.image"]
  end

  defp image(fw, file) do
    args = ["-a", "-i", fw, "-t", "complete", "-d", file]
    cmd = "fwup"
    shell(cmd, args)
  end

end
