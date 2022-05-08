defmodule Nerves.Artifact.BuildRunners.Docker.Volume do
  @moduledoc false
  import Nerves.Artifact.BuildRunners.Docker.Utils
  alias Nerves.Artifact

  @spec name(Nerves.Package.t()) :: String.t()
  def name(pkg) do
    "#{pkg.app}-#{id(pkg)}"
  end

  @spec id(Nerves.Package.t()) :: String.t()
  def id(pkg) do
    id_file = id_file(pkg)

    if File.exists?(id_file) do
      File.read!(id_file)
    else
      create_id(pkg)
      id(pkg)
    end
  end

  defp id_file(pkg) do
    Artifact.build_path(pkg)
    |> Path.join(".docker_id")
  end

  defp create_id(pkg) do
    id_file = id_file(pkg)
    id = Nerves.Utils.random_alpha_num(16)

    Path.dirname(id_file)
    |> File.mkdir_p!()

    File.write!(id_file, id)
  end

  @spec delete(String.t()) :: :ok
  def delete(volume_name) do
    shell_info("Deleting build volume #{volume_name}")
    args = ["volume", "rm", volume_name]

    case Mix.Nerves.Utils.shell("docker", args) do
      {_result, 0} ->
        :ok

      {_result, _} ->
        Mix.raise("""
        Nerves Docker build_runner encountered an error while deleting volume #{volume_name}
        """)
    end
  end

  @spec exists?(String.t()) :: boolean()
  def exists?(volume_name) do
    cmd = "docker"
    args = ["volume", "ls", "-f", "name=#{volume_name}", "-q"]

    case Nerves.Port.cmd(cmd, args, stderr_to_stdout: true) do
      {<<^volume_name, _tail::binary>>, 0} ->
        true

      {<<"Cannot connect to the Docker daemon", _tail::binary>>, _} ->
        Mix.raise("Nerves Docker build_runner is unable to connect to docker daemon")

      _ ->
        false
    end
  end

  @spec create(String.t()) :: :noop
  def create(volume_name) do
    cmd = "docker"
    args = ["volume", "create", "--name", volume_name]

    case Nerves.Port.cmd(cmd, args) do
      {_, 0} -> :noop
      _ -> Mix.raise("Nerves Docker build_runner could not create docker volume #{volume_name}")
    end
  end
end
