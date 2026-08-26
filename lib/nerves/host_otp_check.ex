# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.HostOTPCheck do
  @moduledoc false

  @doc """
  Return true if the target's OTP version is compatible with the host

  This checks whether the host's compiler will generate .beam files
  that will run on the target. Currently it's an equality check since
  that's the safest.

  Past issues that have caused us to want this check:

  1. A newer host OTP can generate instructions that the target doesn't know about. Often
     results in a boot crash
  2. Changes to how compiled regexes are stored results in
     regexes that don't work at runtime.
  """
  @spec compatible_target_otp_version?(Path.t()) :: boolean
  def compatible_target_otp_version?(erts_path) do
    target_otp_release(erts_path) == System.otp_release()
  end

  @doc """
  Return the target's major OTP version string from the erts path

  The erts path points to an `erts-x.y.z` directory. This function
  walks up one level and reads the OTP_VERSION file in the releases
  directory to determine the full OTP version, then returns only the
  major version (the part before the first dot).
  """
  @spec target_otp_release(Path.t()) :: String.t()
  def target_otp_release(erts_path) do
    version = target_otp_version(erts_path)

    case String.split(version, ".") do
      [not_version] -> not_version
      [major | _] -> major
    end
  end

  @doc """
  Return the target's full OTP version string from the erts path

  Returns `"Missing OTP_VERSION file"` when the file cannot be found.
  """
  @spec target_otp_version(Path.t()) :: String.t()
  def target_otp_version(erts_path) do
    releases_dir = Path.expand("../releases", erts_path)

    with [path] <- Path.wildcard("#{releases_dir}/*/OTP_VERSION"),
         {:ok, contents} <- File.read(path) do
      String.trim(contents)
    else
      _ -> "Missing OTP_VERSION file"
    end
  end
end
