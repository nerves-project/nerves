defmodule Nerves.Artifact.Cache do
  alias Nerves.Artifact

  @checksum "CHECKSUM"

  def get(pkg) do 
    path = path(pkg)
    if valid?(pkg) do
      path
    else
      nil
    end
  end

  def put(pkg, path) do
    ext = Artifact.ext(pkg)
    dest = path(pkg)
    if String.ends_with?(path, ext) do
      Nerves.Utils.File.untar(path, dest)
    else
      File.rm_rf!(dest)
      File.mkdir_p!(dest)
      File.ln_s!(path, dest)
    end
    Path.join(dest, @checksum)
    |> File.write(Artifact.checksum(pkg))
  end

  def delete(pkg) do
    path(pkg)
    |> File.rm_rf()
  end

  def valid?(pkg) do
    case read_checksum(pkg) do
      nil -> false
      checksum -> 
        pkg
        |> Artifact.checksum()
        |> String.equivalent?(checksum)
    end
  end

  def path(pkg) do
    Artifact.base_dir()
    |> Path.join(Artifact.name(pkg))
    |> Path.expand
  end

  def checksum_path(pkg) do
    path(pkg)
    |> Path.join(@checksum)
  end

  def read_checksum(pkg) do
    checksum = 
      pkg
      |> checksum_path()
      |> File.read
      
    case checksum do
      {:ok, checksum} ->
        String.trim(checksum)
      {:error, _reason} ->
        nil
    end
  end

end
