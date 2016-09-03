defmodule Mix.Nerves.Utils do
  @fwup_semver "~> 0.8"

  def shell(cmd, args, stream \\ IO.binstream(:standard_io, :line)) do
    System.cmd(cmd, args, into: stream, stderr_to_stdout: true)
  end

  def preflight do
    check_requirements
    Mix.Task.run "nerves.loadpaths"
  end

  def check_requirements do
    case System.cmd("which", ["mksquashfs"]) do
      {_, 0} -> nil
      _ -> Mix.raise """
      Squash FS Tools are required to be installed on your system.
      Please see https://hexdocs.pm/nerves/installation.html#host-specific-tools
      for installation instructions
      """
    end

    case System.cmd("fwup", ["--version"]) do
      {vsn, 0} ->
        vsn = String.strip(vsn)
        {:ok, req} = Version.parse_requirement(@fwup_semver)
        unless Version.match?(vsn, req) do
          Mix.raise """
          fwup #{@fwup_semver} is required for Nerves.
          You are running #{vsn}.
          Please see https://hexdocs.pm/nerves/installation.html#fwup
          for installation instructions
          """
        end
      _ -> Mix.raise """
      fwup is required to create and burn firmware.
      Please see https://hexdocs.pm/nerves/installation.html#fwup
      for installation instructions
      """
    end

    {_, type} = :os.type
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
end
