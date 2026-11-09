# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.Artifact.Clean do
  @shortdoc "Clean a Nerves artifact build"
  @moduledoc """
  Clean the build directory for a Nerves artifact

  The package sources, downloads, and cached artifacts are preserved. Use
  `mix nerves.artifact.purge` to remove those as well.

  Pass `--image` to also remove the selected package's container image after
  cleaning. The next build recreates the image using the current Dockerfile
  and build context. Downloads and compiler caches are preserved.
  Image removal fails if the container tool refuses to remove an image in use.

  ## Examples

      $ MIX_TARGET=rpi0 mix nerves.artifact.clean
      $ MIX_TARGET=rpi0 mix nerves.artifact.clean test_system_rpi0
      $ MIX_TARGET=rpi0 mix nerves.artifact.clean --image test_system_rpi0
  """
  use Mix.Task

  alias Nerves.Container
  alias Nerves.MixUtils

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(args) do
    {opts, args, invalid} = OptionParser.parse(args, strict: [image: :boolean])

    if invalid != [] do
      Mix.raise("""
      Invalid options for nerves.artifact.clean: #{inspect(invalid)}

      Use `mix nerves.artifact.purge` to remove cached artifacts and build volumes.
      """)
    end

    build_plan = Nerves.build_plan()
    package = MixUtils.select_package!(build_plan, args)

    {tool, image, dl_dir, _unchanged?} =
      Container.prepare_artifact_workspace!(build_plan, package)

    docker_args =
      Container.artifact_run_args(build_plan, package, tool, image, dl_dir, ["clean"])

    MixUtils.info("Cleaning artifact build for #{package.app} with #{tool}")

    case MixUtils.interactive_cmd(tool, docker_args) do
      {_, 0} -> Container.invalidate_source_checksum(package)
      {_, status} -> Mix.raise("Container clean failed with status #{status}")
    end

    if opts[:image] do
      MixUtils.info("Removing artifact image #{image}")

      case MixUtils.cmd(tool, ["image", "rm", image], stderr_to_stdout: true) do
        {_, 0} ->
          :ok

        {output, status} ->
          Mix.raise("Container image removal failed with status #{status}: #{output}")
      end
    end

    :ok
  end
end
