# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Integration.NervesNewTest do
  use ExUnit.Case

  # Allow a minute in case downloads are slow
  @test_timeout 120_000

  @tag :integration
  @tag timeout: @test_timeout
  test "nerves.new project for rpi0", _context do
    path = fixture_for_nerves_version()
    clean_build!(path)

    # Both host and rpi0 builds should work
    run_mix_deps_get!(path)
    run_mix_task!(path, "rpi0", "firmware")
    run_mix_task!(path, "host", "compile")
    run_mix_task!(path, "rpi0", "firmware.metadata")
    run_mix_task!(path, "rpi0", "firmware.image")
    run_mix_task!(path, "rpi0", "firmware.unpack")

    # Test out artifact management commands since artifacts will have been downloaded
    run_mix_task!(path, "host", "nerves.artifact.ls")
    run_mix_task!(path, "rpi0", "nerves.artifact.details")
  end

  defp clean_build!(path) do
    File.rm_rf!(Path.join(path, "_build"))
  end

  defp run_mix_task!(path, target, task) do
    env = [{"MIX_ENV", "dev"}, {"MIX_TARGET", target}]
    cover_export = "nerves_new_#{String.replace(task, ".", "_")}"
    {_, 0} = CoverHelper.mix([task], cd: path, env: env, cover_export: cover_export)
  end

  defp run_mix_deps_get!(path) do
    # CoverHelper has a chicken/egg issue when covering deps.get, but there's
    # no interesting code to cover there.
    env = [{"MIX_ENV", "dev"}, {"MIX_TARGET", "host"}]

    {_, 0} =
      System.cmd("mix", ["deps.get"],
        cd: path,
        env: env,
        stderr_to_stdout: true,
        into: IO.stream()
      )
  end

  defp fixture_for_nerves_version() do
    otp = otp_release()
    name = "nerves_new_otp#{otp}"

    # The test fixtures have to be kept on the root level since it wasn't
    # until Elixir 1.19 that there was a way to filter out Elixir files in
    # the fixture. TODO!!!!
    path = Path.expand("../fixtures/build_plans/#{name}", __DIR__)

    assert File.dir?(path), "No fixture for OTP #{otp}. Tried #{path}"
    path
  end

  defp otp_release() do
    :erlang.system_info(:otp_release) |> List.to_integer()
  end
end
