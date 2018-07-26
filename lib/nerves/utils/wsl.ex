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
  def is_wsl?(osrelease_path \\ "/proc/sys/kernel/osrelease") do
    with true <- File.exists?(osrelease_path),
         {content, _} <- System.cmd("cat", [osrelease_path]) do
      Regex.match?(~r/Microsoft/, content)
    else
      _ ->
        false
    end
  end

  @doc """
  Gets a list of fwup devices on a Windows host. This function can be run from
  within WSL, as it runs a powershell command to get the list and writes it to a
  temporary file that WSL can access.
  """
  def get_fwup_devices do
    {win_path, wsl_path} = get_wsl_paths("fwup_devs.txt")
    powershell_args = "fwup.exe -D | set-content -encoding UTF8 #{win_path}"

    with {command, args} <- admin_powershell_command("powershell.exe", powershell_args),
         {"", 0} <- System.cmd(command, args),
         {:ok, devs} <- File.read(wsl_path) do
      devs =
        Regex.replace(~r/[\x{200B}\x{200C}\x{200D}\x{FEFF}]/u, devs, "")
        |> String.replace("\r", "")

      File.rm(wsl_path)
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
  Returns a two item tuple containing the Windows host path for a file in the
  current working directory and its WSL counterpart

  ## Examples

      iex> Nerves.Utils.WSL.get_wsl_paths("mix.exs")
      {"C:\\Users\\username\\src\\nerves\\mix.exs",
      "/mnt/c/Users/username/src/nerves/mix.exs"}
  """
  def get_wsl_paths(file) do
    {win_path, 0} = System.cmd("cmd.exe", ["/c", "cd"])
    win_path = String.trim(win_path) <> "\\#{file}"

    drive_letter = extract_drive_letter(win_path)
    wsl_path = "/mnt/" <> drive_letter <> "/" <> Regex.replace(~r/(.*?):\\/, win_path, "")
    wsl_path = Regex.replace(~r/\\/, wsl_path, "/")
    {win_path, wsl_path}
  end

  @doc """
  Takes a windows path (eg C:\\User\\...) and converts it to WSL path format (eg
  /mnt/c/User/...)
  """
  def convert_path_from_windows_to_wsl(windows_path) do
    drive_letter = extract_drive_letter(windows_path)
    Regex.replace(~r/(.*?):/, windows_path, "/mnt/" <> drive_letter)
  end

  defp extract_drive_letter(windows_path) do
    Regex.run(~r/(.*?):\\/, windows_path)
    |> Enum.at(1)
    |> String.downcase()
  end
end
