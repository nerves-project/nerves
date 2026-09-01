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
    project_name = Path.basename(path)

    # Both host and rpi0 builds should work
    run_mix_task!(path, "host", "deps.get")
    assert File.exists?(Path.join([path, "deps"]))

    run_mix_task!(path, "rpi0", "firmware")

    assert File.exists?(
             Path.join([path, "_build", "rpi0_dev", "nerves", "images", "#{project_name}.fw"])
           )

    run_mix_task!(path, "host", "compile")
    assert File.exists?(Path.join([path, "_build", "dev"]))

    run_mix_task!(path, "rpi0", "firmware.metadata")
    # Trust that failures result in error returns

    run_mix_task!(path, "rpi0", "firmware.image")
    assert File.exists?(Path.join(path, "#{project_name}.img"))

    run_mix_task!(path, "rpi0", "firmware.unpack")
    assert File.exists?(Path.join([path, "#{project_name}.unpacked", "rootfs", "srv", "erlang"]))

    # Test out artifact management commands since artifacts will have been downloaded
    run_mix_task!(path, "host", "nerves.artifact.ls")
    run_mix_task!(path, "rpi0", "nerves.artifact.details")
  end

  @tag :integration
  @tag timeout: @test_timeout
  test "nerves.new project fails for incorrect OTP version" do
    path = fixture_for_incorrect_otp_version()
    clean_build!(path)

    run_mix_task!(path, "host", "deps.get")

    {_, exit_code} = run_mix_task(path, "rpi0", "firmware")
    assert exit_code != 0
  end

  defp clean_build!(path) do
    File.rm_rf!(Path.join(path, "_build"))
  end

  defp run_mix_task!(path, target, task) do
    {_, 0} = run_mix_task(path, target, task)
  end

  defp run_mix_task(path, target, task) do
    env = [{"MIX_ENV", "dev"}, {"MIX_TARGET", target}]
    CoverHelper.mix([task], cd: path, env: env)
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

  defp fixture_for_incorrect_otp_version() do
    otp = otp_release()
    name = "nerves_new_otp#{otp}"

    path =
      Path.wildcard(Path.expand("../fixtures/build_plans/nerves_new_otp*", __DIR__))
      |> Enum.find(&(Path.basename(&1) != name))

    assert path, "No fixture for an OTP other than #{otp}"
    path
  end

  defp otp_release() do
    :erlang.system_info(:otp_release) |> List.to_integer()
  end
end
