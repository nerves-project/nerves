# SPDX-FileCopyrightText: 2018 Justin Schneck
# SPDX-FileCopyrightText: 2018 Michael Schmidt
# SPDX-FileCopyrightText: 2022 Frank Hunleth
# SPDX-FileCopyrightText: 2022 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Utils.File do
  @moduledoc false

  @doc """
  Create a tar of the contents of the path and specified output file

  This hardcodes the tar file type to gzip and was advertised
  as public API in the docs even though this module is `@moduledoc false`.
  """
  @spec tar(String.t(), String.t()) :: :ok | {:error, any}
  def tar(path, file) do
    working_dir = Path.dirname(path)
    path = Path.basename(path)

    cmd("tar", ["-czf", file, "-C", working_dir, path])
    |> result()
  end

  defp result({"", 0}), do: :ok
  defp result({reason, _}), do: {:error, reason}

  defp cmd(cmd, args) do
    if System.find_executable(cmd) do
      Nerves.Port.cmd(cmd, args, stderr_to_stdout: true)
    else
      raise "Could not find '#{cmd}'. See https://nerves.hexdocs.pm/installation.html for required packages."
    end
  end
end
