defmodule Mix.Nerves.Utils do
  alias Nerves.Utils.WSL

  @fwup_semver "~> 1.2.5 or ~> 1.3"

  def shell(cmd, args, opts \\ []) do
    stream = opts[:stream] || IO.binstream(:standard_io, :line)
    std_err = opts[:stderr_to_stdout] || true
    env = Keyword.get(opts, :env, []) ++ [{"PATH", sanitize_path()}]

    opts =
      opts
      |> Keyword.drop([:into, :stderr_to_stdout, :stream])
      |> Keyword.put(:env, env)

    System.cmd(cmd, args, [into: stream, stderr_to_stdout: std_err] ++ opts)
  end

  def preflight do
    {_, type} = :os.type()
    check_requirements("fwup")
    check_requirements("mksquashfs")
    check_host_requirements(type)
    Mix.Task.run("nerves.loadpaths")
  end

  defp check_requirements("mksquashfs") do
    case System.find_executable("mksquashfs") do
      nil ->
        Mix.raise(missing_package_message("squashfs"))

      _ ->
        :ok
    end
  end

  defp check_requirements("fwup") do
    case System.find_executable("fwup") do
      nil ->
        Mix.raise(missing_package_message("fwup"))

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

  defp check_host_requirements(:darwin) do
    case System.find_executable("gstat") do
      nil ->
        Mix.raise(missing_package_message("gstat (coreutils)"))

      _ ->
        :ok
    end
  end

  defp check_host_requirements(_), do: nil

  defp missing_package_message(package) do
    """
    #{package} is required by the Nerves tooling.

    Please see https://hexdocs.pm/nerves/installation.html#host-specific-tools
    for installation instructions.
    """
  end

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

  def get_devs do
    {result, 0} =
      if WSL.running_on_wsl?() do
        WSL.get_fwup_devices()
      else
        System.cmd("fwup", ["--detect"])
      end

    if result == "" do
      Mix.raise("Could not auto detect your SD card")
    end

    result
    |> String.trim()
    |> String.split("\n")
    |> Enum.map(&String.split(&1, ","))
  end

  def prompt_dev() do
    case get_devs() do
      [[dev, bytes]] ->
        choice =
          Mix.shell().yes?("Use #{bytes_to_gigabytes(bytes)} GiB memory card found at #{dev}?")

        if choice do
          dev
        else
          Mix.raise("Aborted")
        end

      devs ->
        choices =
          devs
          |> Enum.zip(0..length(devs))
          |> Enum.reduce([], fn {[dev, bytes], idx}, acc ->
            ["#{idx}) #{bytes_to_gigabytes(bytes)} GiB found at #{dev}" | acc]
          end)
          |> Enum.reverse()

        choice =
          Mix.shell().prompt(
            "Discovered devices:\n#{Enum.join(choices, "\n")}\nWhich device do you want to burn to?"
          )
          |> String.trim()

        idx =
          case Integer.parse(choice) do
            {idx, _} -> idx
            _ -> Mix.raise("Invalid selection #{choice}")
          end

        case Enum.fetch(devs, idx) do
          {:ok, [dev, _]} -> dev
          _ -> Mix.raise("Invalid selection #{choice}")
        end
    end
  end

  def bytes_to_gigabytes(bytes) when is_binary(bytes) do
    {bytes, _} = Integer.parse(bytes)
    bytes_to_gigabytes(bytes)
  end

  def bytes_to_gigabytes(bytes) do
    gb = bytes / 1024 / 1024 / 1024
    Float.round(gb, 2)
  end

  def set_provisioning(nil), do: :ok

  def set_provisioning(app) when is_atom(app) do
    Application.load(app)

    Application.get_env(app, :nerves_provisioning)
    |> set_provisioning()
  end

  def set_provisioning(provisioning) when is_binary(provisioning) do
    path = Path.expand(provisioning)
    System.put_env("NERVES_PROVISIONING", path)
  end

  def set_provisioning(_) do
    Mix.raise("""
      Unexpected Mix config for :nerves, :firmware, :provisioning.
      Provisioning should be a relative string path to a provisioning.conf
      based off the root of the project or an atom of an application that
      provides a provisioning.conf.

      For example:

        config :nerves, :firmware,
          provisioning: "config/provisioning.conf"

      or

        config :nerves, :firmware,
          provisioning: :nerves_hub

    """)
  end

  def mix_target do
    if function_exported?(Mix, :target, 0) do
      apply(Mix, :target, [])
    else
      (System.get_env("MIX_TARGET") || "host")
      |> String.to_atom()
    end
  end

  def sanitize_path() do
    System.get_env("PATH")
    |> String.replace("::", ":")
  end

  def parse_version(vsn) do
    cond do
      # Strict semver
      Regex.match?(
        ~r/^((([0-9]+)\.([0-9]+)\.([0-9]+)(?:-([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?)(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?)$/,
        vsn
      ) ->
        Version.parse(vsn)

      # x.x
      Regex.match?(~r/^([0-9]+)\.([0-9]+)$/, vsn) ->
        Version.parse(vsn <> ".0")

      # x.x.x.x
      Regex.match?(~r/^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/, vsn) ->
        [major, minor, patch | _tail] = String.split(vsn, ".")

        Enum.join([major, minor, patch], ".")
        |> Version.parse()

      # unknown
      true ->
        {:error, "Unable to Version.parse #{inspect(vsn)}"}
    end
  end

  def use_distillery?() do
    less_than_elixir_19 = Nerves.elixir_version() |> Version.compare("1.9.0") == :lt
    less_than_elixir_19 && Code.ensure_loaded?(Mix.Tasks.Distillery.Release)
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
