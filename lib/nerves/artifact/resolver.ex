defmodule Nerves.Artifact.Resolver do
  @callback get(term) :: {:ok, data :: String.t()} | {:error, term}

  @spec get(term, pkg :: Nerves.Package.t()) :: {:ok, file :: String.t()} | {:error, term}
  def get([], _pkg) do
    {:error, :no_result}
  end

  def get([resolver | resolvers], pkg) do
    case get(resolver, pkg) do
      {:ok, _} = result -> result
      _ -> get(resolvers, pkg)
    end
  end

  def get({resolver, opts}, pkg) do
    apply(resolver, :get, [opts])
    |> result(pkg)
  end

  defp result({:ok, data}, pkg) do
    file = Nerves.Artifact.download_path(pkg)
    File.mkdir_p(Nerves.Env.download_dir())
    File.write(file, data)

    case Nerves.Utils.File.validate(file) do
      :ok ->
        {:ok, file}

      {:error, reason} ->
        File.rm(file)
        {:error, reason}
    end
  end

  defp result(error, _pkg), do: error
end
