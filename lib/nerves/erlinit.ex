defmodule Nerves.Erlinit do
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
    working_directory: :string
  ]

  @aliases [
    b: :boot,
    c: :ctty,
    d: :uniqueid_exec,
    e: :env,
    h: :hang_on_exit,
    m: :mount,
    n: :hostname_pattern,
    r: :release_path,
    s: :alternate_exec,
    t: :print_timing,
    v: :verbose
  ]

  def system_config_file(%Nerves.Package{path: path}) do
    file = Path.join(path, "rootfs_overlay/etc/erlinit.config")

    case File.exists?(file) do
      true ->
        {:ok, file}

      false ->
        {:error, :no_config}
    end
  end

  def decode_config(config) do
    argv =
      config
      |> String.split("\n")
      |> Enum.filter(&String.starts_with?(&1, "-"))
      |> Enum.map(&String.split(&1, " ", parts: 2))
      |> List.flatten()

    {opts, _, _} = OptionParser.parse(argv, switches: @switches, aliases: @aliases)
    opts
  end

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

  def encode_config(config) do
    config
    |> Enum.map(&encode_line/1)
    |> Enum.join("\n")
  end

  def encode_line({k, v}) do
    Keyword.get(@switches, k)
    |> encode_type(k, v)
  end

  def encode_type(:boolean, _k, false), do: ""
  def encode_type(:boolean, k, true), do: encode_key(k)
  def encode_type(_, k, v), do: "#{encode_key(k)} #{v}"

  def encode_key(key), do: "--" <> String.replace(to_string(key), "_", "-")
end
