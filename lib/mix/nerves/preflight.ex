defmodule Mix.Nerves.Preflight do
  @moduledoc false
  alias Nerves.Utils.WSL

  @fwup_semver "~> 1.8"

  @doc """
  Run the preflight checks for the Nerves System
  """
  @spec check!() :: any()
  def check!() do
    :os.type()
    |> case do
      {_, :linux} -> if WSL.running_on_wsl?(), do: :wsl, else: :linux
      {_, type} -> type
    end
    |> check_platform!()

    Mix.Task.run("nerves.loadpaths")
  end

  # OSX
  defp check_platform!(:darwin) do
    ensure_fwup_version!()
    ensure_available!("mksquashfs", package: "squashfs")
    ensure_available!("gstat", package: "gstat (coreutils)")
  end

  # NOTE: We currently require fwup to be installed both in WSL and in Windows
  # because the fwup.exe in Windows is used when burning firmware to a physical
  # memory card, and fwup in WSL is used for most other operations.
  #
  # WSL 2 adds some new lower-level integrations that may eliminate the need
  # for this in the future, but we'll need to do some more research.
  defp check_platform!(:wsl) do
    ensure_fwup_version!()
    ensure_fwup_version!("fwup.exe")
    ensure_available!("mksquashfs", package: "squashfs")
  end

  # Non-WSL Linux
  defp check_platform!(_) do
    ensure_fwup_version!()
    ensure_available!("mksquashfs", package: "squashfs")
  end

  @doc """
  Ensure fwup executable is available and is the expected version
  """
  @spec ensure_fwup_version!(String.t(), String.t()) :: :ok
  def ensure_fwup_version!(fwup_bin \\ "fwup", vsn_requirement \\ @fwup_semver) do
    ensure_available!(fwup_bin)

    case Nerves.Port.cmd(fwup_bin, ["--version"]) do
      {vsn, 0} ->
        vsn = String.trim(vsn)
        {:ok, req} = Version.parse_requirement(vsn_requirement)

        unless Version.match?(vsn, req) do
          Mix.raise("""
          #{fwup_bin} #{vsn_requirement} is required for Nerves.

          You are running #{vsn}.
          Please see https://hexdocs.pm/nerves/installation.html#fwup
          for installation instructions
          """)
        end

      error ->
        Mix.raise("""
        Nerves encountered an error while checking host requirements for fwup
        #{inspect(error)}
        Please open a bug report for this issue on github.com/nerves-project/nerves
        """)
    end

    :ok
  end

  @doc """
  Ensure that the given command is available in the system path
  """
  @spec ensure_available!(String.t(), Keyword.t()) :: :ok
  def ensure_available!(executable, opts \\ []) do
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
