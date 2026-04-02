# SPDX-FileCopyrightText: 2018 Justin Schneck
# SPDX-FileCopyrightText: 2020 Frank Hunleth
# SPDX-FileCopyrightText: 2022 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.Downloader do
  @moduledoc false

  alias Nerves.Artifact.Archive

  @downloaders [
    Nerves.Artifact.Downloaders.GithubAPI,
    Nerves.Artifact.Downloaders.GiteaAPI,
    Nerves.Artifact.Downloaders.URI
  ]

  @callback expand_site(site_config :: tuple(), info :: keyword()) ::
              {:ok, {source :: term(), opts :: keyword()}} | :skip

  @callback download(source :: term(), opts :: keyword()) ::
              {:ok, Path.t()} | {:error, term()}

  @callback site_help() :: [String.t()]

  @doc """
  Expands artifact site configurations into a list of downloader tuples.
  """
  @spec expand_sites(Nerves.Package.t()) :: [{module(), {term(), keyword()}}]
  def expand_sites(pkg) do
    info = [
      download_names: Nerves.Artifact.download_names(pkg),
      version: pkg.version
    ]

    Keyword.get(pkg.config, :artifact_sites, [])
    |> Enum.map(&expand_one_site(&1, info))
  end

  @doc """
  Finds an existing downloaded archive for the given package

  Returns the path to the first existing file or `nil` if no archive is found.
  """
  @spec find_archive(Nerves.Package.t()) :: Path.t() | nil
  def find_archive(pkg) do
    dir = Nerves.Env.download_dir()

    Enum.find_value(Nerves.Artifact.download_names(pkg), fn name ->
      path = Path.join(dir, name) |> Path.expand()
      if File.exists?(path), do: path
    end)
  end

  @doc """
  Downloads an artifact by trying each downloader in the list.
  """
  @spec download([{module(), {term(), keyword()}}], Nerves.Package.t()) ::
          {:ok, Path.t()} | {:error, term()}
  def download([], _pkg), do: {:error, :no_result}

  def download(downloaders, pkg) do
    do_download(downloaders, pkg, nil)
  end

  # Private

  defp expand_one_site(site_config, info) do
    Enum.find_value(@downloaders, fn downloader ->
      case downloader.expand_site(site_config, info) do
        {:ok, result} -> {downloader, result}
        :skip -> nil
      end
    end) || raise_unsupported_site(site_config)
  end

  @spec raise_unsupported_site(term()) :: no_return()
  defp raise_unsupported_site(site_config) do
    help = Enum.flat_map(@downloaders, & &1.site_help())
    help_text = Enum.map_join(help, "\n", &"  #{&1}")

    Mix.raise("""
    Unsupported artifact site
    #{inspect(site_config)}

    Supported artifact sites:
    #{help_text}
    """)
  end

  defp do_download([], _pkg, nil), do: {:error, :no_result}
  defp do_download([], _pkg, reason), do: Mix.raise(reason)

  defp do_download([{downloader, {source, opts}} | rest], pkg, raise_reason) do
    download_names = Nerves.Artifact.download_names(pkg)
    dir = Nerves.Env.download_dir()
    File.mkdir_p!(dir)

    dest_dir = Path.expand(dir)

    opts =
      opts
      |> Keyword.put(:dest_dir, dest_dir)
      |> Keyword.put(:download_names, download_names)

    case downloader.download(source, opts) do
      {:ok, path} ->
        validate_and_continue(path, rest, pkg)

      {:error, reason} ->
        handle_error(reason, rest, pkg, raise_reason)
    end
  end

  defp validate_and_continue(file, rest, pkg) do
    case Archive.validate(file) do
      :ok ->
        {:ok, file}

      {:error, reason} ->
        Nerves.Utils.Shell.warn("     Invalid or corrupt file")

        _ = File.rm(file)

        raise_reason = """
        Nerves encountered errors while validating artifact download.
        #{format_raise_reason(reason)}
        """

        do_download(rest, pkg, raise_reason)
    end
  end

  defp handle_error(reason, rest, pkg, raise_reason) do
    Nerves.Utils.Shell.warn("     #{reason}")
    do_download(rest, pkg, raise_reason)
  end

  defp format_raise_reason(reason) do
    if is_binary(reason), do: reason, else: inspect(reason)
  end
end
