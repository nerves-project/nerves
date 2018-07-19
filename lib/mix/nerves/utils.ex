defmodule Mix.Nerves.Utils do
  @fwup_semver "~> 0.15 or ~> 1.0.0-dev or ~> 1.0"

  def shell(cmd, args, opts \\ []) do
    stream = opts[:stream] || IO.binstream(:standard_io, :line)
    std_err = opts[:stderr_to_stdout] || true
    opts = Keyword.drop(opts, [:into, :stderr_to_stdout, :stream])
    System.cmd(cmd, args, [into: stream, stderr_to_stdout: std_err] ++ opts)
  end

  def preflight do
    {_, type} = :os.type()
    check_requirements("fwup")
    check_requirements("mksquashfs")
    check_host_requirements(type)
    Mix.Task.run("nerves.loadpaths")
  end

  def check_requirements("mksquashfs") do
    case System.find_executable("mksquashfs") do
      nil ->
        Mix.raise("""
        Squash FS Tools are required to be installed on your system.
        Please see https://hexdocs.pm/nerves/installation.html#host-specific-tools
        for installation instructions
        """)

      _ ->
        :ok
    end
  end

  def check_requirements("fwup") do
    case System.find_executable("fwup") do
      nil ->
        Mix.raise("""
        fwup is required to create and burn firmware.
        Please see https://hexdocs.pm/nerves/installation.html#fwup
        for installation instructions
        """)

      _ ->
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
  end

  def check_host_requirements(:darwin) do
    case System.find_executable("gstat") do
      nil ->
        Mix.raise("""
        gstat is required to create and burn firmware.
        Please see https://hexdocs.pm/nerves/installation.html#host-specific-tools
        for installation instructions
        """)

      _ ->
        :ok
    end
  end

  def check_host_requirements(_), do: nil

  def debug_info(msg) do
    if System.get_env("NERVES_DEBUG") == "1" do
      Mix.shell().info(msg)
    end
  end

  def check_nerves_system_is_set! do
    var_name = "NERVES_SYSTEM"
    System.get_env(var_name) || raise_env_var_missing(var_name)
  end

  def check_nerves_toolchain_is_set! do
    var_name = "NERVES_TOOLCHAIN"
    System.get_env(var_name) || raise_env_var_missing(var_name)
  end

  defp raise_env_var_missing(name) do
    Mix.raise("""
    Environment variable $#{name} is not set.

    This variable is usually set for you by Nerves when you specify the
    $MIX_TARGET. For examples please see
    https://hexdocs.pm/nerves/getting-started.html#create-the-firmware-bundle
    """)
  end
end
