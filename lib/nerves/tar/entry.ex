# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Tar.Entry do
  @moduledoc """
  Represents a single entry in a tar archive

  The representation is lightweight in that file `contents` are
  stored elsewhere.
  """

  defstruct path: "",
            contents: nil,
            type: :regular,
            mode: 0,
            uid: 0,
            gid: 0,
            size: 0,
            mtime: 0,
            link: "",
            major_device: 0,
            minor_device: 0

  @type entry_type ::
          :regular
          | :hard_link
          | :symlink
          | :character_device
          | :block_device
          | :directory
          | :pax_header
          | :long_link
          | :long_name

  @type t() :: %__MODULE__{
          path: String.t(),
          contents: nil | {Path.t(), non_neg_integer()} | {File.io_device(), non_neg_integer()},
          type: entry_type(),
          mode: non_neg_integer(),
          uid: non_neg_integer(),
          gid: non_neg_integer(),
          link: String.t(),
          size: non_neg_integer(),
          mtime: non_neg_integer(),
          major_device: non_neg_integer(),
          minor_device: non_neg_integer()
        }

  @doc "Create a regular file"
  @spec regular(String.t(), keyword()) :: t()
  def regular(path, info) do
    %__MODULE__{
      path: normalize_path(path),
      type: :regular,
      contents: Keyword.fetch!(info, :contents),
      mode: Keyword.fetch!(info, :mode) |> normalize_mode(),
      size: Keyword.fetch!(info, :size)
    }
  end

  @doc "Create a directory"
  @spec directory(String.t(), keyword()) :: t()
  def directory(path, info) do
    %__MODULE__{
      path: path |> normalize_path() |> normalize_dir(),
      type: :directory,
      mode: Keyword.fetch!(info, :mode) |> normalize_mode()
    }
  end

  @doc "Create a symlink"
  @spec symlink(String.t(), keyword()) :: t()
  def symlink(path, info) do
    %__MODULE__{
      path: normalize_path(path),
      type: :symlink,
      mode: Keyword.fetch!(info, :mode) |> normalize_mode(),
      link: Keyword.fetch!(info, :link),
      size: 0
    }
  end

  @doc "Create a block device"
  @spec block_device(String.t(), keyword()) :: t()
  def block_device(path, info) do
    %__MODULE__{
      path: normalize_path(path),
      type: :block_device,
      mode: Keyword.fetch!(info, :mode) |> normalize_mode(),
      size: 0,
      major_device: Keyword.fetch!(info, :major_device),
      minor_device: Keyword.fetch!(info, :minor_device)
    }
  end

  @doc "Create a character device"
  @spec character_device(String.t(), keyword()) :: t()
  def character_device(path, info) do
    %__MODULE__{
      path: normalize_path(path),
      type: :character_device,
      mode: Keyword.fetch!(info, :mode) |> normalize_mode(),
      size: 0,
      major_device: Keyword.fetch!(info, :major_device),
      minor_device: Keyword.fetch!(info, :minor_device)
    }
  end

  @doc "Update the path"
  @spec put_path(t(), String.t()) :: t()
  def put_path(entry, path) do
    %{entry | path: normalize_path(path)}
  end

  @doc "Read the file contents referenced by this entry"
  @spec read_contents(t()) :: {:ok, binary()} | {:error, :file.posix() | :eof}
  def read_contents(%__MODULE__{contents: nil}), do: {:ok, <<>>}

  def read_contents(%__MODULE__{contents: {io_device, offset}} = entry) when is_pid(io_device) do
    case :file.pread(io_device, offset, entry.size) do
      {:ok, data} -> {:ok, data}
      :eof -> {:error, :eof}
      err -> {:error, err}
    end
  end

  def read_contents(%__MODULE__{contents: {path, offset}} = entry) when is_binary(path) do
    with {:ok, file} <- File.open(path, [:read]),
         {:ok, data} <- :file.pread(file, offset, entry.size) do
      _ = :file.close(file)
      {:ok, data}
    else
      :eof -> {:error, :eof}
      err -> err
    end
  end

  defp normalize_mode(mode) do
    Bitwise.band(mode, 0o7777)
  end

  defp normalize_path("../" <> path),
    do: raise(RuntimeError, "Previous directory not supported in path: ../#{path}")

  defp normalize_path("./" <> path), do: "./" <> path
  defp normalize_path("/" <> path), do: "./" <> path
  defp normalize_path(path), do: "./" <> path

  defp normalize_dir(path) do
    # Tarball directories always end with /'s
    if String.ends_with?(path, "/") do
      path
    else
      path <> "/"
    end
  end
end
