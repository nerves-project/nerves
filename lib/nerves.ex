defmodule Nerves do
  @elixir_version_req ">= 1.7.0"
  @otp_version_req ">= 21.0.0"

  def version, do: unquote(Mix.Project.config()[:version])
  def elixir_version, do: unquote(System.version())
  def otp_release, do: unquote(System.otp_release())

  def system_requirements(elixir_version \\ nil, otp_release \\ nil) do
    elixir_version = elixir_version || elixir_version()
    otp_release = otp_release || otp_release()

    with {:ok, otp_rel_version} <- Version.parse(otp_release <> ".0.0"),
         true <- Version.match?(elixir_version, @elixir_version_req),
         true <- Version.match?(otp_rel_version, @otp_version_req) do
      :ok
    else
      _ ->
        Nerves.Utils.Shell.warn("""
        Nerves #{version()} requires at least Elixir #{@elixir_version_req} and Erlang/OTP #{@otp_version_req}.

        Your system has Elixir #{elixir_version} and Erlang/OTP #{otp_release}.

        Please resolve this by either:

        1. Installing a compatible version of Elixir and Erlang/OTP

        2. Pinning your nerves and nerves_bootstrap dependencies to
           older versions.
        """)

        :error
    end
  end
end
