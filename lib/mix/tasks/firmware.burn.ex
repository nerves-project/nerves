defmodule Mix.Tasks.Firmware.Burn do
  use Mix.Task
  import Mix.Nerves.Utils

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

    # Create a temporary .fw file that fwup.exe is able to access
    fw =
      if is_wsl?() do
        {win_path, wsl_path} = get_wsl_paths("#{otp_app}.fw")
        File.copy(fw, wsl_path)
        win_path
      else
        fw
      end

    dev =
      case opts[:device] do
        nil -> prompt_dev()
        dev -> dev
      end

    burn(fw, dev, opts, argv)

    # Remove the temporary .fw file
    if is_wsl?() do
      drive_letter =
        Regex.run(~r/(.*?):/, fw)
        |> Enum.at(1)
        |> String.downcase()

      fw = Regex.replace(~r/(.*?):/, fw, "/mnt/" <> drive_letter)
      File.rm(fw)
    end
  end

  defp burn(fw, dev, opts, argv) do
    task = opts[:task] || "complete"
    args = ["-a", "-i", fw, "-t", task, "-d", dev] ++ argv

    {cmd, args} =
      case :os.type() do
        {_, :darwin} ->
          {"fwup", args}

        {_, :linux} ->
          if is_wsl?() do
            ps_cmd =
              "Start-Process fwup -ArgumentList '#{Enum.join(args, " ")}' -Verb runAs -Wait"

            {"powershell.exe", ["-Command", ps_cmd]}
          else
            case File.stat(dev) do
              {:ok, %File.Stat{access: :read_write}} ->
                {"fwup", args}

              _ ->
                ask_pass = System.get_env("SUDO_ASKPASS") || "/usr/bin/ssh-askpass"
                System.put_env("SUDO_ASKPASS", ask_pass)
                {"sudo", ["fwup"] ++ args}
            end
          end

        {_, :nt} ->
          {"fwup", args}

        {_, type} ->
          raise "Unable to burn firmware on your host #{inspect(type)}"
      end

    shell(cmd, args)
  end

  defp get_devs do
    {result, 0} =
      if is_wsl?() do
        {win_path, wsl_path} = get_wsl_paths("fwup_devs.txt")

        System.cmd("powershell.exe", [
          "-Command",
          "Start-Process powershell.exe -Verb runAs -Wait -ArgumentList \"fwup.exe -D | set-content -encoding UTF8 #{
            win_path
          }\""
        ])

        {:ok, devs} = File.read(wsl_path)

        devs =
          Regex.replace(~r/[\x{200B}\x{200C}\x{200D}\x{FEFF}]/u, devs, "")
          |> String.replace("\r", "")

        File.rm(wsl_path)
        {devs, 0}
      else
        System.cmd("fwup", ["--detect"])
      end

    if result == "" do
      Mix.raise("Could not auto detect your SD card")
    end

    result
    |> String.trim()
    |> String.split("\n")
    |> Enum.map(&String.split(&1, ","))
  end

  defp prompt_dev() do
    case get_devs() do
      [[dev, bytes]] ->
        choice =
          Mix.shell().yes?("Use #{bytes_to_gigabytes(bytes)} GiB memory card found at #{dev}?")

        if choice do
          dev
        else
          Mix.raise("Aborted")
        end

      devs ->
        choices =
          devs
          |> Enum.zip(0..length(devs))
          |> Enum.reduce([], fn {[dev, bytes], idx}, acc ->
            ["#{idx}) #{bytes_to_gigabytes(bytes)} GiB found at #{dev}" | acc]
          end)
          |> Enum.reverse()

        choice =
          Mix.shell().prompt(
            "Discovered devices:\n#{Enum.join(choices, "\n")}\nWhich device do you want to burn to?"
          )
          |> String.trim()

        idx =
          case Integer.parse(choice) do
            {idx, _} -> idx
            _ -> Mix.raise("Invalid selection #{choice}")
          end

        case Enum.fetch(devs, idx) do
          {:ok, [dev, _]} -> dev
          _ -> Mix.raise("Invalid selection #{choice}")
        end
    end
  end

  defp bytes_to_gigabytes(bytes) when is_binary(bytes) do
    {bytes, _} = Integer.parse(bytes)
    bytes_to_gigabytes(bytes)
  end

  defp bytes_to_gigabytes(bytes) do
    gb = bytes / 1024 / 1024 / 1024
    Float.round(gb, 2)
  end

  defp is_wsl? do
    # using system.cmd("cat", ...) here is simpler
    # https://stackoverflow.com/questions/29874941/elixir-file-read-returns-empty-data-when-accessing-proc-cpuinfo/29875499
    if File.exists?("/proc/sys/kernel/osrelease") do
      System.cmd("cat", ["/proc/sys/kernel/osrelease"])
      |> elem(0)
      |> (&Regex.match?(~r/Microsoft/, &1)).()
    else
      false
    end
  end

  defp get_wsl_paths(file) do
    {win_path, 0} = System.cmd("cmd.exe", ["/c", "cd"])
    win_path = String.trim(win_path) <> "\\#{file}"

    drive_letter =
      Regex.run(~r/(.*?):\\/, win_path)
      |> Enum.at(1)
      |> String.downcase()

    wsl_path = "/mnt/" <> drive_letter <> "/" <> Regex.replace(~r/(.*?):\\/, win_path, "")
    wsl_path = Regex.replace(~r/\\/, wsl_path, "/")
    {win_path, wsl_path}
  end
end
