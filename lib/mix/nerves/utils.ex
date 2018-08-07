defmodule Mix.Nerves.Utils do
  @fwup_semver "~> 0.15 or ~> 1.0.0-dev or ~> 1.0"

  def shell(cmd, args, opts \\ []) do
    stream = opts[:stream] || IO.binstream(:standard_io, :line)
    std_err = opts[:stderr_to_stdout] || true
    opts = Keyword.drop(opts, [:into, :stderr_to_stdout, :stream])
    System.cmd(cmd, args, [into: stream, stderr_to_stdout: std_err] ++ opts)
  end

  def preflight do
    {_, type} = :os.type()
    check_requirements("fwup")
    check_requirements("mksquashfs")
    check_host_requirements(type)
    Mix.Task.run("nerves.loadpaths")
  end

  def check_requirements("mksquashfs") do
    case System.find_executable("mksquashfs") do
      nil ->
        Mix.raise("""
        Squash FS Tools are required to be installed on your system.
        Please see https://hexdocs.pm/nerves/installation.html#host-specific-tools
        for installation instructions
        """)

      _ ->
        :ok
    end
  end

  def check_requirements("fwup") do
    case System.find_executable("fwup") do
      nil ->
        Mix.raise("""
        fwup is required to create and burn firmware.
        Please see https://hexdocs.pm/nerves/installation.html#fwup
        for installation instructions
        """)

      _ ->
        with {vsn, 0} <- System.cmd("fwup", ["--version"]),
             vsn = String.trim(vsn),
             {:ok, req} = Version.parse_requirement(@fwup_semver),
             true <- Version.match?(vsn, req) do
          :ok
        else
          false ->
            {vsn, 0} = System.cmd("fwup", ["--version"])

            Mix.raise("""
            fwup #{@fwup_semver} is required for Nerves.
            You are running #{vsn}.
            Please see https://hexdocs.pm/nerves/installation.html#fwup
            for installation instructions
            """)

          error ->
            Mix.raise("""
            Nerves encountered an error while checking host requirements for fwup
            #{inspect(error)}
            Please open a bug report for this issue on github.com/nerves-project/nerves
            """)
        end
    end
  end

  def check_host_requirements(:darwin) do
    case System.find_executable("gstat") do
      nil ->
        Mix.raise("""
        gstat is required to create and burn firmware.
        Please see https://hexdocs.pm/nerves/installation.html#host-specific-tools
        for installation instructions
        """)

      _ ->
        :ok
    end
  end

  def check_host_requirements(_), do: nil

  def debug_info(msg) do
    if System.get_env("NERVES_DEBUG") == "1" do
      Mix.shell().info(msg)
    end
  end

  def check_nerves_system_is_set! do
    var_name = "NERVES_SYSTEM"
    System.get_env(var_name) || raise_env_var_missing(var_name)
  end

  def check_nerves_toolchain_is_set! do
    var_name = "NERVES_TOOLCHAIN"
    System.get_env(var_name) || raise_env_var_missing(var_name)
  end

  def get_devs do
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

  def prompt_dev() do
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

  def bytes_to_gigabytes(bytes) when is_binary(bytes) do
    {bytes, _} = Integer.parse(bytes)
    bytes_to_gigabytes(bytes)
  end

  def bytes_to_gigabytes(bytes) do
    gb = bytes / 1024 / 1024 / 1024
    Float.round(gb, 2)
  end

  def is_wsl? do
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

  def get_wsl_paths(file) do
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

  defp raise_env_var_missing(name) do
    Mix.raise("""
    Environment variable $#{name} is not set.

    This variable is usually set for you by Nerves when you specify the
    $MIX_TARGET. For examples please see
    https://hexdocs.pm/nerves/getting-started.html#create-the-firmware-bundle
    """)
  end
end
