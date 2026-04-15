# SPDX-FileCopyrightText: 2018 Justin Schneck
# SPDX-FileCopyrightText: 2020 Frank Hunleth
# SPDX-FileCopyrightText: 2022 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.Resolver do
  @moduledoc false

  @doc """
  Build a plan for downloading a package

  This function should not make any HTTP requests.

  Return `nil` if the implementing module can't handle the site spec.
  """
  @callback plan(tuple(), version :: String.t(), artifact_filename :: String.t()) ::
              {module(), map()} | nil

  @doc """
  Download the package based on a previously returned plan

  This function should download to the specified path.
  """
  @callback get(map(), Path.t()) :: :ok | {:error, term()}

  @spec get(list(), pkg :: Nerves.Package.t()) :: {:ok, path :: Path.t()} | {:error, term}
  def get([], _pkg) do
    {:error, :no_result}
  end

  def get(resolvers, pkg) do
    do_get(resolvers, pkg)
  end

  defp do_get(_, _, _raise \\ nil)
  defp do_get([], _pkg, nil), do: {:error, :no_result}
  defp do_get([], _pkg, reason), do: Mix.raise(reason)

  defp do_get([{resolver, resolver_opts} | resolvers], pkg, raise_reason) do
    file = Nerves.Artifact.download_path(pkg)
    File.mkdir_p!(Nerves.Env.download_dir())

    case resolver.get(resolver_opts, file) do
      :ok ->
        validate_and_continue(file, resolvers, pkg)

      {:error, reason} ->
        handle_error(reason, resolvers, pkg, raise_reason)
    end
  end

  defp validate_and_continue(file, resolvers, pkg) do
    case Nerves.Artifact.Archive.validate(file) do
      :ok ->
        {:ok, file}

      {:error, reason} ->
        Nerves.Utils.Shell.warn("     Invalid or corrupt file")

        _ = File.rm(file)

        raise_reason = """
        Nerves encountered errors while validating artifact download.
        #{format_raise_reason(reason)}
        """

        do_get(resolvers, pkg, raise_reason)
    end
  end

  defp handle_error(reason, resolvers, pkg, raise_reason) do
    Nerves.Utils.Shell.warn("     #{reason}")
    do_get(resolvers, pkg, raise_reason)
  end

  defp format_raise_reason(reason) do
    if is_binary(reason), do: reason, else: inspect(reason)
  end
end
