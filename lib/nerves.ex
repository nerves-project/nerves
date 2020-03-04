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
        Nerves #{version()} requires
        Elixir:      #{@elixir_version_req}
        OTP release: #{@otp_version_req}

        Your system has
        Elixir:      #{elixir_version}
        OTP release: #{otp_release}

        Please resolve the issue by
        * Installing a version of Elixir / OTP that is compatible with the
          Minimal requirements.
        * Pin your nerves and nerves_bootstrap dependencies to an older
          version that supports your version of Elixir / OTP.
        """)

        :error
    end
  end

  # If distillery is present, load the plugin code
  if Code.ensure_loaded?(Distillery.Releases.Plugin) do
    defdelegate before_assembly(release, opts), to: Nerves.Distillery
    defdelegate after_assembly(release, opts), to: Nerves.Distillery
    defdelegate before_package(release, opts), to: Nerves.Distillery
    defdelegate after_package(release, opts), to: Nerves.Distillery
    defdelegate after_cleanup(release, opts), to: Nerves.Distillery
  end
end
