defmodule Mix.Nerves.Preflight do
  @fwup_semver "~> 1.2.5 or ~> 1.3"

  def check! do
    {_, type} = :os.type()
    check_requirements("fwup")
    ensure_available!("mksquashfs", package: "squashfs")
    check_host_requirements(type)
    Mix.Task.run("nerves.loadpaths")
  end

  defp check_requirements("fwup") do
    ensure_available!("fwup")

    with {vsn, 0} <- System.cmd("fwup", ["--version"]),
         vsn = String.trim(vsn),
         {:ok, req} = Version.parse_requirement(@fwup_semver),
         true <- Version.match?(vsn, req) do
      :ok
    else
      false ->
        {vsn, 0} = System.cmd("fwup", ["--version"])

        Mix.raise("""
        fwup #{@fwup_semver} is required for Nerves.

        You are running #{vsn}.
        Please see https://hexdocs.pm/nerves/installation.html#fwup
        for installation instructions
        """)

      error ->
        Mix.raise("""
        Nerves encountered an error while checking host requirements for fwup
        #{inspect(error)}
        Please open a bug report for this issue on github.com/nerves-project/nerves
        """)
    end
  end

  defp check_host_requirements(:darwin) do
    ensure_available!("gstat", package: "gstat (coreutils)")
  end

  defp check_host_requirements(_), do: nil

  defp ensure_available!(executable, opts \\ []) do
    if System.find_executable(executable) do
      :ok
    else
      package = opts[:package] || executable
      Mix.raise(missing_package_message(package))
    end
  end

  defp missing_package_message(package) do
    """
    #{package} is required by the Nerves tooling.

    Please see https://hexdocs.pm/nerves/installation.html for installation
    instructions.
    """
  end
end
