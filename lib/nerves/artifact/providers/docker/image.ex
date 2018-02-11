defmodule Nerves.Artifact.Providers.Docker.Image do
  alias Nerves.Artifact.Providers.Docker
  import Docker.Utils

  def create(dockerfile, tag) do
    cmd = "docker"
    path = Path.dirname(dockerfile)
    args = ["build", "--tag", "#{tag}", path]
    shell_info("Create image")

    if Mix.shell().yes?("The Nerves Docker provider needs to create the image.\nProceed? ") do
      case Mix.Nerves.Utils.shell(cmd, args) do
        {_, 0} -> :ok
        _ -> Mix.raise("Nerves Docker provider could not create docker volume nerves_cache")
      end
    else
      Mix.raise("Unable to use Nerves Docker provider without image")
    end
  end

  def pull(tag) do
    shell_info("Trying to pull image")
    cmd = "docker"
    args = ["pull", "#{tag}"]

    case System.cmd(cmd, args, stderr_to_stdout: true) do
      {<<"Cannot connect to the Docker daemon", _tail::binary>>, _} ->
        Mix.raise("Nerves Docker provider is unable to connect to docker daemon")

      {_, 0} ->
        true

      {_reason, _} ->
        false
    end
  end

  def exists?(tag) do
    cmd = "docker"
    args = ["image", "ls", "#{tag}", "-q"]

    case System.cmd(cmd, args, stderr_to_stdout: true) do
      {"", _} ->
        false

      {<<"Cannot connect to the Docker daemon", _tail::binary>>, _} ->
        Mix.raise("Nerves Docker provider is unable to connect to docker daemon")

      {_, 0} ->
        true
    end
  end
end
