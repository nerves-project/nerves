# SPDX-FileCopyrightText: 2026 Tom Hoenderdos
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.PrecompiledTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO
  alias Nerves.Precompiled
  alias Nerves.PrecompiledFixture, as: F
  @moduletag :tmp_dir

  @ash {:hex, :ash, "3.5.2", "i", [:mix], [], "hexpm", "ASHOUTER"}
  @jason {:hex, :jason, "1.4.5", "i", [:mix], [], "hexpm", "JOUTER"}

  setup_all do
    start_supervised!(Nerves.TestServer)
    :ok
  end

  setup %{tmp_dir: dir} do
    :inets.start(:httpc, profile: :nerves)
    old = Application.get_env(:nerves, :precompiled)

    on_exit(fn ->
      :inets.stop(:httpc, :nerves)
      Application.put_env(:nerves, :precompiled, old)
      System.delete_env("NERVES_PRECOMPILED_HOME")
    end)

    f = F.new(dir)
    Application.put_env(:nerves, :precompiled, source: F.base_url(), root: f.root_path)
    System.put_env("NERVES_PRECOMPILED_HOME", Path.join(dir, "home"))
    lib = Path.join(dir, "_build/rpi4_dev/lib")

    %{
      f: f,
      lib: lib,
      opts: [
        deps: [
          %{name: :ash, version: "3.5.2", lock_entry: @ash},
          %{name: :jason, version: "1.4.5", lock_entry: @jason}
        ],
        lock: %{ash: @ash, jason: @jason},
        system: {"nerves_system_rpi4", "1.31.0"},
        build_lib: lib,
        config_fun: fn _, _ -> :error end,
        host?: false
      ]
    }
  end

  # `MixUtils.error/1` (used for FAIL lines) writes to the named `:stderr`
  # device, not the calling process' group leader, so a plain `capture_io/1`
  # (which only captures the group leader, i.e. `:stdio`) never sees it.
  # Capture both and concatenate so assertions can match either kind of line.
  defp run_capturing(opts) do
    stderr =
      capture_io(:stderr, fn ->
        stdio = capture_io(fn -> send(self(), {:report, Precompiled.run(opts)}) end)
        send(self(), {:stdio, stdio})
      end)

    receive do
      {:stdio, stdio} -> stdio <> stderr
    end
  end

  defp good_entry(f, dep, system_version) do
    beam = "beam #{dep}"
    vsn = if dep == "ash", do: "3.5.2", else: "1.4.5"
    app = "{application, #{dep}, [{vsn, \"#{vsn}\"}]}.\n"

    %{
      "ebin" => [
        %{
          "path" => "ebin/Elixir.X.beam",
          "sha256" => F.file(f, beam),
          "size" => byte_size(beam),
          "mode" => 33188
        },
        %{
          "path" => "ebin/#{dep}.app",
          "sha256" => F.file(f, app),
          "size" => byte_size(app),
          "mode" => 33188
        }
      ],
      "priv" => [],
      "build" => %{
        "elixir" => System.version(),
        "otp" => to_string(:erlang.system_info(:otp_release)),
        "system_version" => system_version,
        "run_id" => "r",
        "image_digest" => "d",
        "deps" => %{},
        "compile_env" => [],
        "package_checksum" => elem(if(dep == "ash", do: @ash, else: @jason), 7)
      }
    }
  end

  test "disabled without a source", %{opts: opts} do
    Application.put_env(:nerves, :precompiled, [])
    assert Precompiled.run(opts) == :disabled
  end

  test "hits, misses and the summary line", %{f: f, opts: opts, lib: lib} do
    F.publish(f, %{
      "ash" => %{
        "versions" => %{"3.5.2" => %{"nerves_system_rpi4" => good_entry(f, "ash", "1.31.0")}}
      }
    })

    out = run_capturing(opts)
    assert_received {:report, {:ok, report}}
    assert report.hits == 1 and report.misses == 1 and report.fails == 0
    assert out =~ ~r/precompiled: ash 3\.5\.2\s+HIT\s+0\.0 MB/
    assert out =~ ~r/precompiled: jason 1\.4\.5\s+MISS\s+not in batch/
    assert out =~ "precompiled: 1 hit, 1 miss, 0 fail of 2 deps"
    assert File.exists?(Path.join(lib, "ash/.mix/compile.elixir_scm"))
    report_file = Path.join(lib, ".precompiled/report.json") |> File.read!() |> :json.decode()

    assert [%{"name" => "ash", "status" => "hit"}, %{"name" => "jason", "status" => "miss"}] =
             report_file["lines"]
  end

  test "a tampered manifest is a FAIL and installs nothing", %{f: f, opts: opts, lib: lib} do
    F.publish(f, %{
      "ash" => %{
        "versions" => %{"3.5.2" => %{"nerves_system_rpi4" => good_entry(f, "ash", "1.31.0")}}
      }
    })

    F.tamper_manifest(f, "ash")
    out = run_capturing(opts)
    assert_received {:report, {:ok, %{fails: 1}}}
    assert out =~ ~r/ash 3\.5\.2\s+FAIL\s+manifest hash differs from batch/
    refute File.exists?(Path.join(lib, "ash"))
  end

  test "a downloaded .app whose compile_env differs is a FAIL", %{f: f, opts: opts, lib: lib} do
    e = good_entry(f, "ash", "1.31.0")
    app = "{application, ash, [{vsn, \"3.5.2\"}, {compile_env, [{ash, [mode], {ok, fast}}]}]}.\n"

    e =
      update_in(e["ebin"], fn files ->
        Enum.map(files, fn
          %{"path" => "ebin/ash.app"} = x ->
            %{x | "sha256" => F.file(f, app), "size" => byte_size(app)}

          x ->
            x
        end)
      end)

    F.publish(f, %{"ash" => %{"versions" => %{"3.5.2" => %{"nerves_system_rpi4" => e}}}})
    out = run_capturing(opts)
    assert_received {:report, {:ok, %{fails: 1}}}
    assert out =~ ~r/ash 3\.5\.2\s+FAIL\s+downloaded \.app: compile_env differs: ash \[:mode\]/
    refute File.exists?(Path.join(lib, "ash"))
  end

  test "an invalid batch fails every candidate", %{f: f, opts: opts} do
    F.publish(f, %{}, expires: "2020-01-01T00:00:00Z")
    out = run_capturing(opts)
    assert_received {:report, {:ok, %{fails: 2, hits: 0}}}
    assert out =~ ~r/FAIL\s+batch expired/
  end

  test "a malformed manifest fails its candidate without crashing the run", %{
    f: f,
    opts: opts,
    lib: lib
  } do
    F.publish(f, %{"ash" => %{"versions" => ["oops"]}})
    out = run_capturing(opts)
    assert_received {:report, {:ok, %{fails: 1, misses: 1}}}
    assert out =~ ~r/ash 3\.5\.2\s+FAIL\s+candidate crashed: /
    assert File.exists?(Path.join(lib, ".precompiled/report.json"))
  end

  test "system_from_plan finds the v1 system package" do
    plan = %Nerves.BuildPlan{
      packages: [%{app: :nerves_system_rpi4, version: "1.31.0"}],
      actions: [{Nerves.BuildAction.NervesV1System, app: :nerves_system_rpi4}]
    }

    assert Precompiled.system_from_plan(plan) == {"nerves_system_rpi4", "1.31.0"}
    assert Precompiled.system_from_plan(%Nerves.BuildPlan{}) == nil
  end

  test "config_lookup follows compile_env semantics" do
    Application.put_env(:precompiled_test_app, :mode, fast: true)
    on_exit(fn -> Application.delete_env(:precompiled_test_app, :mode) end)
    assert Precompiled.config_lookup("precompiled_test_app", ["mode"]) == {:ok, [fast: true]}
    assert Precompiled.config_lookup("precompiled_test_app", ["mode", "fast"]) == {:ok, true}
    assert Precompiled.config_lookup("precompiled_test_app", ["mode", "slow"]) == :error
    assert Precompiled.config_lookup("precompiled_test_app", ["nothing"]) == :error
  end

  test "config_lookup never creates an atom from untrusted input" do
    never = "zz_app_#{System.unique_integer([:positive])}"
    assert Precompiled.config_lookup(never, ["mode"]) == :error
    assert_raise ArgumentError, fn -> String.to_existing_atom(never) end
  end

  test "candidates_from keeps Hex deps Mix would compile now" do
    decimal = {:hex, :decimal, "2.3.0", "i", [:mix], [], "hexpm", "DOUTER"}
    lock = %{ash: @ash, jason: @jason, decimal: decimal, gitdep: {:git, "u", "r", []}}
    dep = fn app, status, scm -> %Mix.Dep{app: app, status: status, scm: scm} end

    assert Precompiled.candidates_from([dep.(:ash, :compile, Hex.SCM)], lock) ==
             [%{name: :ash, version: "3.5.2", lock_entry: @ash}]

    assert Precompiled.candidates_from([dep.(:jason, {:noappfile, {"a", "b"}}, Hex.SCM)], lock) ==
             [%{name: :jason, version: "1.4.5", lock_entry: @jason}]

    assert Precompiled.candidates_from([dep.(:decimal, {:ok, "1.0.0"}, Hex.SCM)], lock) == []
    assert Precompiled.candidates_from([dep.(:gitdep, :compile, Mix.SCM.Git)], lock) == []
    assert Precompiled.candidates_from([dep.(:absent, :compile, Hex.SCM)], lock) == []
  end

  test "already-compiled deps are left alone", %{f: f, opts: opts, lib: lib} do
    decimal = {:hex, :decimal, "2.3.0", "i", [:mix], [], "hexpm", "DOUTER"}
    File.mkdir_p!(Path.join(lib, "decimal/ebin"))
    File.write!(Path.join(lib, "decimal/ebin/keep.beam"), "keep")

    F.publish(f, %{
      "decimal" => %{
        "versions" => %{"2.3.0" => %{"nerves_system_rpi4" => good_entry(f, "ash", "1.31.0")}}
      }
    })

    deps =
      Precompiled.candidates_from(
        [%Mix.Dep{app: :decimal, status: {:ok, "2.3.0"}, scm: Hex.SCM}],
        %{decimal: decimal}
      )

    assert deps == []
    assert run_capturing(Keyword.merge(opts, deps: deps, lock: %{decimal: decimal})) == ""
    assert_received {:report, :nothing_to_do}
    assert File.read!(Path.join(lib, "decimal/ebin/keep.beam")) == "keep"
  end

  test "host target is disabled even with a source", %{opts: opts} do
    assert Precompiled.run(Keyword.put(opts, :host?, true)) == :disabled
  end

  test "no candidates: no network, no output, no report", %{f: f, opts: opts, lib: lib} do
    F.publish(f, %{}, sequence: 3)
    opts = Keyword.put(opts, :deps, [])

    assert run_capturing(opts) == ""
    assert_received {:report, :nothing_to_do}
    refute File.exists?(Path.join(lib, ".precompiled/report.json"))
    # The batch fetch would have stored the sequence under the home dir.
    refute File.exists?(System.get_env("NERVES_PRECOMPILED_HOME"))
  end

  test "no candidates in DEBUG mode prints one line", %{opts: opts} do
    System.put_env("NERVES_PRECOMPILED_DEBUG", "1")
    on_exit(fn -> System.delete_env("NERVES_PRECOMPILED_DEBUG") end)

    out = run_capturing(Keyword.put(opts, :deps, []))
    assert_received {:report, :nothing_to_do}
    assert [_one] = String.split(out, "\n", trim: true)
    assert out =~ "precompiled: no dependencies to check"
  end

  test "an unwritable _build skips the step with one warning, never raises", %{
    f: f,
    opts: opts,
    tmp_dir: dir
  } do
    F.publish(f, %{})
    blocker = Path.join(dir, "_build_file")
    File.write!(blocker, "a file where _build/<t>/lib should be")

    out = run_capturing(Keyword.put(opts, :build_lib, blocker))
    assert_received {:report, :disabled}
    assert out =~ "precompiled: step skipped: "
  end

  test "a throw inside a candidate is that candidate's FAIL", %{f: f, opts: opts} do
    e = good_entry(f, "ash", "1.31.0")
    app = "{application, ash, [{vsn, \"3.5.2\"}, {compile_env, [{ash, [mode], {ok, fast}}]}]}.\n"

    e =
      update_in(e["ebin"], fn files ->
        Enum.map(files, fn
          %{"path" => "ebin/ash.app"} = x ->
            %{x | "sha256" => F.file(f, app), "size" => byte_size(app)}

          x ->
            x
        end)
      end)

    F.publish(f, %{"ash" => %{"versions" => %{"3.5.2" => %{"nerves_system_rpi4" => e}}}})
    out = run_capturing(Keyword.put(opts, :config_fun, fn _, _ -> throw(:boom) end))
    assert_received {:report, {:ok, %{fails: 1, misses: 1}}}
    assert out =~ ~r/ash 3\.5\.2\s+FAIL\s+candidate crashed: :boom/
  end

  defp with_beam(f, entry, beam) do
    app = "{application, ash, [{vsn, \"3.5.2\"}, {modules, ['Elixir.X']}]}.\n"

    update_in(entry["ebin"], fn files ->
      Enum.map(files, fn
        %{"path" => "ebin/ash.app"} = x ->
          %{x | "sha256" => F.file(f, app), "size" => byte_size(app)}

        %{"path" => "ebin/Elixir.X.beam"} = x ->
          %{x | "sha256" => F.file(f, beam), "size" => byte_size(beam)}
      end)
    end)
  end

  test "HITs whose beams carry no debug_info are counted once", %{f: f, opts: opts} do
    e = with_beam(f, good_entry(f, "ash", "1.31.0"), "beam bytes")
    F.publish(f, %{"ash" => %{"versions" => %{"3.5.2" => %{"nerves_system_rpi4" => e}}}})

    out = run_capturing(opts)
    assert_received {:report, {:ok, %{hits: 1}}}

    assert out =~
             "precompiled: 1 hits carry stripped beams; protocols they define are not " <>
               "consolidated and Dialyzer has no types for them"
  end

  test "HITs with debug_info print no stripped line", %{f: f, opts: opts} do
    {:module, _, beam, _} =
      defmodule WithDbgi do
        @moduledoc false
        @spec x() :: :x
        def x(), do: :x
      end

    e = with_beam(f, good_entry(f, "ash", "1.31.0"), beam)
    F.publish(f, %{"ash" => %{"versions" => %{"3.5.2" => %{"nerves_system_rpi4" => e}}}})

    out = run_capturing(opts)
    assert_received {:report, {:ok, %{hits: 1}}}
    refute out =~ "stripped"
  end

  for {app, label} <- [
        {"{application, other, [{vsn, \"3.5.2\"}]}.\n", "other 3.5.2"},
        {"{application, ash, [{vsn, \"9.9.9\"}]}.\n", "ash 9.9.9"},
        {"{application, ash, []}.\n", "ash nil"}
      ] do
    test "a downloaded .app naming #{label} is a FAIL", %{f: f, opts: opts, lib: lib} do
      app = unquote(app)

      e =
        update_in(good_entry(f, "ash", "1.31.0")["ebin"], fn files ->
          Enum.map(files, fn
            %{"path" => "ebin/ash.app"} = x ->
              %{x | "sha256" => F.file(f, app), "size" => byte_size(app)}

            x ->
              x
          end)
        end)

      F.publish(f, %{"ash" => %{"versions" => %{"3.5.2" => %{"nerves_system_rpi4" => e}}}})
      out = run_capturing(opts)
      assert_received {:report, {:ok, %{fails: 1}}}
      assert out =~ "FAIL  downloaded .app names #{unquote(label)}"
      refute File.exists?(Path.join(lib, "ash"))
    end
  end
end
