defmodule Nerves.Artifact.Cache do
  @moduledoc false
  alias Nerves.Artifact
  alias Nerves.Package

  @checksum "CHECKSUM"

  @spec get(Package.t()) :: binary() | nil
  def get(pkg) do
    path = path(pkg)

    if valid?(pkg) do
      path
    else
      nil
    end
  end

  @spec put(Package.t(), binary()) :: :ok | {:error, File.posix()}
  def put(pkg, path) do
    ext = Artifact.ext(pkg)
    dest = path(pkg)

    _ = File.rm_rf(dest)

    if String.ends_with?(path, ext) do
      File.mkdir_p!(dest)
      :ok = Nerves.Utils.File.untar(path, dest)
    else
      Path.dirname(dest)
      |> File.mkdir_p!()

      File.ln_s!(path, dest)
    end

    Path.join(dest, @checksum)
    |> File.write(Artifact.checksum(pkg))
  end

  @spec delete(Package.t()) :: {:ok, [binary()]} | {:error, File.posix(), binary()}
  def delete(pkg) do
    path(pkg)
    |> File.rm_rf()
  end

  @spec valid?(Package.t()) :: boolean()
  def valid?(pkg) do
    path = checksum_path(pkg)

    case read_checksum(path) do
      nil ->
        try_link(pkg)

      checksum ->
        valid_checksum?(pkg, checksum)
    end
  end

  @spec path(Package.t()) :: binary()
  def path(pkg) do
    Artifact.base_dir()
    |> Path.join(Artifact.name(pkg))
    |> Path.expand()
  end

  @spec checksum_path(Package.t()) :: binary()
  def checksum_path(pkg) do
    path(pkg)
    |> Path.join(@checksum)
  end

  defp read_checksum(path) do
    case File.read(path) do
      {:ok, checksum} ->
        String.trim(checksum)

      {:error, _reason} ->
        nil
    end
  end

  defp valid_checksum?(_pkg, nil), do: false

  defp valid_checksum?(pkg, checksum) do
    pkg
    |> Artifact.checksum()
    |> String.equivalent?(checksum)
  end

  defp try_link(pkg) do
    build_path_link = Artifact.build_path_link(pkg)
    checksum_path = Path.join(build_path_link, @checksum)
    checksum = read_checksum(checksum_path)

    if valid_checksum?(pkg, checksum) do
      dest = path(pkg)
      File.mkdir_p!(Artifact.base_dir())
      _ = File.rm_rf!(dest)
      File.ln_s!(build_path_link, dest)
      true
    else
      false
    end
  end
end
