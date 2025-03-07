defmodule Nerves.Paths do
  @moduledoc """
  Functions for determining paths used by Nerves

  """

  @doc """
  The download location for artifact downloads.

  Placing an artifact tar in this location will bypass the need for it to
  be downloaded.
  """
  @spec download_dir() :: String.t()
  def download_dir() do
    (System.get_env("NERVES_DL_DIR") || Path.join(data_dir(), "dl"))
    |> Path.expand()
  end

  @doc """
  Get the base dir for where an artifact for a package should be stored.

  Normally this returns the `artifacts` directory under `Nerves.Paths.data_dir/0`,
  but it can be overridden by the environment variable `NERVES_ARTIFACTS_DIR`.
  """
  @spec artifacts_dir() :: String.t()
  def artifacts_dir() do
    (System.get_env("NERVES_ARTIFACTS_DIR") || Path.join(data_dir(), "artifacts"))
    |> Path.expand()
  end

  @doc """
  The location for storing global nerves data.

  The base directory is normally set by the `XDG_DATA_HOME`
  environment variable (i.e. `$XDG_DATA_HOME/nerves/`).
  If `XDG_DATA_HOME` is unset, the user's home directory
  is used (i.e. `$HOME/.nerves`).
  """
  @spec data_dir() :: String.t()
  def data_dir() do
    case System.get_env("XDG_DATA_HOME") do
      directory when is_binary(directory) -> Path.join(directory, "nerves")
      nil -> Path.expand("~/.nerves")
    end
  end
end
