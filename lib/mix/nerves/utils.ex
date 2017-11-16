defmodule Mix.Nerves.Utils do
  @fwup_semver "~> 0.15 or ~> 1.0.0-dev or ~> 1.0"

  def shell(cmd, args, opts \\ []) do
    stream = opts[:stream] || IO.binstream(:standard_io, :line)
    std_err = opts[:stderr_to_stdout] || true
    opts = Keyword.drop(opts, [:into, :stderr_to_stdout, :stream])
    System.cmd(cmd, args, [into: stream, stderr_to_stdout: std_err] ++ opts)
  end

  def preflight do
    check_requirements()
    Mix.Task.run "nerves.loadpaths"
  end

  def check_requirements do
    {_, type} = :os.type

    which_or_where = case type do
                        :nt -> "where"
                        _ -> "which"
                     end

    case System.cmd(which_or_where, ["mksquashfs"]) do
      {_, 0} -> nil
      _ -> Mix.raise """
      Squash FS Tools are required to be installed on your system.
      Please see https://hexdocs.pm/nerves/installation.html#host-specific-tools
      for installation instructions
      """
    end

    with {_, 0} <- System.cmd(which_or_where, ["fwup"]),
         {vsn, 0} <- System.cmd("fwup", ["--version"]),
         vsn = String.trim(vsn),
         {:ok, req} = Version.parse_requirement(@fwup_semver),
         true <- Version.match?(vsn, req) do
    else
      false ->
        {vsn, 0} = System.cmd("fwup", ["--version"])
        Mix.raise """
        fwup #{@fwup_semver} is required for Nerves.
        You are running #{vsn}.
        Please see https://hexdocs.pm/nerves/installation.html#fwup
        for installation instructions
        """
      {_, _} ->
        Mix.raise """
        fwup is required to create and burn firmware.
        Please see https://hexdocs.pm/nerves/installation.html#fwup
        for installation instructions
        """
    end

    check_host_requirements(type)
  end

  def check_host_requirements(:darwin) do
    case System.cmd("which", ["gstat"]) do
      {_, 0} -> nil
      _ -> Mix.raise """
      gstat is required to create and burn firmware.
      Please see https://hexdocs.pm/nerves/installation.html#host-specific-tools
      for installation instructions
      """
    end
  end
  def check_host_requirements(_), do: nil

  def debug_info(msg) do
    if System.get_env("NERVES_DEBUG") == "1" do
      Mix.shell.info(msg)
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
    Mix.raise """
    Environment variable $#{name} is not set.

    This variable is usually set for you by Nerves when you specify the
    $MIX_TARGET. For examples please see
    https://hexdocs.pm/nerves/getting-started.html#create-the-firmware-bundle
    """
  end
end
