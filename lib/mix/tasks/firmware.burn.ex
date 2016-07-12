defmodule Mix.Tasks.Firmware.Burn do
  use Mix.Task
  import Mix.Nerves.Utils

  @switches [device: :string, task: :string]
  @aliases [d: :device, t: :task]

  def run(argv) do
    preflight

    {opts, argv, _} = OptionParser.parse(argv, switches: @switches, aliases: @aliases)

    Mix.shell.info "Nerves Firmware Burn"
    config = Mix.Project.config
    otp_app = config[:app]
    target = config[:target]

    System.get_env("NERVES_SYSTEM") || raise """
      Environment variable $NERVES_SYSTEM is not set
    """

    System.get_env("NERVES_TOOLCHAIN") || raise """
      Environment variable $NERVES_TOOLCHAIN is not set
    """

    fw = Path.join(File.cwd!, "_images/#{target}/#{otp_app}.fw")
    unless File.exists?(fw) do
      Mix.raise "Firmware for target #{target} not found at #{fw} run `mix firmware` to build"
    end

    dev =
      case opts[:device] do
        nil -> prompt_dev()
        dev -> dev
      end
    burn(fw, dev, opts, argv)
  end

  defp burn(fw, dev, opts, argv) do
    task = opts[:task] || "complete"
    args = ["-a", "-i", fw, "-t", task, "-d", dev] ++ argv
    {cmd, args} =
      case :os.type do
        {_, :darwin} ->
          {"fwup", args}
        {_, :linux} ->
           ask_pass = System.get_env("SUDO_ASKPASS") || "/usr/bin/ssh-askpass"
           System.put_env("SUDO_ASKPASS", ask_pass)
           {"sudo", ["fwup"] ++ args}
        {_, type} ->
          raise "Unable to burn firmware on your host #{inspect type}"
      end
    shell(cmd, args)
  end

  defp get_devs do
    {result, 0} = System.cmd("fwup", ["--detect"])
    if result == "" do
      Mix.raise "Could not auto detect your SD card"
    end
    result
    |> String.strip
    |> String.split("\n")
    |> Enum.map(&String.split(&1, ","))
  end

  defp prompt_dev() do
    case get_devs() do
      [[dev, bytes]] ->
        choice =
          Mix.shell.yes?("Use #{bytes_to_gigabytes(bytes)} GiB memory card found at #{dev}?")
        if choice do
          dev
        else
          Mix.raise "Aborted"
        end
      devs ->
        choices =
          devs
          |> Enum.zip(0..length(devs))
          |> Enum.reduce([], fn({[dev, bytes], idx}, acc) ->
            ["#{idx}) #{bytes_to_gigabytes(bytes)} GiB found at #{dev}" | acc]
          end)
          |> Enum.reverse
        choice = Mix.shell.prompt("Discovered devices:\n#{Enum.join(choices, "\n")}\nWhich device do you want to burn to?")
        |> String.strip
        idx =
          case Integer.parse(choice) do
            {idx, _} -> idx
            _ -> Mix.raise "Invalid selection #{choice}"
          end
        case Enum.fetch(devs, idx) do
          {:ok, [dev, _]} -> dev
          _ -> Mix.raise "Invalid selection #{choice}"
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
end
