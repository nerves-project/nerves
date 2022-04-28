defmodule Mix.Tasks.Burn do
  use Mix.Task
  import Mix.Nerves.Utils
  alias Mix.Nerves.{FwupStream, Preflight}
  alias Nerves.Utils.WSL

  @switches [device: :string, task: :string, firmware: :string, overwrite: :boolean]
  @aliases [d: :device, t: :task, i: :firmware]

  @shortdoc "Write a firmware image to an SDCard"

  @moduledoc """
  Writes the generated firmware image to an attached SDCard or file.

  By default, this task detects attached SDCards and then invokes `fwup`
  to upgrade the contents of the selected SDCard with the new image.
  If the upgrade to the next parition fails, it will then attempt to
  completely overwrite the SDCard with the new image.

  ## Command line options

    * `--device <filename>` - skip SDCard detection and write the image to
      the specified filename. SDCard paths depend on the operating system, but
      have a form like `/dev/sdc` or `/dev/mmcblk0`. You may also specify a
      filename to create an image that can be used with a bulk memory programmer
      or copied to an SDCard manually with a utility like `dd`.

    * `--task <name>` - apply the specified `fwup` task. See the `fwup.conf`
      file that was used to create the firmware image for options. By
      convention, the `complete` task writes everything to the SDCard including
      bootloader and application data partitions. The `upgrade` task only
      modifies the parts of the SDCard required to run the new software.
      Defaults to `upgrade`

    * `--firmware <name>` - (Optional) The path to the fw file to use.
      Defaults to `<image_path>/<otp_app>.fw`

    * `--overwrite` - (Optional) Overwrite the contents of the SDCard by
      forcing the `complete` task. Defaults to `false`

  ## Examples

  ```
  # Upgrade the contents of the SDCard located at /dev/mmcblk0
  mix burn --device /dev/mmcblk0 --task upgrade
  ```
  """

  @impl true
  def run(argv) do
    Preflight.check!()
    debug_info("Nerves Burn")

    {opts, argv, _} = OptionParser.parse(argv, switches: @switches, aliases: @aliases)

    firmware_config = Application.get_env(:nerves, :firmware)

    target = mix_target()

    _ = check_nerves_system_is_set!()

    _ = check_nerves_toolchain_is_set!()

    fw = firmware_file(opts)

    unless File.exists?(fw) do
      Mix.raise("Firmware for target #{target} not found at #{fw} run `mix firmware` to build")
    end

    {fw, firmware_location} =
      WSL.make_file_accessible(fw, WSL.running_on_wsl?(), WSL.has_wslpath?())

    dev =
      case opts[:device] do
        nil -> prompt_dev()
        dev -> dev
      end

    task = if opts[:overwrite], do: "complete", else: opts[:task] || "upgrade"

    set_provisioning(firmware_config[:provisioning])

    burn(fw, dev, task, argv)

    # Remove the temporary .fw file
    WSL.cleanup_file(fw, firmware_location)
  end

  defp burn(fw, dev, task, argv) do
    args = ["-a", "-i", fw, "-t", task, "-d", dev] ++ argv

    os = get_os!()

    {cmd, args} = cmd_and_args_for_os(os, args, dev)

    shell(cmd, args, stream: FwupStream.new())
    |> format_result(task)
    |> case do
      :failed_not_upgradable ->
        Mix.shell().info("""
        #{IO.ANSI.yellow()}
        Device #{dev} either doesn't have firmware on it or has incompatible firmware.
        Going to burn the whole MicroSD card so that it's in a factory-default state.
        #{IO.ANSI.default_color()}
        """)

        burn(fw, dev, "complete", argv)

      result ->
        result
    end
  end

  # Requests an elevation of user through askpass
  @doc false
  def elevate_user() do
    ask_pass = System.get_env("SUDO_ASKPASS") || "/usr/bin/ssh-askpass"
    System.put_env("SUDO_ASKPASS", ask_pass)
  end

  # This is a fix for linux when running through sudo.
  # Sudo will strip the environment and therefore any variables
  # that are set during device provisioning.
  @doc false
  def provision_env() do
    System.get_env()
    |> Enum.filter(fn {k, _} ->
      String.starts_with?(k, "NERVES_") or String.equivalent?(k, "SERIAL_NUMBER")
    end)
    |> Enum.map(fn {k, v} -> k <> "=" <> v end)
  end

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

  defp get_os!() do
    case :os.type() do
      {_, :linux} ->
        if WSL.running_on_wsl?(), do: :wsl, else: :linux

      {_, os} when os in [:darwin, :nt] ->
        os

      {_, os} ->
        raise "Unable to burn firmware on your host #{inspect(os)}"
    end
  end

  defp cmd_and_args_for_os(:linux, args, dev) do
    fwup = System.find_executable("fwup")

    case File.stat(dev) do
      {:ok, %File.Stat{access: :read_write}} ->
        {"fwup", args}

      {:error, :enoent} ->
        case File.touch(dev, System.os_time(:second)) do
          :ok ->
            {"fwup", args}

          {:error, :eacces} ->
            elevate_user()
            {"sudo", provision_env() ++ [fwup] ++ args}
        end

      _ ->
        elevate_user()
        {"sudo", provision_env() ++ [fwup] ++ args}
    end
  end

  defp cmd_and_args_for_os(:wsl, args, _dev) do
    WSL.admin_powershell_command("fwup", Enum.join(args, " "))
  end

  defp cmd_and_args_for_os(_os, args, _dev), do: {"fwup", args}

  defp format_result({_, 0}, _task), do: :ok

  defp format_result({%FwupStream{output: o}, _}, "upgrade") do
    if o =~ ~r/fwup: Expecting platform=#{mix_target()} and/ do
      :failed_not_upgradable
    else
      :failed
    end
  end

  defp format_result(_result, _task), do: :failed
end
