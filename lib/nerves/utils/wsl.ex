defmodule Nerves.Utils.WSL do
  @moduledoc """
  This module contains utility functions to assist in detecting a Windows
  Subsystem for Linux environment as well as functions to convert paths between
  the Windows host and Linux.
  """

  @doc """
  Returns a two item tuple where the first item is a command and the second is
  the argument list to run a powershell command as administrator in Windows
  """
  @spec admin_powershell_command(String.t(), String.t()) :: {String.t(), [String.t()]}
  def admin_powershell_command(command, args) do
    {
      "powershell.exe",
      [
        "-Command",
        "Start-Process #{command} -Verb runAs -Wait -ArgumentList \"#{args}\""
      ]
    }
  end

  @doc """
  Returns true if inside a WSL shell environment
  """
  @spec running_on_wsl?() :: boolean
  def running_on_wsl?() do
    # Docker Desktop for Windows uses WSL 2 kernel as the back-end
    # so also check whether the env is Docker
    Regex.match?(~r/[Mm]icrosoft/, osrelease()) and not File.exists?("/.dockerenv")
  end

  defp osrelease() do
    case File.read("/proc/sys/kernel/osrelease") do
      {:ok, text} -> text
      _ -> "unknown"
    end
  end

  @doc """
  Gets a list of fwup devices on a Windows host. This function can be run from
  within WSL, as it runs a powershell command to get the list and writes it to a
  temporary file that WSL can access.
  """
  @spec get_fwup_devices() :: {Collectable.t(), exit_status :: non_neg_integer()}
  def get_fwup_devices() do
    {win_path, _} = make_file_accessible("fwup_devs.txt", running_on_wsl?(), has_wslpath?())

    {_, wsl_path} = get_wsl_paths(win_path, has_wslpath?())

    powershell_args = "fwup.exe -D | set-content -encoding UTF8 #{win_path}"

    with {command, args} <- admin_powershell_command("powershell.exe", powershell_args),
         {"", 0} <- Nerves.Port.cmd(command, args),
         {:ok, devs} <- File.read(wsl_path) do
      devs =
        Regex.replace(~r/[\x{200B}\x{200C}\x{200D}\x{FEFF}]/u, devs, "")
        |> String.replace("\r", "")

      _ = File.rm(wsl_path)
      {devs, 0}
    else
      {:error, :enoent} ->
        # fwup didn't find any devices and no tmp file was generated
        # behave as fwup does normally and return an empty string result
        {"", 0}

      error ->
        error
    end
  end

  @doc """
  Returns true if the WSL utility `wslpath` is available
  """
  @spec has_wslpath?() :: boolean
  def has_wslpath?() do
    System.find_executable("wslpath") != nil
  end

  @doc """
  Returns true if the path is accessible in Windows
  """
  @spec path_accessible_in_windows?(String.t(), boolean()) :: boolean()
  def path_accessible_in_windows?(file, true = _use_wslpath) do
    {_path, exitcode} = Nerves.Port.cmd("wslpath", ["-w", "-a", file], stderr_to_stdout: true)
    exitcode == 0
  end

  def path_accessible_in_windows?(file, _use_wslpath) do
    Regex.match?(~r/(\/mnt\/\w{1})\//, file)
  end

  @doc """
  Returns a path to the base file name a temporary location in Windows
  """
  @spec get_temp_file_location(String.t()) :: String.t()
  def get_temp_file_location(file) do
    {win_path, 0} = Nerves.Port.cmd("cmd.exe", ["/c", "echo %TEMP%"])
    "#{String.trim(win_path)}\\#{Path.basename(file)}"
  end

  @doc """
  Returns true when the path matches various kinds of Windows-specific paths, like:

  ```
  C:\\
  C:\\projects
  \\\\myserver\\sharename\\
  \\\\wsl$\\Ubuntu-18.04\\home\\username\\my_project\\
  ```
  """
  @spec valid_windows_path?(String.t()) :: boolean
  def valid_windows_path?(path) do
    Regex.match?(~r/^(\w:|\\\\[\w.$-]+)\\/, path)
  end

  @doc """
  Returns true if the path is not a Windows path
  """
  @spec valid_wsl_path?(String.t()) :: boolean
  def valid_wsl_path?(path) do
    valid_windows_path?(path) === false
  end

  @doc """
  Returns a two item tuple containing the Windows host path for a file and its WSL counterpart.

  If the path is not available in either Windows or WSL, nil will replace the item

  ## Examples

      iex> Nerves.Utils.WSL.get_wsl_paths("mix.exs", Nerves.Utils.WSL.has_wslpath?())
      {"C:\\Users\\username\\src\\nerves\\mix.exs",
      "/mnt/c/Users/username/src/nerves/mix.exs"}

  """
  @spec get_wsl_paths(String.t(), boolean()) :: {String.t() | nil, String.t() | nil}
  def get_wsl_paths(file, true = _use_wslpath) do
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

    # Check if the full path is accessible form Windows
    win_path =
      if Regex.match?(~r/(\/mnt\/\w{1})\//, fullpath) do
        # extract drive letter from path
        %{"drive" => drive_letter} = Regex.named_captures(~r/\/mnt\/(?<drive>\w{1})\//, fullpath)
        # replace /mnt/<drive_letter>/ with windows version C:/
        win_path =
          Regex.replace(~r/(\/mnt\/\w{1})\//, fullpath, "#{String.upcase(drive_letter)}:/")

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

    # Check if full path is a windows path
    wsl_path =
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

  @doc """
  Executes wslpath with the file and arguments.

  When a valid WSL path is passed through to `wslpath` asking for a
  valid path an "Invalid argument" error is returned. This function
  catches this error and returns the valid path.
  """
  @spec execute_wslpath(String.t(), [String.t()]) :: String.t() | nil
  def execute_wslpath(file, arguments) do
    case Nerves.Port.cmd("wslpath", arguments ++ [file], stderr_to_stdout: true) do
      {path, 0} ->
        String.trim(path)

      {error, _} ->
        if String.contains?(error, "Invalid argument"), do: Path.expand(file)
    end
  end

  @doc """
  Returns an item tuple with the Windows accessible path and whether the path is a temporary location or original location
  """
  @spec make_file_accessible(String.t(), boolean(), boolean()) ::
          {String.t(), :original_location} | {String.t(), :temporary_location}
  def make_file_accessible(file, true = _is_wsl, has_wslpath) do
    if path_accessible_in_windows?(file, has_wslpath) do
      {win_path, _wsl_path} = get_wsl_paths(file, has_wslpath)
      {win_path, :original_location}
    else
      # Create a temporary .fw file that fwup.exe is able to access
      temp_file_location = get_temp_file_location(file)
      {win_path, wsl_path} = get_wsl_paths(temp_file_location, has_wslpath)
      _ = File.copy(file, wsl_path)
      {win_path, :temporary_location}
    end
  end

  def make_file_accessible(file, _is_wsl, _has_wslpath) do
    {file, :original_location}
  end

  @doc """
  If the file was created in a temporary location, get the WSL path and delete it. Otherwise return `:ok`
  """
  @spec cleanup_file(String.t(), :temporary_location | :original_location) :: :ok | {:error, atom}
  def cleanup_file(file, :temporary_location) do
    {_win_path, wsl_path} = get_wsl_paths(file, has_wslpath?())
    File.rm(wsl_path)
  end

  def cleanup_file(_, _), do: :ok
end
