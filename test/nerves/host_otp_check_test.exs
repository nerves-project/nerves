# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.HostOTPCheckTest do
  use ExUnit.Case, async: true

  alias Nerves.HostOTPCheck

  @moduletag :tmp_dir

  defp make_empty_erts(tmp_dir) do
    erts_path = Path.join(tmp_dir, "erts-99.0")
    File.mkdir_p!(erts_path)
    File.mkdir(Path.join(tmp_dir, "bin"))
    File.mkdir(Path.join(tmp_dir, "lib"))
    File.mkdir(Path.join(tmp_dir, "releases"))
    erts_path
  end

  defp make_erts(tmp_dir, otp_version) do
    erts_path = make_empty_erts(tmp_dir)
    otp_major = String.split(otp_version, ".") |> hd()
    otp_version_path = Path.join(tmp_dir, "releases/#{otp_major}/OTP_VERSION")
    File.mkdir_p!(Path.dirname(otp_version_path))
    File.write!(otp_version_path, "#{otp_version}\n")
    erts_path
  end

  test "reads the OTP_VERSION file", %{tmp_dir: tmp_dir} do
    erts_path = make_erts(tmp_dir, "27.3.1")
    assert HostOTPCheck.target_otp_version(erts_path) == "27.3.1"
    assert HostOTPCheck.target_otp_release(erts_path) == "27"
  end

  test "reads the 2-tuple OTP_VERSION file", %{tmp_dir: tmp_dir} do
    erts_path = make_erts(tmp_dir, "28.0")
    assert HostOTPCheck.target_otp_version(erts_path) == "28.0"
    assert HostOTPCheck.target_otp_release(erts_path) == "28"
  end

  test "reads the 4-tuple OTP_VERSION file", %{tmp_dir: tmp_dir} do
    erts_path = make_erts(tmp_dir, "29.0.1.2")
    assert HostOTPCheck.target_otp_version(erts_path) == "29.0.1.2"
    assert HostOTPCheck.target_otp_release(erts_path) == "29"
  end

  test "returns an error string when OTP_VERSION is missing", %{tmp_dir: tmp_dir} do
    erts_path = make_empty_erts(tmp_dir)

    assert HostOTPCheck.target_otp_version(erts_path) == "Missing OTP_VERSION file"
    assert HostOTPCheck.target_otp_release(erts_path) == "Missing OTP_VERSION file"
  end

  test "reads a real OTP_VERSION file" do
    erts_path = Path.join(:code.root_dir(), "erts-#{:erlang.system_info(:version)}")
    assert HostOTPCheck.target_otp_release(erts_path) == System.otp_release()
  end

  test "compatible_target_otp_version? succeeds when correct", %{tmp_dir: tmp_dir} do
    erts_path = make_erts(tmp_dir, "#{System.otp_release()}.0")
    assert HostOTPCheck.compatible_target_otp_version?(erts_path)
  end

  test "compatible_target_otp_version? fails when wrong", %{tmp_dir: tmp_dir} do
    erts_path = make_erts(tmp_dir, "12.0")
    refute HostOTPCheck.compatible_target_otp_version?(erts_path)
  end
end
