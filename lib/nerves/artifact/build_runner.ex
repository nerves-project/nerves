defmodule Nerves.Artifact.BuildRunner do
  @moduledoc """
  Defines the Nerves build runner behaviour

  A build runner is a module that can take package source and produce
  artifacts.
  """

  @type build_result :: {:ok, build_path :: String.t()} | {:error, reason :: term}
  @type archive_result :: {:ok, path :: String.t()} | {:error, reason :: term}
  @type clean_result :: :ok | {:error, reason :: term}

  @callback build(package :: Nerves.Package.t(), toolchain :: Nerves.Package.t(), opts :: term) ::
              build_result

  @callback archive(package :: Nerves.Package.t(), toolchain :: Nerves.Package.t(), opts :: term) ::
              archive_result

  @callback clean(package :: Nerves.Package.t()) :: clean_result
end
