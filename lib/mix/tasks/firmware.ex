defmodule Mix.Tasks.Firmware do
  use Mix.Task
  import Mix.Nerves.Utils

  @switches [verbosity: :string]

  @moduledoc """
  Build a firmware image for the selected target platform.

  This task builds the project, combines the generated OTP release with
  a Nerves system image, and creates a `.fw` file that may be written
  to an SDCard or sent to a device.

  ## Command line options

    * `--verbosity=[silent|quiet|normal|verbose]` - set the verbosity level

  ## Environment variables

    * `NERVES_SYSTEM` - may be set to a local directory to specify the Nerves
      system image that is used

    * `NERVES_TOOLCHAIN` - may be set to a local directory to specify the
      Nerves toolchain (C/C++ crosscompiler) that is used
  """
  def run(args) do
    preflight()

    {opts, _, _} = OptionParser.parse(args, switches: @switches)
    debug_info "Nerves Firmware Assembler"
    config = Mix.Project.config
    otp_app = config[:app]
    target = config[:target]
    verbosity = opts[:verbosity] || "normal"

    firmware_config = Application.get_env(:nerves, :firmware)

    system_path = System.get_env("NERVES_SYSTEM") || raise """
      Environment variable $NERVES_SYSTEM is not set
    """

    System.get_env("NERVES_TOOLCHAIN") || raise """
      Environment variable $NERVES_TOOLCHAIN is not set
    """
    Mix.Task.run "compile", []
    Mix.Task.run "release", ["--verbosity=#{verbosity}"]

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
    fw = ["-f", "_images/#{target}/#{otp_app}.fw"]
    release_path =
      Mix.Project.build_path()
      |> Path.join("rel/#{otp_app}")
    output = [release_path]
    args = args ++ fwup_conf ++ rootfs_additions ++ fw ++ output

    shell(cmd, args)
    |> result
  end

  def result({_ , 0}), do: nil
  def result({result, _}), do: Mix.raise """
  Nerves encountered an error. #{inspect result}
  """

end
