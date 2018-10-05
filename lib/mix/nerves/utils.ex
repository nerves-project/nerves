defmodule Mix.Nerves.Utils do
  @fwup_semver "~> 1.2.5 or ~> 1.3"

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
        {win_path, _} = make_file_accessible("fwup_devs.txt", is_wsl?(), has_wslpath?())

        {_, wsl_path} = get_wsl_paths(win_path, has_wslpath?())

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

  def has_wslpath?() do
    System.find_executable("wslpath") != nil
  end

  def wsl_path_accessible?(file, _use_wslpath = true) do
    {_path, exitcode} = System.cmd("wslpath", ["-w", "-a", file], stderr_to_stdout: true)
    exitcode == 0
  end

  def wsl_path_accessible?(file, _use_wslpath) do
    Regex.match?(~r/(\/mnt\/\w{1})\//, file)
  end

  def get_temp_firmware_location(file) do
    {win_path, 0} = System.cmd("cmd.exe", ["/c", "echo %TEMP%"])
    "#{String.trim(win_path)}\\#{Path.basename(file)}"
  end

  def valid_windows_path?(path) do
    # Match <drive_letter>: then \ or \\ and then one or more characters except line breaks
    Regex.match?(~r/(^\w{1}:)(\\\\|\\)(.+)/, path)
  end

  def valid_wsl_path?(path) do
    valid_windows_path?(path) === false
  end

  def get_wsl_paths(file, _use_wslpath = true) do
    # Use wslpath, available from Windows 10 1803
    # https://superuser.com/questions/1113385/convert-windows-path-for-windows-ubuntu-bash
    # -a    force result to absolute path format
    # -u    translate from a Windows path to a WSL path (default)
    # -w    translate from a WSL path to a Windows path
    # -m    translate from a WSL path to a Windows path, with ‘/’ instead of ‘\\’

    win_path =
      if valid_windows_path?(file) do
        file
      else
        execute_wslpath(file, ["-w", "-a"])
      end

    wsl_path =
      if valid_wsl_path?(file) do
        Path.expand(file)
      else
        execute_wslpath(file, ["-u", "-a"])
      end

    {win_path, wsl_path}
  end

  def get_wsl_paths(file, _use_wslpath) do
    # Maintain support for Windows builds before 1803
    fullpath =
      if valid_wsl_path?(file) do
        Path.expand(file)
      else
        file
      end

    win_path =
      # Check if the full path is accessible form Windows
      if Regex.match?(~r/(\/mnt\/\w{1})\//, fullpath) do
        # extract drive letter from path
        %{"drive" => drive_letter} = Regex.named_captures(~r/\/mnt\/(?<drive>\w{1})\//, fullpath)
        # replace /mnt/<drive_letter>/ with windows version C:/
        win_path = Regex.replace(~r/(\/mnt\/\w{1})\//, fullpath, "#{String.upcase(drive_letter)}:/")
        # replace forward slashes with backslashes
        Regex.replace(~r/\//, win_path, "\\\\")
      else
        # If path is already a windows path, return it
        if valid_windows_path?(fullpath) do
          fullpath
        else
          nil
        end
      end

    wsl_path =
      # Check if full path is a windows path
      if valid_windows_path?(fullpath) do
        # extract drive letter
        %{"drive" => drive_letter} = Regex.named_captures(~r/(?<drive>^.{1}):/, fullpath)
        # replace <drive_letter>: with /mnt/<drive_letter>
        wsl_path = Regex.replace(~r/^.{1}:/, fullpath, "/mnt/#{String.downcase(drive_letter)}")
        # replace \\ or \ with forward slashes
        Regex.replace(~r/\\\\|\\/, wsl_path, "/")
      else
        # if we are already a wsl path just return it
        fullpath
      end

    {win_path, wsl_path}
  end

  def execute_wslpath(file, arguments) do
    with {path, 0} <- System.cmd("wslpath", arguments ++ [file], stderr_to_stdout: true) do
      String.trim(path)
    else
      {error, _} ->
        if String.contains?(error, "Invalid argument") do
          Path.expand(file)
        else
          nil
        end
    end
  end

  def make_file_accessible(fw, _is_wsl = true, has_wslpath) do
    if wsl_path_accessible?(fw, has_wslpath) do
      {win_path, _wsl_path} = get_wsl_paths(fw,has_wslpath)
      {win_path, :original_location}
    else
      # Create a temporary .fw file that fwup.exe is able to access
      temp_firmware_location = get_temp_firmware_location(fw)
      {win_path, wsl_path} = get_wsl_paths(temp_firmware_location, has_wslpath)
      File.copy(fw, wsl_path)
      {win_path, :temporary_location}
    end
  end

  def make_file_accessible(fw, _is_wsl, _has_wslpath) do
    {fw, :original_location}
  end

  def cleanup_file(fw, :temporary_location) do
    {_win_path, wsl_path} = get_wsl_paths(fw, has_wslpath?())
    File.rm(wsl_path)
  end
  def cleanup_file(_, _), do: nil

  def set_provisioning(nil), do: :ok

  def set_provisioning(app) when is_atom(app) do
    Application.load(app)

    Application.get_env(app, :nerves_provisioning)
    |> set_provisioning()
  end

  def set_provisioning(provisioning) when is_binary(provisioning) do
    path = Path.expand(provisioning)
    System.put_env("NERVES_PROVISIONING", path)
  end

  def set_provisioning(_) do
    Mix.raise("""
      Unexpected Mix config for :nerves, :firmware, :provisioning.
      Provisioning should be a relative string path to a provisioning.conf
      based off the root of the project or an atom of an application that
      provides a provisioning.conf.

      For example:

        config :nerves, :firmware,
          provisioning: "config/provisioning.conf"

      or

        config :nerves, :firmware,
          provisioning: :nerves_hub

    """)
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
