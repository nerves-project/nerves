# SPDX-FileCopyrightText: 2018 Joel Byler
# SPDX-FileCopyrightText: 2019 Greg Mefford
# SPDX-FileCopyrightText: 2019 Justin Schneck
# SPDX-FileCopyrightText: 2019 Matt Willy
# SPDX-FileCopyrightText: 2020 Frank Hunleth
# SPDX-FileCopyrightText: 2022 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Burn do
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
      bootloader and application data partitions. The `upgrade` task only
      modifies the parts of the SDCard required to run the new software.

    * `--firmware <name>` - (Optional) The path to the fw file to use.
      Defaults to `<image_path>/<otp_app>.fw`

  ## Examples

  ```
  # Upgrade the contents of the SDCard located at /dev/mmcblk0
  mix burn --device /dev/mmcblk0 --task upgrade
  ```
  """
  use Mix.Task
  import Mix.Nerves.Utils
  alias Mix.Nerves.Preflight
  alias Nerves.Utils.WSL

  @switches [device: :string, task: :string, firmware: :string]
  @aliases [d: :device, t: :task, i: :firmware]

  @impl Mix.Task
  def run(argv) do
    Preflight.check!()
    debug_info("Nerves Burn")

    {opts, argv, _} = OptionParser.parse(argv, switches: @switches, aliases: @aliases)

    firmware_config = Application.get_env(:nerves, :firmware)

    target = Mix.target()

    _ = check_nerves_system_is_set!()

    _ = check_nerves_toolchain_is_set!()

    fw = firmware_file(opts)

    if !File.exists?(fw) do
      Mix.raise("Firmware for target #{target} not found at #{fw} run `mix firmware` to build")
    end

    {fw, firmware_location} =
      WSL.make_file_accessible(fw, WSL.running_on_wsl?(), WSL.has_wslpath?())

    dev =
      case opts[:device] do
        nil -> prompt_dev()
        dev -> dev
      end

    set_provisioning(firmware_config[:provisioning])
    _ = burn(fw, dev, opts, argv)

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
            maybe_elevated_user_fwup(dev, args)
          end

        {_, :nt} ->
          {"fwup", args}

        {_, type} ->
          raise "Unable to burn firmware on your host #{inspect(type)}"
      end

    interactive_shell(cmd, args)
  end

  defp maybe_elevated_user_fwup(dev, args) do
    fwup = System.find_executable("fwup")

    case File.stat(dev) do
      {:ok, %File.Stat{access: :read_write}} ->
        {"fwup", args}

      {:error, :enoent} ->
        case File.touch(dev, System.os_time(:second)) do
          :ok ->
            {"fwup", args}

          {:error, :eacces} ->
            {"sudo", asdf_aware_env(fwup) ++ [fwup] ++ args}
        end

      _ ->
        {"sudo", asdf_aware_env(fwup) ++ [fwup] ++ args}
    end
  end

  # Check if fwup is managed by asdf and return appropriate environment variables
  defp asdf_aware_env(fwup) do
    if fwup_managed_by_asdf?(fwup) do
      provision_env() ++ asdf_env_vars()
    else
      provision_env()
    end
  end

  # Detect if fwup is managed by asdf by checking if it's in the asdf shims directory
  defp fwup_managed_by_asdf?(fwup) do
    String.contains?(fwup, ".asdf/shims")
  end

  # Get the appropriate asdf environment variables
  defp asdf_env_vars() do
    # Check for ASDF_DATA_DIR first (0.16+), then ASDF_DIR (0.15 and earlier)
    cond do
      data_dir = System.get_env("ASDF_DATA_DIR") ->
        ["ASDF_DATA_DIR=#{data_dir}"]

      dir = System.get_env("ASDF_DIR") ->
        ["ASDF_DIR=#{dir}"]

      true ->
        Mix.raise("""
        fwup is installed via asdf, but the required environment variable is not set.

        For asdf 0.16 and later, you need to set ASDF_DATA_DIR in your shell configuration.
        For asdf 0.15 and earlier, you need to set ASDF_DIR in your shell configuration.

        Please add one of the following to your shell configuration file (~/.bashrc, ~/.zshrc, etc.):

          export ASDF_DATA_DIR="$HOME/.asdf"  # for asdf 0.16+

        or

          export ASDF_DIR="$HOME/.asdf"  # for asdf 0.15 and earlier

        After updating your shell configuration, restart your terminal or run `source ~/.bashrc` (or equivalent).
        """)
    end
  end

  # This is a fix for linux when running through sudo.
  # Sudo will strip the environment and therefore any variables
  # that are set during device provisioning.
  defp provision_env() do
    System.get_env()
    |> Enum.filter(fn {k, _} ->
      String.starts_with?(k, "NERVES_") or String.equivalent?(k, "SERIAL_NUMBER")
    end)
    |> Enum.map(fn {k, v} -> k <> "=" <> v end)
  end

  @spec firmware_file(keyword()) :: String.t()
  def firmware_file(opts) do
    fw =
      (opts[:firmware] || Nerves.Env.firmware_path())
      |> Path.expand()

    if File.exists?(fw) do
      fw
    else
      Mix.raise("The firmware file #{fw} does not exist")
    end
  end
end
