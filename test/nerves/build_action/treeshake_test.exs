# SPDX-FileCopyrightText: 2026 Nerves Project Authors
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildAction.TreeshakeTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Nerves.BuildAction.Treeshake
  alias Nerves.BuildPlan

  setup do
    previous = Application.fetch_env(:nerves, :treeshake)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:nerves, :treeshake, value)
        :error -> Application.delete_env(:nerves, :treeshake)
      end
    end)

    :ok
  end

  test "can be disabled without changing release stripping" do
    Application.put_env(:nerves, :treeshake, false)
    release = %Mix.Release{options: [strip_beams: [keep: ["Docs"]]]}
    assert Treeshake.pre_assemble_steps(%BuildPlan{}, release, []) == release
    assert Treeshake.post_assemble_steps(%BuildPlan{}, release, []) == release
  end

  test "disabled by default without changing release stripping" do
    Application.delete_env(:nerves, :treeshake)
    release = %Mix.Release{options: [strip_beams: [keep: ["Docs"]]]}
    assert Treeshake.pre_assemble_steps(%BuildPlan{}, release, []) == release
    assert Treeshake.post_assemble_steps(%BuildPlan{}, release, []) == release
  end

  @tag :tmp_dir
  test "when enabled, keeps configured modules and updates only release files", %{
    tmp_dir: tmp_dir
  } do
    {release, source} = fixture(tmp_dir, true)
    Application.put_env(:nerves, :treeshake, true)
    original = File.read!(Path.join(source, "nerves_shake_dependency.beam"))

    assembled = Treeshake.pre_assemble_steps(%BuildPlan{}, release, [])
    assert assembled.options[:strip_beams] == false
    result = Treeshake.post_assemble_steps(%BuildPlan{}, assembled, [])
    assert result.options == release.options
    ebin = Path.join(release.path, "lib/shake-1/ebin")

    assert exports(ebin, :nerves_shake_dependency) == [used: 0]
    assert exports(ebin, :nerves_shake_configured) == [dynamic: 0]
    refute File.exists?(Path.join(ebin, "nerves_shake_dead.beam"))
    assert File.read!(Path.join(source, "nerves_shake_dependency.beam")) == original
    refute File.exists?(Path.join(release.path, ".treeshake"))

    assert {:ok, [{:application, :shake, attributes}]} =
             :file.consult(String.to_charlist(Path.join(ebin, "shake.app")))

    refute :nerves_shake_dead in attributes[:modules]
    assert :nerves_shake_configured in attributes[:modules]

    assert {:ok, {_, [{~c"Dbgi", :missing_chunk}]}} =
             :beam_lib.chunks(
               File.read!(Path.join(ebin, "nerves_shake_dependency.beam")),
               [
                 ~c"Dbgi"
               ],
               [:allow_missing_chunks]
             )

    assert {:ok, {_, [exports: exports]}} =
             :beam_lib.chunks(
               String.to_charlist(
                 Path.join(release.version_path, "consolidated/nerves_shake_dependency.beam")
               ),
               [:exports]
             )

    assert {:used, 0} in exports
    refute {:unused, 0} in exports
  end

  @tag :tmp_dir
  test "keeps function captures in application environment and sys.config with their dependencies",
       %{tmp_dir: tmp_dir} do
    for location <- [:app_env, :sys_config] do
      {release, _source} = fixture(Path.join(tmp_dir, to_string(location)), true)
      Application.put_env(:nerves, :treeshake, true)
      ebin = Path.join(release.path, "lib/shake-1/ebin")
      config = [callback: %{nested: [Function.capture(NervesShakeRuntime, :configured, 0)]}]

      {path, term, lookup} =
        case location do
          :app_env ->
            path = Path.join(ebin, "shake.app")
            {:ok, [{:application, :shake, attributes}]} = :file.consult(String.to_charlist(path))

            {path, {:application, :shake, Keyword.put(attributes, :env, config)},
             "elem(term, 2) |> Keyword.fetch!(:env)"}

          :sys_config ->
            {Path.join(release.version_path, "sys.config"), [shake: config],
             "Keyword.fetch!(term, :shake)"}
        end

      File.write!(path, :io_lib.format(~c"~tp.~n", [term]))
      assembled = Treeshake.pre_assemble_steps(%BuildPlan{}, release, [])
      Treeshake.post_assemble_steps(%BuildPlan{}, assembled, [])

      assert exports(ebin, NervesShakeRuntime) == [configured: 0]
      assert exports(ebin, :nerves_shake_dependency) == [unused: 0, used: 0]
      refute File.exists?(Path.join(ebin, "nerves_shake_dead.beam"))

      eval = """
      {:ok, [term]} = :file.consult(String.to_charlist(#{inspect(path)}))
      config = #{lookup}
      %{nested: [callback]} = Keyword.fetch!(config, :callback)
      :unused = callback.()
      """

      assert {_, 0} =
               System.cmd("elixir", ["-pa", ebin, "-e", eval], stderr_to_stdout: true)
    end
  end

  @tag :tmp_dir
  test "debug lists removed modules and functions only when enabled", %{tmp_dir: tmp_dir} do
    for debug <- [false, true] do
      {release, _source} = fixture(Path.join(tmp_dir, to_string(debug)), true)
      options = if debug, do: [debug: true], else: []
      Application.put_env(:nerves, :treeshake, options)

      output =
        capture_io(fn ->
          assembled = Treeshake.pre_assemble_steps(%BuildPlan{}, release, [])
          Treeshake.post_assemble_steps(%BuildPlan{}, assembled, [])
        end)

      assert output =~ ~r/Removed \d+ modules and \d+ functions/

      if debug do
        assert output =~ "Removed module: :nerves_shake_dead"
        assert output =~ "Removed function: :nerves_shake_dependency.unused/0"
        refute output =~ "Removed function: :nerves_shake_dependency.used/0"
      else
        refute output =~ "Removed module:"
        refute output =~ "Removed function:"
      end
    end
  end

  @tag :tmp_dir
  test "keep rules and application preservation follow dependencies with stripping disabled", %{
    tmp_dir: tmp_dir
  } do
    {release, _source} = fixture(tmp_dir, false)

    Application.put_env(:nerves, :treeshake,
      keep_applications: [:shake],
      keep: [mod: :nerves_shake_dead]
    )

    result =
      %BuildPlan{}
      |> Treeshake.pre_assemble_steps(release, [])
      |> then(&Treeshake.post_assemble_steps(%BuildPlan{}, &1, []))

    assert result.options[:strip_beams] == false
    ebin = Path.join(release.path, "lib/shake-1/ebin")
    assert exports(ebin, :nerves_shake_dependency) == [unused: 0, used: 0]
    assert exports(ebin, :nerves_shake_dead) == [unused: 0]

    assert {:ok, {_, [debug_info: {:debug_info_v1, _, _}]}} =
             :beam_lib.chunks(
               String.to_charlist(Path.join(ebin, "nerves_shake_dependency.beam")),
               [:debug_info]
             )
  end

  @tag :tmp_dir
  test "preserves documentation chunks requested by the release", %{tmp_dir: tmp_dir} do
    {release, _source} = fixture(tmp_dir, keep: ["Docs"])
    Application.put_env(:nerves, :treeshake, true)
    path = Path.join(release.path, "lib/shake-1/ebin/nerves_shake_dependency.beam")
    {:ok, module, chunks} = :beam_lib.all_chunks(File.read!(path))
    docs = :erlang.term_to_binary({:docs_v1, 0, :erlang, "text/markdown", :none, %{}, []})
    {:ok, binary} = :beam_lib.build_module(chunks ++ [{~c"Docs", docs}])
    File.write!(path, binary)
    File.write!(Path.join(release.version_path, "consolidated/#{module}.beam"), binary)

    assembled = Treeshake.pre_assemble_steps(%BuildPlan{}, release, [])
    Treeshake.post_assemble_steps(%BuildPlan{}, assembled, [])
    assert {:ok, {^module, [{~c"Docs", ^docs}]}} = :beam_lib.chunks(File.read!(path), [~c"Docs"])
  end

  @tag :tmp_dir
  test "keeps runtime configuration modules and their dependencies without evaluating the script",
       %{
         tmp_dir: tmp_dir
       } do
    {release, _source} = fixture(tmp_dir, true)
    Application.put_env(:nerves, :treeshake, keep_applications: [])
    marker = Path.join(tmp_dir, "runtime-config-evaluated")

    File.write!(
      Path.join(release.version_path, "runtime.exs"),
      """
      File.write!(#{inspect(marker)}, "must not run at build time")
      NervesShakeRuntime.configured()
      :nerves_shake_runtime.configured()
      """
    )

    assembled = Treeshake.pre_assemble_steps(%BuildPlan{}, release, [])
    Treeshake.post_assemble_steps(%BuildPlan{}, assembled, [])
    ebin = Path.join(release.path, "lib/shake-1/ebin")

    assert exports(ebin, NervesShakeRuntime) == [configured: 0]
    assert exports(ebin, :nerves_shake_runtime) == [configured: 0]
    assert exports(ebin, :nerves_shake_dependency) == [unused: 0, used: 0]
    refute File.exists?(marker)
    refute File.exists?(Path.join(ebin, "nerves_shake_dead.beam"))
  end

  @tag :tmp_dir
  test "keeps console script modules from user and generated overlays without evaluating them", %{
    tmp_dir: tmp_dir
  } do
    {release, _source} = fixture(tmp_dir, true)
    Application.put_env(:nerves, :treeshake, keep_applications: [])
    user_overlay = Path.join(tmp_dir, "user_overlay")
    generated_overlay = Path.join(tmp_dir, "generated_overlay")
    marker = Path.join(tmp_dir, "console-script-evaluated")
    File.mkdir_p!(Path.join(user_overlay, "etc"))
    File.mkdir_p!(generated_overlay)

    File.write!(
      Path.join(user_overlay, "etc/iex.exs"),
      """
      File.write!(#{inspect(marker)}, "must not run at build time")
      NervesShakeRuntime.configured()
      """
    )

    File.write!(Path.join(generated_overlay, ".iex.exs"), ":nerves_shake_runtime.configured()")

    build_plan = %BuildPlan{
      rootfs_overlays: [generated_overlay],
      config: %{rootfs_overlay: [user_overlay]}
    }

    assembled = Treeshake.pre_assemble_steps(build_plan, release, [])
    Treeshake.post_assemble_steps(build_plan, assembled, [])
    ebin = Path.join(release.path, "lib/shake-1/ebin")

    assert exports(ebin, NervesShakeRuntime) == [configured: 0]
    assert exports(ebin, :nerves_shake_runtime) == [configured: 0]
    assert exports(ebin, :nerves_shake_dependency) == [unused: 0, used: 0]
    refute File.exists?(marker)
    refute File.exists?(Path.join(ebin, "nerves_shake_dead.beam"))

    assert {_, 0} =
             System.cmd(
               "elixir",
               ["-pa", ebin, "-e", ":unused = NervesShakeRuntime.configured()"],
               stderr_to_stdout: true
             )
  end

  test "rejects options that would bypass release integration" do
    Application.put_env(:nerves, :treeshake, dry_run: true)

    assert_raise Mix.Error, ~r/Unknown Nerves treeshake options/, fn ->
      Treeshake.pre_assemble_steps(%BuildPlan{}, %Mix.Release{}, [])
    end
  end

  @tag :tmp_dir
  test "HTTP response parser and body continuations survive fragmented input", %{tmp_dir: tmp_dir} do
    {release, _source} = fixture(tmp_dir, true)
    Application.put_env(:nerves, :treeshake, true)
    ebin = Path.join(release.path, "lib/shake-1/ebin")

    for module <- [:httpc_response, :http_response] do
      File.cp!(:code.which(module), Path.join(ebin, "#{module}.beam"))
    end

    assembled = Treeshake.pre_assemble_steps(%BuildPlan{}, release, [])
    Treeshake.post_assemble_steps(%BuildPlan{}, assembled, [])
    assert {:parse, 1} in exports(ebin, :httpc_response)
    assert {:whole_body, 1} in exports(ebin, :httpc_response)

    eval = """
    Response = <<"HTTP/1.1 200 OK\\r\\nContent-Length: 2\\r\\n\\r\\n">>,
    {ok, {"HTTP/1.1", 200, "OK", _, <<>>}} =
      lists:foldl(fun(Byte, {Module, Function, Args}) ->
        Module:Function([<<Byte>> | Args])
      end, {httpc_response, parse, [65536, false]}, binary_to_list(Response)),
    {Module, Function, Args} = httpc_response:whole_body(<<"o">>, 2),
    {ok, <<"ok">>} = Module:Function([<<"k">> | Args]),
    halt(0).
    """

    assert {_, 0} =
             System.cmd("erl", ["-noshell", "-pa", ebin, "-eval", eval], stderr_to_stdout: true)
  end

  @tag :tmp_dir
  test "streamed HTTP chunk continuations still execute", %{tmp_dir: tmp_dir} do
    {release, _source} = fixture(tmp_dir, true)
    Application.put_env(:nerves, :treeshake, keep_applications: [])
    ebin = Path.join(release.path, "lib/shake-1/ebin")
    File.cp!(:code.which(:http_chunk), Path.join(ebin, "http_chunk.beam"))

    assembled = Treeshake.pre_assemble_steps(%BuildPlan{}, release, [])
    Treeshake.post_assemble_steps(%BuildPlan{}, assembled, [])
    assert {:decode_trailer, 1} in exports(ebin, :http_chunk)

    eval = """
    {ok, {_, <<"abc">>}} =
      http_chunk:decode(<<"3\\r\\nabc\\r\\n0;ignored\\r\\n\\r\\n">>, 1000, 1000),
    halt(0).
    """

    assert {_, 0} =
             System.cmd("erl", ["-noshell", "-pa", ebin, "-eval", eval], stderr_to_stdout: true)
  end

  @tag :tmp_dir
  test "referenced logger handlers without a behaviour declaration can still be registered", %{
    tmp_dir: tmp_dir
  } do
    {release, source} = fixture(tmp_dir, true)
    Application.put_env(:nerves, :treeshake, keep_applications: [])
    ebin = Path.join(release.path, "lib/shake-1/ebin")

    for {module, body} <- [
          {:nerves_shake_app,
           """
           -export([start/2, stop/1]).
           start(_, _) -> logger:add_handler(nerves_shake_test, nerves_shake_log_handler, \#{}).
           stop(_) -> ok.
           """},
          {:nerves_shake_log_handler,
           """
           -export([adding_handler/1, log/2]).
           adding_handler(Config) -> {ok, Config}.
           log(_, _) -> ok.
           """}
        ] do
      path = Path.join(source, "#{module}.erl")
      File.write!(path, "-module(#{module}).\n" <> body)

      {:ok, ^module} =
        :compile.file(String.to_charlist(path), [:debug_info, outdir: String.to_charlist(ebin)])
    end

    assembled = Treeshake.pre_assemble_steps(%BuildPlan{}, release, [])
    Treeshake.post_assemble_steps(%BuildPlan{}, assembled, [])
    assert exports(ebin, :nerves_shake_log_handler) == [adding_handler: 1, log: 2]

    eval =
      "ok = nerves_shake_app:start(normal, []), ok = logger:remove_handler(nerves_shake_test), halt(0)."

    assert {_, 0} =
             System.cmd("erl", ["-noshell", "-pa", ebin, "-eval", eval], stderr_to_stdout: true)
  end

  @tag :tmp_dir
  test "custom kept applications retain the base tracing and SASL preservation", %{
    tmp_dir: tmp_dir
  } do
    {release, _source} = fixture(tmp_dir, true)
    Application.put_env(:nerves, :treeshake, keep_applications: [:shake])

    paths =
      for app <- [:runtime_tools, :sasl] do
        ebin = Path.join(release.path, "lib/#{app}/ebin")
        File.mkdir_p!(Path.dirname(ebin))
        [source_ebin] = Path.wildcard(Path.join([:code.root_dir(), "lib", "#{app}-*", "ebin"]))
        File.cp_r!(source_ebin, ebin)
        {source_ebin, ebin}
      end

    assembled = Treeshake.pre_assemble_steps(%BuildPlan{}, release, [])
    Treeshake.post_assemble_steps(%BuildPlan{}, assembled, [])

    assert exports(Path.join(release.path, "lib/shake-1/ebin"), :nerves_shake_dead) == [unused: 0]

    eval =
      :io_lib.format(
        ~c"""
        lists:foreach(fun code:del_path/1, ~p),
        Results = [application:ensure_all_started(App) || App <- [runtime_tools, sasl]],
        case lists:all(fun({ok, _}) -> true; (_) -> false end, Results) of
          true -> halt(0);
          false -> io:format("~~p~~n", [Results]), halt(1)
        end.
        """,
        [Enum.map(paths, fn {source, _} -> String.to_charlist(source) end)]
      )
      |> IO.iodata_to_binary()

    args = ["-noshell", "-pa"] ++ Enum.map(paths, &elem(&1, 1)) ++ ["-eval", eval]

    assert {_, 0} =
             System.cmd("erl", args, stderr_to_stdout: true)
  end

  @tag :tmp_dir
  test "SSH still listens after tree-shaking with the default options", %{tmp_dir: tmp_dir} do
    {release, source} = fixture(tmp_dir, true)
    Application.put_env(:nerves, :treeshake, true)
    ebin = Path.join(release.path, "lib/ssh/ebin")
    File.mkdir_p!(Path.dirname(ebin))
    [source_ebin] = Path.wildcard(Path.join([:code.root_dir(), "lib", "ssh-*", "ebin"]))
    File.cp_r!(source_ebin, ebin)

    assembled = Treeshake.pre_assemble_steps(%BuildPlan{}, release, [])
    Treeshake.post_assemble_steps(%BuildPlan{}, assembled, [])

    path = Path.join(source, "nerves_shake_keys.erl")

    File.write!(path, """
    -module(nerves_shake_keys).
    -export([host_key/2, is_auth_key/3]).
    host_key(Algorithm, _)
      when Algorithm == 'ssh-rsa';
           Algorithm == 'rsa-sha2-256';
           Algorithm == 'rsa-sha2-512' -> {ok, persistent_term:get(?MODULE)};
    host_key(_, _) -> {error, unsupported}.
    is_auth_key(_, _, _) -> false.
    """)

    {:ok, :nerves_shake_keys} =
      :compile.file(String.to_charlist(path), [:debug_info, outdir: String.to_charlist(ebin)])

    eval =
      :io_lib.format(
        ~c"""
        code:del_path(~p),
        {ok, _} = application:ensure_all_started(ssh),
        persistent_term:put(nerves_shake_keys, public_key:generate_key({rsa, 2048, 65537})),
        case catch ssh:daemon({127, 0, 0, 1}, 0, [
          {key_cb, {nerves_shake_keys, []}},
          {auth_methods, "publickey"},
          {preferred_algorithms, [{public_key, ['rsa-sha2-256']}]}]) of
          {ok, Daemon} -> ssh:stop_daemon(Daemon), halt(0);
          Error -> io:format("~~p~~n", [Error]), halt(1)
        end.
        """,
        [String.to_charlist(source_ebin)]
      )
      |> IO.iodata_to_binary()

    assert {_, 0} =
             System.cmd("erl", ["-noshell", "-pa", ebin, "-eval", eval], stderr_to_stdout: true)
  end

  @tag :tmp_dir
  test "runtime recovery callbacks survive dynamic Task and heart invocation", %{tmp_dir: tmp_dir} do
    {release, source} = fixture(tmp_dir, true)
    Application.put_env(:nerves, :treeshake, true)
    ebin = Path.join(release.path, "lib/nerves_runtime/ebin")
    File.mkdir_p!(ebin)
    path = Path.join(source, "nerves_shake_guard.erl")

    File.write!(path, """
    -module(nerves_shake_guard).
    -export([start/2, stop/1, run/1, heart_check/0]).
    start(_, _) -> 'Elixir.Task':start_link(?MODULE, run, [self()]).
    stop(_) -> ok.
    run(Parent) -> Parent ! {ready, {?MODULE, heart_check}}.
    heart_check() -> ok.
    """)

    {:ok, :nerves_shake_guard} =
      :compile.file(String.to_charlist(path), [:debug_info, outdir: String.to_charlist(ebin)])

    app =
      {:application, :nerves_runtime,
       vsn: ~c"1", modules: [:nerves_shake_guard], mod: {:nerves_shake_guard, []}}

    File.write!(Path.join(ebin, "nerves_runtime.app"), :io_lib.format(~c"~tp.~n", [app]))

    assembled = Treeshake.pre_assemble_steps(%BuildPlan{}, release, [])
    Treeshake.post_assemble_steps(%BuildPlan{}, assembled, [])

    eval = """
    {:ok, _} = :nerves_shake_guard.start(:normal, [])
    receive do
      {:ready, {module, function}} -> :ok = apply(module, function, [])
    after
      5000 -> raise "Recovery task did not start"
    end
    """

    assert {_, 0} =
             System.cmd("elixir", ["-pa", ebin, "-e", eval], stderr_to_stdout: true)
  end

  defp fixture(tmp_dir, strip_beams) do
    source = Path.join(tmp_dir, "source")
    release_path = Path.join(tmp_dir, "release")
    version_path = Path.join(release_path, "releases/1")
    ebin = Path.join(release_path, "lib/shake-1/ebin")
    File.mkdir_p!(source)
    File.mkdir_p!(Path.join(version_path, "consolidated"))

    modules = [
      {:nerves_shake_app,
       "-export([start/2, stop/1]). start(_, _) -> nerves_shake_dependency:used(). stop(_) -> ok."},
      {:nerves_shake_dependency,
       "-export([used/0, unused/0]). used() -> ok. unused() -> unused."},
      {:nerves_shake_configured, "-export([dynamic/0]). dynamic() -> ok."},
      {NervesShakeRuntime,
       "-export([configured/0]). configured() -> nerves_shake_dependency:unused()."},
      {:nerves_shake_runtime, "-export([configured/0]). configured() -> ok."},
      {:nerves_shake_dead, "-export([unused/0]). unused() -> unused."}
    ]

    for {module, body} <- modules do
      path = Path.join(source, "#{module}.erl")
      File.write!(path, [:io_lib.format(~c"-module(~p).~n", [module]), body])

      {:ok, ^module} =
        :compile.file(String.to_charlist(path), [:debug_info, outdir: String.to_charlist(source)])
    end

    app =
      {:application, :shake,
       vsn: ~c"1", modules: Enum.map(modules, &elem(&1, 0)), mod: {:nerves_shake_app, []}}

    File.write!(Path.join(source, "shake.app"), :io_lib.format(~c"~tp.~n", [app]))
    File.mkdir_p!(Path.dirname(ebin))
    File.cp_r!(source, ebin)

    File.cp!(
      Path.join(ebin, "nerves_shake_dependency.beam"),
      Path.join(version_path, "consolidated/nerves_shake_dependency.beam")
    )

    File.write!(
      Path.join(version_path, "sys.config"),
      "[{shake, [{callback, \#{nested => {nerves_shake_configured, dynamic, []}}}]}]."
    )

    {%Mix.Release{
       path: release_path,
       version_path: version_path,
       options: [strip_beams: strip_beams]
     }, source}
  end

  defp exports(ebin, module) do
    path = String.to_charlist(Path.join(ebin, "#{module}.beam"))
    {:ok, {^module, [exports: exports]}} = :beam_lib.chunks(path, [:exports])
    Enum.reject(exports, fn {name, _} -> name == :module_info end)
  end
end
