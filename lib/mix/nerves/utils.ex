defmodule Mix.Nerves.Utils do
  alias Nerves.Utils.WSL

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

  def debug_info(msg) do
    if System.get_env("NERVES_DEBUG") == "1" do
      Mix.shell().info(msg)
    end
  end

  @spec check_nerves_system_is_set!() :: String.t()
  def check_nerves_system_is_set! do
    var_name = "NERVES_SYSTEM"
    System.get_env(var_name) || raise_env_var_missing(var_name)
  end

  @spec check_nerves_toolchain_is_set! :: String.t()
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
    _ = Application.load(app)

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

  @spec mix_target() :: atom()
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

  @spec parse_version(String.t()) :: {:error, String.t()} | {:ok, Version.t()}
  def parse_version(vsn) do
    cond do
      # Strict semver
      Regex.match?(
        ~r/^((([0-9]+)\.([0-9]+)\.([0-9]+)(?:-([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?)(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?)$/,
        vsn
      ) ->
        {:ok, Version.parse!(vsn)}

      # x.x
      Regex.match?(~r/^([0-9]+)\.([0-9]+)$/, vsn) ->
        {:ok, Version.parse!(vsn <> ".0")}

      # x.x.x.x
      Regex.match?(~r/^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/, vsn) ->
        [major, minor, patch | _tail] = String.split(vsn, ".")

        vsn = Enum.join([major, minor, patch], ".")
        {:ok, Version.parse!(vsn)}

      # unknown
      true ->
        {:error, "Unable to Version.parse #{inspect(vsn)}"}
    end
  end

  def use_distillery?() do
    less_than_elixir_19 = Nerves.elixir_version() |> Version.compare("1.9.0") == :lt
    less_than_elixir_19 && Code.ensure_loaded?(Mix.Tasks.Distillery.Release)
  end

  @spec raise_env_var_missing(String.t()) :: no_return()
  defp raise_env_var_missing(name) do
    Mix.raise("""
    Environment variable $#{name} is not set.

    This variable is usually set for you by Nerves when you specify the
    $MIX_TARGET. It is unusual to need to specify it yourself.

    Some things to check:

    1. In your `mix.exs`, is the value that you have in $MIX_TARGET in the
      `@all_targets` list? If you're not using `@all_targets`, then the
      $MIX_TARGET should appear in the `:targets` option for `:nerves_runtime`
      and other packages that run on the target.

    2. Do you have a dependency on a Nerves system for the target? For example,
      `{:nerves_system_rpi0, "~> 1.8", runtime: false, targets: :rpi0}`

    3. Is there a typo? For example, is $MIX_TARGET set to `rpi1` when it should
      be `rpi`.

    4. Is there a typo in the package name of the system? For example, if you
      have a custom system, `:nerves_system_my_board`, does the spelling of the
      system in the dependency in your `mix.exs` match the spelling in your
      system project's `mix.exs`?

    For build examples in the Nerves documentation, please see
    https://hexdocs.pm/nerves/getting-started.html#create-the-firmware-bundle
    """)
  end
end
