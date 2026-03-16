# SPDX-FileCopyrightText: 2018 Justin Schneck
# SPDX-FileCopyrightText: 2020 Frank Hunleth
# SPDX-FileCopyrightText: 2022 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.Resolver do
  @moduledoc false

  @callback get(tuple()) :: {:ok, term()} | {:error, term}

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

  defp do_get([{resolver, {id, resolver_opts}} | resolvers], pkg, raise_reason) do
    file = Nerves.Artifact.download_path(pkg)
    tmp_file = file <> ".tmp"
    File.mkdir_p!(Nerves.Env.download_dir())

    resolver_opts = Keyword.put(resolver_opts, :into, File.stream!(tmp_file))

    case resolver.get({id, resolver_opts}) do
      {:ok, _} ->
        File.rename!(tmp_file, file)
        validate_and_continue(file, resolvers, pkg)

      {:error, reason} ->
        _ = File.rm(tmp_file)
        handle_error(reason, resolvers, pkg, raise_reason)
    end
  end

  defp validate_and_continue(file, resolvers, pkg) do
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
