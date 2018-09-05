defmodule Nerves.Utils.File do
  def untar(file, destination \\ nil) do
    destination = destination || File.cwd!()

    cmd("tar", ["xf", file, "--strip-components=1", "-C", destination])
    |> result()
  end

  @doc """
  Create a tar of the contents of the path and specified output file
  """
  def tar(path, file) do
    working_dir = Path.dirname(path)
    path = Path.basename(path)

    cmd("tar", ["-czf", file, "-C", working_dir, path])
    |> result()
  end

  def validate(file) do
    Path.extname(file)
    |> ext_cmd()
    |> cmd(["-t", file])
    |> result()
  end

  def ext_cmd(".xz"), do: "xz"
  def ext_cmd(".gz"), do: "gzip"
  def ext_cmd(".tar"), do: "tar"

  defp result({"", 0}), do: :ok
  defp result({reason, _}), do: {:error, reason}

  defp cmd(cmd, args) do
    if System.find_executable(cmd) do
      System.cmd(cmd, args, stderr_to_stdout: true)
    else
      {"#{cmd} not found.  See README.md for Host Requirements", nil}
    end
  end
end
