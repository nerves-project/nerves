# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildAction do
  @moduledoc """
  Behaviour for all functionality in the Nerves firmware build process

  Implementations should add `use Nerves.BuildAction` and only implement
  the callbacks they use. Most actions will only implement one callback
  """

  alias Nerves.BuildPlan

  @doc """
  Callback for updating the build plan once artifacts are extracted

  This can be used to look through artifact contents to adjust to plan
  """
  @callback post_extract(build_plan :: BuildPlan.t(), opts :: keyword()) :: BuildPlan.t()

  @doc """
  Callback for anything that should run before the Mix release gets assembled
  """
  @callback pre_assemble_steps(
              build_plan :: BuildPlan.t(),
              release :: Mix.Release.t(),
              opts :: keyword()
            ) :: Mix.Release.t()

  @doc """
  Callback for processing the release right after assembly, but before rootfs creation
  """
  @callback post_assemble_steps(
              build_plan :: BuildPlan.t(),
              release :: Mix.Release.t(),
              opts :: keyword()
            ) :: Mix.Release.t()

  @doc """
  Callback for creating the rootfs
  """
  @callback rootfs_creation_steps(
              build_plan :: BuildPlan.t(),
              release :: Mix.Release.t(),
              opts :: keyword()
            ) :: Mix.Release.t()

  @doc """
  Callback for everything after rootfs creation and before making the firmware image
  """
  @callback pre_image_creation(build_plan :: BuildPlan.t(), opts :: keyword()) :: :ok

  @doc """
  Callback for creating the firmware image
  """
  @callback image_creation(build_plan :: BuildPlan.t(), opts :: keyword()) :: :ok

  @doc """
  Callback for everything after firmware image creation
  """
  @callback post_image_creation(build_plan :: BuildPlan.t(), opts :: keyword()) :: :ok

  @doc false
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour Nerves.BuildAction

      @doc false
      def post_extract(build_plan, _opts), do: build_plan

      @doc false
      def pre_assemble_steps(_build_plan, release, _opts), do: release

      @doc false
      def post_assemble_steps(_build_plan, release, _opts), do: release

      @doc false
      def rootfs_creation_steps(_build_plan, release, _opts), do: release

      @doc false
      def pre_image_creation(_build_plan, _opts), do: :ok

      @doc false
      def image_creation(_build_plan, _opts), do: :ok

      @doc false
      def post_image_creation(_build_plan, _opts), do: :ok

      defoverridable post_extract: 2,
                     pre_assemble_steps: 3,
                     post_assemble_steps: 3,
                     rootfs_creation_steps: 3,
                     pre_image_creation: 2,
                     image_creation: 2,
                     post_image_creation: 2
    end
  end
end
