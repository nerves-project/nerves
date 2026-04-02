# SPDX-FileCopyrightText: 2018 Justin Schneck
# SPDX-FileCopyrightText: 2020 Frank Hunleth
# SPDX-FileCopyrightText: 2022 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.Downloader do
  @moduledoc false

  @callback download(tuple(), Path.t()) :: :ok | {:error, term}

  @spec download(list(), pkg :: Nerves.Package.t()) :: {:ok, path :: Path.t()} | {:error, term}
  def download([], _pkg) do
    {:error, :no_result}
  end

  def download(downloaders, pkg) do
    do_download(downloaders, pkg)
  end

  defp do_download(_, _, _raise \\ nil)
  defp do_download([], _pkg, nil), do: {:error, :no_result}
  defp do_download([], _pkg, reason), do: Mix.raise(reason)

  defp do_download([{downloader, {id, downloader_opts}} | downloaders], pkg, raise_reason) do
    file = Nerves.Artifact.download_path(pkg)
    File.mkdir_p!(Nerves.Env.download_dir())

    case downloader.download({id, downloader_opts}, file) do
      :ok ->
        validate_and_continue(file, downloaders, pkg)

      {:error, reason} ->
        handle_error(reason, downloaders, pkg, raise_reason)
    end
  end

  defp validate_and_continue(file, downloaders, pkg) do
    case Nerves.Utils.File.validate(file) do
      :ok ->
        {:ok, file}

      {:error, reason} ->
        Nerves.Utils.Shell.warn("     Invalid or corrupt file")

        _ = File.rm(file)

        raise_reason = """
        Nerves encountered errors while validating artifact download.
        #{format_raise_reason(reason)}
        """

        do_download(downloaders, pkg, raise_reason)
    end
  end

  defp handle_error(reason, downloaders, pkg, raise_reason) do
    Nerves.Utils.Shell.warn("     #{reason}")
    do_download(downloaders, pkg, raise_reason)
  end

  defp format_raise_reason(reason) do
    if is_binary(reason), do: reason, else: inspect(reason)
  end
end
