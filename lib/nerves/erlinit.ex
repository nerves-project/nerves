defmodule Nerves.Erlinit do
  @moduledoc """
  Decode and encode erlinit.config files

  This module is used to decode, merge, and encode multiple erlinit.config
  files.
  """

  @switches [
    boot: :string,
    ctty: :string,
    uniqueid_exec: :string,
    env: :keep,
    gid: :integer,
    graceful_shutdown_timeout: :integer,
    hang_on_exit: :boolean,
    reboot_on_exit: :boolean,
    hang_on_fatal: :boolean,
    limits: :string,
    mount: :keep,
    hostname_pattern: :string,
    pre_run_exec: :string,
    poweroff_on_exit: :boolean,
    poweroff_on_fatal: :boolean,
    reboot_on_fatal: :boolean,
    release_path: :string,
    run_on_exit: :string,
    alternate_exec: :string,
    print_timing: :boolean,
    uid: :integer,
    update_clock: :boolean,
    verbose: :boolean,
    warn_unused_tty: :boolean,
    working_directory: :string,
    shutdown_report: :string
  ]

  @aliases [
    b: :boot,
    c: :ctty,
    d: :uniqueid_exec,
    e: :env,
    h: :hang_on_exit,
    l: :limits,
    m: :mount,
    n: :hostname_pattern,
    r: :release_path,
    s: :alternate_exec,
    t: :print_timing,
    v: :verbose
  ]

  @type option() ::
          {:boot, Path.t()}
          | {:ctty, String.t()}
          | {:uniqueid_exec, String.t()}
          | {:env, String.t()}
          | {:gid, non_neg_integer()}
          | {:graceful_shutdown_timeout, non_neg_integer()}
          | {:hang_on_exit, boolean()}
          | {:hang_on_fatal, boolean()}
          | {:limits, String.t()}
          | {:mount, String.t()}
          | {:hostname_pattern, String.t()}
          | {:pre_run_exec, String.t()}
          | {:poweroff_on_exit, boolean()}
          | {:poweroff_on_fatal, boolean()}
          | {:reboot_on_fatal, boolean()}
          | {:release_path, Path.t()}
          | {:run_on_exit, String.t()}
          | {:alternate_exec, String.t()}
          | {:print_timing, boolean()}
          | {:uid, non_neg_integer()}
          | {:update_clock, boolean()}
          | {:verbose, boolean()}
          | {:warn_unused_tty, boolean()}
          | {:working_directory, Path.t()}
          | {:shutdown_report, Path.t()}

  @type t :: [option()]

  @doc """
  Return the path to the erlinit.config file provided by the Nerves System
  """
  @spec system_config_file(Nerves.Package.t()) :: {:ok, Path.t()} | {:error, :no_config}
  def system_config_file(%Nerves.Package{path: path}) do
    file = Path.join(path, "rootfs_overlay/etc/erlinit.config")

    case File.exists?(file) do
      true ->
        {:ok, file}

      false ->
        {:error, :no_config}
    end
  end

  # TODO: Remove this once this fix has been released in Elixir
  # https://github.com/elixir-lang/elixir/pull/11804
  @dialyzer {:nowarn_function, decode_config: 1}
  @doc """
  Decode the data from the config into a keyword list
  """
  @spec decode_config(String.t()) :: t()
  def decode_config(config) do
    argv =
      config
      |> String.split("\n")
      |> Enum.map(&String.trim_leading/1)
      |> Enum.filter(&String.starts_with?(&1, "-"))
      |> Enum.map(&trim_trailing_comments/1)
      |> Enum.map(&String.split(&1, " ", parts: 2))
      |> List.flatten()
      |> Enum.map(&String.trim/1)
      |> Enum.map(&trim_quoted_string/1)

    # `allow_nonexistent_atoms: true` allows unknown erlinit options to pass through.
    {opts, _, _} =
      OptionParser.parse(argv,
        switches: @switches,
        aliases: @aliases,
        allow_nonexistent_atoms: true
      )

    opts
  end

  defp trim_quoted_string(<<?", rest::binary>>) do
    content_len = byte_size(rest) - 1
    <<content::binary-size(content_len), _>> = rest
    content
  end

  defp trim_quoted_string(s), do: s

  defp trim_trailing_comments(s) do
    # Trim everything after a #. This is flawed since quoted '#'s should work,
    # but I don't think that that exists in anything that erlinit can do...
    String.split(s, "#", parts: 2) |> hd()
  end

  @doc """
  Merge keyword options
  """
  @spec merge_opts(t(), t()) :: t()
  def merge_opts(old, new) do
    Enum.reduce(new, old, fn
      {k, nil}, acc ->
        Keyword.delete(acc, k)

      {k, v}, acc ->
        case Keyword.get(@switches, k) do
          :keep ->
            [{k, v} | acc]

          _ ->
            Keyword.put(acc, k, v)
        end
    end)
  end

  @doc """
  Encode the keyword list options into an erlinit.config file format
  """
  @spec encode_config(t()) :: String.t()
  def encode_config(config) do
    config
    |> Enum.map(&encode_line/1)
    |> IO.iodata_to_binary()
  end

  defp encode_line({k, v}) do
    Keyword.get(@switches, k)
    |> encode_kv(k, v)
  end

  defp encode_kv(:boolean, _k, false), do: []
  defp encode_kv(:boolean, k, true), do: [encode_key(k), "\n"]

  defp encode_kv(type, k, v) do
    [encode_key(k), " ", encode_value(type, v), "\n"]
  end

  defp encode_value(:string, v) do
    if String.contains?(v, " ") do
      ["\"", v, "\""]
    else
      v
    end
  end

  defp encode_value(_, v), do: to_string(v)

  defp encode_key(key), do: "--" <> String.replace(to_string(key), "_", "-")
end
