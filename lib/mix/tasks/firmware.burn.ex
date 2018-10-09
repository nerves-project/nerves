defmodule Mix.Tasks.Firmware.Burn do
  use Mix.Task
  import Mix.Nerves.Utils
  alias Nerves.Utils.WSL

  @switches [device: :string, task: :string]
  @aliases [d: :device, t: :task]

  @shortdoc "Write a firmware image to an SDCard"

  @moduledoc """
  Writes the generated firmware image to an attached SDCard or file.

  By default, this task detects attached SDCards and then invokes `fwup`
  to overwrite the contents of the selected SDCard with the new image.
  Data on the SDCard will be lost, so be careful.

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

  ## Examples

  ```
  # Upgrade the contents of the SDCard located at /dev/mmcblk0
  mix firmware.burn --device /dev/mmcblk0 --task upgrade
  ```
  """
  def run(argv) do
    preflight()
    debug_info("Nerves Firmware Burn")

    {opts, argv, _} = OptionParser.parse(argv, switches: @switches, aliases: @aliases)

    config = Mix.Project.config()
    firmware_config = Application.get_env(:nerves, :firmware)
    otp_app = config[:app]
    target = config[:target]

    images_path =
      (config[:images_path] || Path.join([Mix.Project.build_path(), "nerves", "images"]))
      |> Path.expand()

    check_nerves_system_is_set!()

    check_nerves_toolchain_is_set!()

    fw = "#{images_path}/#{otp_app}.fw"

    unless File.exists?(fw) do
      Mix.raise("Firmware for target #{target} not found at #{fw} run `mix firmware` to build")
    end

    {fw, firmware_location} = WSL.make_file_accessible(fw, WSL.running_on_wsl?(), WSL.has_wslpath?())

    dev =
      case opts[:device] do
        nil -> prompt_dev()
        dev -> dev
      end

    set_provisioning(firmware_config[:provisioning])
    burn(fw, dev, opts, argv)

    # Remove the temporary .fw file
    WSL.cleanup_file(fw, firmware_location)
  end

  defp burn(fw, dev, opts, argv) do
    task = opts[:task] || "complete"
    args = ["-a", "-i", fw, "-t", task, "-d", dev] ++ argv

    {cmd, args} =
      case :os.type() do
        {_, :darwin} ->
          {"fwup", args}

        {_, :linux} ->
          if WSL.running_on_wsl?() do
            WSL.admin_powershell_command("fwup", Enum.join(args, " "))
          else
            case File.stat(dev) do
              {:ok, %File.Stat{access: :read_write}} ->
                {"fwup", args}

              _ ->
                fwup = System.find_executable("fwup")
                ask_pass = System.get_env("SUDO_ASKPASS") || "/usr/bin/ssh-askpass"
                System.put_env("SUDO_ASKPASS", ask_pass)
                {"sudo", provision_env() ++ [fwup] ++ args}
            end
          end

        {_, :nt} ->
          {"fwup", args}

        {_, type} ->
          raise "Unable to burn firmware on your host #{inspect(type)}"
      end

    shell(cmd, args)
  end

  # This is a fix for linux when running through sudo.
  # Sudo will strip the environment and therefore any variables
  # that are set during device provisioning.
  def provision_env() do
    System.get_env()
    |> Enum.filter(fn {k, _} ->
      String.starts_with?(k, "NERVES_") or String.equivalent?(k, "SERIAL_NUMBER")
    end)
    |> Enum.map(fn {k, v} -> k <> "=" <> v end)
  end
end
