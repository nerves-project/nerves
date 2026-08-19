# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildPlan.ChecksTest do
  use ExUnit.Case, async: false

  alias Nerves.BuildPlan

  defp passing_plan() do
    env =
      ~w[AR_FOR_BUILD AS_FOR_BUILD CC CC_FOR_BUILD CFLAGS CFLAGS_FOR_BUILD CMAKE_TOOLCHAIN_FILE
           CPPFLAGS CPPFLAGS_FOR_BUILD CROSSCOMPILE CXX CXX_FOR_BUILD CXXFLAGS CXXFLAGS_FOR_BUILD
           ERL_CFLAGS ERL_EI_INCLUDE_DIR ERL_EI_LIBDIR ERL_LDFLAGS ERTS_INCLUDE_DIR GCC_FOR_BUILD
           LD_FOR_BUILD LDFLAGS LDFLAGS_FOR_BUILD NERVES_APP NERVES_SDK_IMAGES NERVES_SDK_SYSROOT
           NERVES_SYSTEM NERVES_TOOLCHAIN PKG_CONFIG_LIBDIR PKG_CONFIG_SYSROOT_DIR QMAKESPEC
           REBAR_TARGET_ARCH STRIP TARGET_ABI TARGET_ARCH TARGET_CPU TARGET_GCC_FLAGS TARGET_OS]
      |> Map.new(&{&1, "value"})

    %BuildPlan{env: env}
  end

  test "passing plan passes" do
    build_plan = passing_plan()
    assert ^build_plan = BuildPlan.validate!(build_plan)
  end

  test "missing environment variable is detected" do
    starting_plan = passing_plan()
    build_plan = %{starting_plan | env: Map.delete(starting_plan.env, "CROSSCOMPILE")}

    assert_raise Nerves.InvalidPlan, ~r/CROSSCOMPILE/, fn ->
      BuildPlan.validate!(build_plan)
    end
  end
end
