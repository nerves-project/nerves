defmodule Nerves.Artifact.BuildRunners.Docker.Image do
  @moduledoc false
  import Nerves.Artifact.BuildRunners.Docker.Utils

  @doc false
  @spec create(Path.t(), String.t()) :: :ok
  def create(dockerfile, tag) do
    cmd = "docker"
    path = Path.dirname(dockerfile)
    args = ["build", "--tag", "#{tag}", path]
    shell_info("Create image")

    if Mix.shell().yes?("The Nerves Docker build_runner needs to create the image.\nProceed? ") do
      case Mix.Nerves.Utils.shell(cmd, args) do
        {_, 0} -> :ok
        _ -> Mix.raise("Nerves Docker build_runner could not create docker volume nerves_cache")
      end
    else
      Mix.raise("Unable to use Nerves Docker build_runner without image")
    end
  end

  @doc false
  @spec pull(String.t()) :: boolean()
  def pull(tag) do
    shell_info("Trying to pull image")
    cmd = "docker"
    args = ["pull", "#{tag}"]

    case Nerves.Port.cmd(cmd, args, stderr_to_stdout: true) do
      {<<"Cannot connect to the Docker daemon", _tail::binary>>, _} ->
        Mix.raise("Nerves Docker build_runner is unable to connect to docker daemon")

      {_, 0} ->
        true

      {_reason, _} ->
        false
    end
  end

  @doc false
  @spec exists?(String.t()) :: boolean()
  def exists?(tag) do
    cmd = "docker"
    args = ["image", "ls", "#{tag}", "-q"]

    case Nerves.Port.cmd(cmd, args, stderr_to_stdout: true) do
      {"", _} ->
        false

      {<<"Cannot connect to the Docker daemon", _tail::binary>>, _} ->
        Mix.raise("Nerves Docker build_runner is unable to connect to docker daemon")

      {_, 0} ->
        true
    end
  end
end
