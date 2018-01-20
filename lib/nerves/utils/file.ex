defmodule Nerves.Utils.File do

  def untar(file, destination \\ nil) do
    destination = destination || File.cwd!
    System.cmd("tar", ["xf", file, "--strip-components=1", "-C", destination])
    |> result()
  end

  def validate(file) do
    Path.extname(file)
    |> ext_cmd()
    |> System.cmd(["-t", file])
    |> result()
  end

  def ext_cmd(".xz"), do: "xz"
  def ext_cmd(".gz"), do: "gzip"
  def ext_cmd(".tar"), do: "tar"

  defp result({"", 0}), do: :ok
  defp result({reason, _}), do: {:error, reason}

end
