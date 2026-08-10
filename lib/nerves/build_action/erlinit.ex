# SPDX-FileCopyrightText: 2019 Frank Hunleth
# SPDX-FileCopyrightText: 2019 Justin Schneck
# SPDX-FileCopyrightText: 2021 Connor Rigby
# SPDX-FileCopyrightText: 2022 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildAction.Erlinit do
  @moduledoc """
  Build action for generating `erlinit.config`

  This action merges in Nerves app environment updates to the erlinit.conf.

  Configuration:

  * `:base_erlinit_conf` - Absolute path to the base erlinit.conf
  * `:shoehorn?` - Whether the project depends on ShoeHorn
  """

  use Nerves.BuildAction

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

  @type t() :: [option()]

  @doc """
  Merge application `erlinit` options with the system configuration.
  """
  @impl Nerves.BuildAction
  def post_extract(%Nerves.BuildPlan{} = build_plan, opts) do
    base_erlinit_conf = Keyword.fetch!(opts, :base_erlinit_conf)

    write_config(build_plan, base_erlinit_conf, opts)
  end

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
    <<content::binary-size(^content_len), _>> = rest
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

  @doc false
  @spec erlinit_config_header(String.t(), keyword()) :: String.t()
  def erlinit_config_header(base_erlinit_conf, opts) do
    relative_path = String.split(base_erlinit_conf, "/deps/", parts: 2) |> List.last()
    overrides_text = if opts != [], do: "\n# with overrides from the application config", else: ""

    """
    # Generated from #{relative_path}#{overrides_text}
    """
  end

  defp write_config(build_plan, base_erlinit_conf, opts) do
    case File.read(base_erlinit_conf) do
      {:ok, system_config} ->
        user_opts = Application.get_env(:nerves, :erlinit, [])

        erlinit_config =
          system_config
          |> decode_config()
          |> maybe_use_start_boot(opts)
          |> merge_opts(user_opts)
          |> encode_config()

        overlay_path =
          opts[:output_path] || Path.join([Mix.Project.build_path(), "nerves", "erlinit_overlay"])

        config_path = Path.join(overlay_path, "etc/erlinit.config")

        _ = File.rm_rf!(overlay_path)
        File.mkdir_p!(Path.dirname(config_path))

        File.write!(config_path, [
          erlinit_config_header(base_erlinit_conf, user_opts),
          erlinit_config
        ])

        %{build_plan | rootfs_overlays: build_plan.rootfs_overlays ++ [overlay_path]}

      {:error, _reason} ->
        Mix.raise("""
        Error creating updated erlinit.config

        The source erlinit.config should have been at #{base_erlinit_conf}.
        """)
    end
  end

  defp maybe_use_start_boot(opts, action_opts) do
    # Nerves systems would hardcode `--boot shoehorn` in the base rootfs.
    # Since shoehorn isn't used by default anymore, that's misleading. erlinit
    # actually falls back to start.boot, but it's just way more clear if it
    # doesn't have to do that. Of course, if the user is still using shoehorn
    # or the new system is set to something else, then don't apply the hack.
    if action_opts[:shoehorn?] == true or opts[:boot] != "shoehorn" do
      opts
    else
      merge_opts(opts, boot: "start")
    end
  end
end
