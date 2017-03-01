defmodule Mix.Tasks.Firmware do
  use Mix.Task
  import Mix.Nerves.Utils

  @moduledoc """
  Build a firmware image for the selected target platform.

  This task builds the project, combines the generated OTP release with
  a Nerves system image, and creates a `.fw` file that may be written
  to an SDCard or sent to a device.

  ## Environment variables

    * `NERVES_SYSTEM` - may be set to a local directory to specify the Nerves
      system image that is used

    * `NERVES_TOOLCHAIN` - may be set to a local directory to specify the
      Nerves toolchain (C/C++ crosscompiler) that is used
  """
  def run(_args) do
    preflight()
    debug_info "Nerves Firmware Assembler"

    system_path = System.get_env("NERVES_SYSTEM") || Mix.raise """
      Environment variable $NERVES_SYSTEM is not set
    """

    System.get_env("NERVES_TOOLCHAIN") || Mix.raise """
      Environment variable $NERVES_TOOLCHAIN is not set
    """

    rel_config =
      File.cwd!
      |> Path.join("rel/config.exs")

    unless File.exists?(rel_config) do
      Mix.raise """
        You are missing a release config file. Run  nerves.release.init task first
      """
    end

    Mix.Task.run "compile", []

    Mix.Nerves.IO.shell_info "Building OTP Release..."

    clean_release()
    build_release()
    build_firmware(system_path)
  end

  def result({_ , 0}), do: nil
  def result({result, _}), do: Mix.raise """
  Nerves encountered an error. #{inspect result}
  """

  defp clean_release do
    try do
      Mix.Task.run "release.clean", ["--implode", "--no-confirm"]
    catch
      :exit, _ -> :noop
    end
  end

  defp build_release do
    Mix.Task.run "release", ["--silent"]
  end

  defp build_firmware(system_path) do
    config = Mix.Project.config
    otp_app = config[:app]
    images_path =
      (config[:images_path] || Path.join([Mix.Project.build_path, "nerves", "images"]))
      |> Path.expand

    unless File.exists?(images_path) do
      File.mkdir_p(images_path)
    end

    firmware_config = Application.get_env(:nerves, :firmware)
    rel2fw_path = Path.join(system_path, "scripts/rel2fw.sh")
    cmd = "bash"
    args = [rel2fw_path]
    rootfs_additions =
      case firmware_config[:rootfs_additions] do
        nil -> []
        rootfs_additions ->
          rfs = File.cwd!
          |> Path.join(rootfs_additions)
          ["-a", rfs]
      end
    fwup_conf =
      case firmware_config[:fwup_conf] do
        nil -> []
        fwup_conf ->
          fw_conf = File.cwd!
          |> Path.join(fwup_conf)
          ["-c", fw_conf]
      end
    fw = ["-f", "#{images_path}/#{otp_app}.fw"]
    release_path =
      Mix.Project.build_path()
      |> Path.join("rel/#{otp_app}")
    output = [release_path]
    args = args ++ fwup_conf ++ rootfs_additions ++ fw ++ output

    shell(cmd, args)
    |> result
  end
end
