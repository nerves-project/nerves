defmodule Nerves.Checks do
  @moduledoc false

  # Make sure that the user installed the version of Elixir that was compiled by
  # the same version of Erlang since this it's confusing to debug missing feature
  # issues that happen because of this.
  @spec check_compiler!() :: :ok
  def check_compiler!() do
    otpc = erlang_compiler_version!()
    elixirc = elixir_compiler_version!()

    if otpc.major != elixirc.major do
      Mix.raise("""
      Elixir was compiled by a different version of the Erlang/OTP compiler
      than is being used now. This may not work.

      Erlang compiler used for Elixir: #{elixirc.major}.#{elixirc.minor}.#{elixirc.patch}
      Current Erlang compiler:         #{otpc.major}.#{otpc.minor}.#{otpc.patch}

      Please use a version of Elixir that was compiled using the same major
      version.

      For example:

      If your target is running OTP 25, you should use a version of Elixir
      that was compiled using OTP 25.

      If you're using asdf to manage Elixir versions, run:

      asdf install elixir #{System.version()}-otp-#{System.otp_release()}
      asdf global elixir #{System.version()}-otp-#{System.otp_release()}
      """)
    end

    :ok
  end

  defp erlang_compiler_version!() do
    Application.spec(:compiler, :vsn)
    |> parse_otp_version!()
  end

  defp elixir_compiler_version!() do
    {:file, path} = :code.is_loaded(Kernel)
    {:ok, {_, [compile_info: compile_info]}} = :beam_lib.chunks(path, [:compile_info])
    {:ok, vsn} = Keyword.fetch(compile_info, :version)

    parse_otp_version!(vsn)
  end

  @doc """
  Parse OTP versions

  OTP versions can have anywhere from 2 to 5 parts. Normalize this into
  a 3-part version for convenience. This is a lossy operation, but it
  doesn't matter because the checks aren't needed in this project.

  ```elixir
  iex> Nerves.Checks.parse_otp_version!("24.2") |> to_string()
  "24.2.0"

  iex> Nerves.Checks.parse_otp_version!("23.3.4") |> to_string()
  "23.3.4"

  iex> Nerves.Checks.parse_otp_version!("18.3.4.1.1") |> to_string()
  "18.3.4"

  iex> Nerves.Checks.parse_otp_version!("23.0-rc1") |> to_string()
  "23.0.0-rc1"

  iex> Nerves.Checks.parse_otp_version!("invalid")
  ** (RuntimeError) Unexpected OTP version: "invalid"
  ```
  """
  @spec parse_otp_version!(String.t() | charlist()) :: Version.t()
  def parse_otp_version!(vsn) do
    case Regex.run(~r/^([0-9.]+)(-[0-9a-zA-Z]+)?$/, to_string(vsn)) do
      [_, version] -> normalize_version!(version, "")
      [_, version, pre] -> normalize_version!(version, pre)
      _ -> raise RuntimeError, "Unexpected OTP version: #{inspect(vsn)}"
    end
  end

  defp normalize_version!(version, pre) do
    {major, minor, patch} =
      case String.split(version, ".") do
        [major] -> {major, 0, 0}
        [major, minor] -> {major, minor, 0}
        [major, minor, patch | _] -> {major, minor, patch}
      end

    Version.parse!("#{major}.#{minor}.#{patch}#{pre}")
  end
end
