defmodule Nerves.Utils.File do

  def untar(file, destination \\ nil) do
    destination = destination || File.cwd!
    System.cmd("tar", ["xf", file, "--strip-components=1", "-C", destination])
  end

  def validate(file) do
    cmd = 
      Path.extname(file)
      |> ext_cmd()
    case System.cmd(cmd, ["-t", file]) do
      {"", 0} -> :ok
      {reason, _} -> {:error, reason}
    end
  end

  def ext_cmd(".xz"), do: "xz"
  def ext_cmd(".gz"), do: "gz"
  def ext_cmd(".tar"), do: "tar"

end
