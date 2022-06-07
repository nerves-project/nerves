defmodule Nerves.Artifact.Resolver do
  @moduledoc false

  @callback get(term) :: {:ok, data :: String.t()} | {:error, term}

  @spec get(term, pkg :: Nerves.Package.t()) :: {:ok, file :: String.t()} | {:error, term}
  def get([], _pkg) do
    {:error, :no_result}
  end

  def get(resolvers, pkg) do
    do_get(resolvers, pkg)
  end

  defp do_get(_, _, _raise \\ nil)
  defp do_get([], _pkg, nil), do: {:error, :no_result}
  defp do_get([], _pkg, reason), do: Mix.raise(reason)

  defp do_get([{resolver, opts} | resolvers], pkg, raise_reason) do
    case resolver.get(opts) do
      {:ok, data} ->
        file = Nerves.Artifact.download_path(pkg)
        File.mkdir_p!(Nerves.Env.download_dir())
        File.write!(file, data)

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

      {:error, reason} ->
        Nerves.Utils.Shell.warn("     #{reason}")
        do_get(resolvers, pkg, raise_reason)
    end
  end

  defp format_raise_reason(reason) do
    if is_binary(reason), do: reason, else: inspect(reason)
  end
end
