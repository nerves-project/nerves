# SPDX-FileCopyrightText: 2016 Justin Schneck
# SPDX-FileCopyrightText: 2020 Jon Carstens
# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.HostElixirCheck do
  @moduledoc false

  @doc """
  Check that the host Elixir was compiled with a matching Erlang version

  This catches cases where Elixir has a workaround compiled in for the version
  of Erlang running on the host rather than for the version of Erlang running
  on the target. This is important since the Elixir `.beam` files from the host
  are copied over to the target firmware.

  The reality is that there are a lot of cases where this mismatch doesn't
  matter. No one wants to debug those cases where it does matter, though.
  """
  @spec check!() :: :ok
  def check!() do
    {:ok, otpc} = erlang_compiler_version()
    {:ok, elixirc} = elixir_compiler_version()

    if otpc.major != elixirc.major do
      otp_release = System.otp_release()

      Mix.raise("""
      Elixir was compiled by a different version of the Erlang/OTP compiler
      than is being used now. This may not work.

      Erlang compiler used for Elixir: #{elixirc.major}.#{elixirc.minor}.#{elixirc.patch}
      Current Erlang compiler:         #{otpc.major}.#{otpc.minor}.#{otpc.patch}

      Please use a version of Elixir that was compiled using the same major
      version. The Erlang compiler version is not the same as the more visible
      Erlang/OTP version, but it gets incremented similarly.

      You'll need a version of Elixir compiled with OTP #{otp_release}.

      If you're using asdf to manage Elixir versions, run:

      asdf install elixir #{System.version()}-otp-#{System.otp_release()}
      asdf set elixir #{System.version()}-otp-#{System.otp_release()}
      """)
    end

    :ok
  end

  defp erlang_compiler_version() do
    Application.spec(:compiler, :vsn)
    |> to_string()
    |> parse_otp_version()
  end

  defp elixir_compiler_version() do
    {:file, path} = :code.is_loaded(Kernel)
    {:ok, {_, [compile_info: compile_info]}} = :beam_lib.chunks(path, [:compile_info])
    {:ok, vsn} = Keyword.fetch(compile_info, :version)

    vsn
    |> to_string()
    |> parse_otp_version()
  end

  @doc """
  Parse OTP versions

  OTP versions can have anywhere from 2 to 5 parts. Normalize this into
  a 3-part version for convenience. This is a lossy operation, but it
  doesn't matter because the checks aren't needed in this project.

  ```elixir
  iex> {:ok, version} = Nerves.MixUtils.parse_otp_version("24.2")
  iex> to_string(version)
  "24.2.0"

  iex> {:ok, version} = Nerves.MixUtils.parse_otp_version("23.3.4")
  iex> to_string(version)
  "23.3.4"

  iex> {:ok, version} = Nerves.MixUtils.parse_otp_version("18.3.4.1.1")
  iex> to_string(version)
  "18.3.4"

  iex> {:ok, version} = Nerves.MixUtils.parse_otp_version("23.0-rc1")
  iex> to_string(version)
  "23.0.0-rc1"

  iex> Nerves.MixUtils.parse_otp_version("invalid")
  {:error, "Unexpected OTP version: \\"invalid\\""}
  ```
  """
  @spec parse_otp_version(String.t()) :: {:error, String.t()} | {:ok, Version.t()} | :error
  def parse_otp_version(vsn) do
    case Regex.run(~r/^([0-9.]+)(-[0-9a-zA-Z]+)?$/, vsn) do
      [_, version] -> normalize_version(version, "")
      [_, version, pre] -> normalize_version(version, pre)
      _ -> {:error, "Unexpected OTP version: #{inspect(vsn)}"}
    end
  end

  defp normalize_version(version, pre) do
    {major, minor, patch} =
      case String.split(version, ".") do
        [major] -> {major, 0, 0}
        [major, minor] -> {major, minor, 0}
        [major, minor, patch | _] -> {major, minor, patch}
      end

    Version.parse("#{major}.#{minor}.#{patch}#{pre}")
  end
end
