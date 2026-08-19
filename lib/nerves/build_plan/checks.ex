# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildPlan.Checks do
  @moduledoc false

  alias Nerves.BuildPlan
  alias Nerves.InvalidPlan

  # All environment variables documented as "Nerves-provided" in
  # guides/advanced/environment-variables.md
  @required_env_vars ~w[
    AR_FOR_BUILD
    AS_FOR_BUILD
    CC
    CC_FOR_BUILD
    CFLAGS
    CFLAGS_FOR_BUILD
    CMAKE_TOOLCHAIN_FILE
    CPPFLAGS
    CPPFLAGS_FOR_BUILD
    CROSSCOMPILE
    CXX
    CXX_FOR_BUILD
    CXXFLAGS
    CXXFLAGS_FOR_BUILD
    ERL_CFLAGS
    ERL_EI_INCLUDE_DIR
    ERL_EI_LIBDIR
    ERL_LDFLAGS
    ERTS_INCLUDE_DIR
    GCC_FOR_BUILD
    LD_FOR_BUILD
    LDFLAGS
    LDFLAGS_FOR_BUILD
    NERVES_APP
    NERVES_SDK_IMAGES
    NERVES_SDK_SYSROOT
    NERVES_SYSTEM
    NERVES_TOOLCHAIN
    PKG_CONFIG_LIBDIR
    PKG_CONFIG_SYSROOT_DIR
    QMAKESPEC
    REBAR_TARGET_ARCH
    STRIP
    TARGET_ABI
    TARGET_ARCH
    TARGET_CPU
    TARGET_GCC_FLAGS
    TARGET_OS
  ]

  @doc """
  Validate the build plan to detect issues that may cause problems later

  Returns the build plan for use in pipelines
  """
  @spec validate!(BuildPlan.t()) :: BuildPlan.t()
  def validate!(%BuildPlan{} = build_plan) do
    # Check that all official Nerves environment variables are set.
    env = BuildPlan.fetch_interpolated_env!(build_plan)

    missing = @required_env_vars -- Map.keys(env)

    if missing != [] do
      raise InvalidPlan,
        message:
          "The following required Nerves environment variables are missing from the build plan: #{Enum.join(missing, ", ")}"
    end

    build_plan
  end

  # defp validate_config!(build_plan) do
  #   [
  #     :pre_assemble_steps,
  #     :post_assemble_steps,
  #     :rootfs_creation_steps,
  #     :image_creation,
  #     :post_image_creation,
  #     :pre_image_creation,
  #     :post_extract
  #     :pre_download
  #   ]
  #   |> Enum.each(&call_config_validators!(build_plan, &1))
  # end

  # defp call_config_validators!(build_plan, step) do
  #   Map.fetch!(build_plan, step)
  #   |> Enum.each(&call_config_validator!(build_plan, &1))
  # end

  # defp call_config_validator!(build_plan, module) when is_atom(module) do
  #   Kernel.function_exported?(module, :validate, 1) and
  #     module.validate!(build_plan)
  # end
end
