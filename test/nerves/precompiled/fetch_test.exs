# SPDX-FileCopyrightText: 2026 Tom Hoenderdos
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Precompiled.FetchTest do
  use ExUnit.Case, async: false
  alias Nerves.Precompiled.Fetch
  alias Nerves.PrecompiledFixture, as: F

  @moduletag :tmp_dir
  @lock_entry {:hex, :ash, "3.5.2", "i", [:mix], [], "hexpm", "OUTER"}

  setup_all do
    start_supervised!(Nerves.TestServer)
    :ok
  end

  setup %{tmp_dir: dir} do
    :inets.start(:httpc, profile: :nerves)
    on_exit(fn -> :inets.stop(:httpc, :nerves) end)
    f = F.new(dir)

    config = %{
      source: F.base_url(),
      except: [],
      root_path: f.root_path,
      home: Path.join(dir, "home")
    }

    %{f: f, config: config, build_lib: Path.join(dir, "_build/rpi4_dev/lib")}
  end

  defp entry(files), do: %{"ebin" => files, "priv" => [], "build" => %{}}

  defp file_entry(sha, size, path \\ "ebin/Elixir.Ash.beam", mode \\ 33188),
    do: %{"path" => path, "sha256" => sha, "size" => size, "mode" => mode}

  # The validator requires ebin/<dep>.app; most entries need one alongside the file under test.
  defp with_app(f, files) do
    app = "{application, ash, []}.\n"
    files ++ [file_entry(F.file(f, app), byte_size(app), "ebin/ash.app")]
  end

  test "get_body caps size and refuses cross-host redirects", %{config: config} do
    port = Nerves.TestServer.port()

    assert {:error, "redirect to another host refused"} =
             Fetch.get_body(config.source <> "/redirect/batch.json")

    assert {:error, "response larger than 10 bytes"} =
             Fetch.get_body("http://127.0.0.1:#{port}/binary", max_bytes: 10)

    assert {:error, "Status 404 Not Found"} =
             Fetch.get_body(config.source <> "/manifests/nope.json")
  end

  test "get_body streams the body and assembles it correctly under the cap" do
    port = Nerves.TestServer.port()

    assert {:ok, body} = Fetch.get_body("http://127.0.0.1:#{port}/binary", max_bytes: 2048)
    assert byte_size(body) == 1024
    assert body == :binary.copy(<<0xDE, 0xAD, 0xBE, 0xEF>>, 256)
  end

  test "manifest: miss on 404, fail on hash mismatch, ok when it matches", %{f: f, config: config} do
    F.publish(f, %{"ash" => %{"versions" => %{"3.5.2" => %{}}}})

    sha =
      F.get(:batch)
      |> then(fn env ->
        env["payload"] |> Base.url_decode64!(padding: false) |> :json.decode()
      end)
      |> get_in(["manifests", "ash"])

    assert {:ok, %{"versions" => _}} = Fetch.manifest(config, "ash", sha)
    assert {:miss, "no manifest"} = Fetch.manifest(config, "nope", sha)
    F.tamper_manifest(f, "ash")
    assert {:fail, "manifest hash differs from batch"} = Fetch.manifest(config, "ash", sha)
  end

  test "manifest: a manifest larger than the default 8 MB body cap still fetches", %{
    f: f,
    config: config
  } do
    F.publish(f, %{
      "ash" => %{
        "versions" => %{"3.5.2" => %{"pad" => String.duplicate("a", 9 * 1024 * 1024)}}
      }
    })

    sha =
      F.get(:batch)
      |> then(fn env ->
        env["payload"] |> Base.url_decode64!(padding: false) |> :json.decode()
      end)
      |> get_in(["manifests", "ash"])

    assert {:ok, %{"versions" => _}} = Fetch.manifest(config, "ash", sha)
  end

  test "install downloads, verifies, writes the marker and renames atomically", %{
    f: f,
    config: config,
    build_lib: lib
  } do
    beam = "beam bytes"
    app = "{application, ash, [{vsn, \"3.5.2\"}]}.\n"
    s1 = F.file(f, beam)
    s2 = F.file(f, app)
    e = entry([file_entry(s1, byte_size(beam)), file_entry(s2, byte_size(app), "ebin/ash.app")])
    File.mkdir_p!(Path.join(lib, "ash/ebin"))
    File.write!(Path.join(lib, "ash/ebin/stale.beam"), "old")

    assert {:ok, %{files: 2, cached: 0}} = Fetch.install(config, :ash, e, @lock_entry, lib)
    assert File.read!(Path.join(lib, "ash/ebin/Elixir.Ash.beam")) == beam
    refute File.exists?(Path.join(lib, "ash/ebin/stale.beam"))
    refute File.exists?(Path.join(lib, ".precompiled/ash"))

    # Mix itself must read the marker as "compiled by this Elixir/OTP with Hex".
    vsn = {System.version(), :erlang.system_info(:otp_release)}

    if Version.match?(System.version(), ">= 1.20.0") do
      assert {:ok, ^vsn, Hex.SCM, @lock_entry} =
               Mix.Dep.ElixirSCM.read(Path.join(lib, "ash/.mix"))
    else
      assert {:ok, ^vsn, Hex.SCM} = Mix.Dep.ElixirSCM.read(Path.join(lib, "ash/.mix"))
    end

    assert File.exists?(Path.join(config.home, "files/#{s1}"))

    # second install hits the cache
    File.rm_rf!(Path.join(lib, "ash"))
    assert {:ok, %{files: 2, cached: 2}} = Fetch.install(config, :ash, e, @lock_entry, lib)
  end

  test "a wrong sha or size fails and leaves _build untouched", %{
    f: f,
    config: config,
    build_lib: lib
  } do
    s = F.file(f, "real")
    e = entry(with_app(f, [file_entry(String.duplicate("0", 64), 4)]))
    assert {:fail, "file not available: " <> _} = Fetch.install(config, :ash, e, @lock_entry, lib)
    e = entry(with_app(f, [file_entry(s, 99)]))

    assert {:fail, "size mismatch (ebin/Elixir.Ash.beam)"} =
             Fetch.install(config, :ash, e, @lock_entry, lib)

    refute File.exists?(Path.join(lib, "ash"))
  end

  test "a cached file that no longer matches its sha is re-downloaded", %{
    f: f,
    config: config,
    build_lib: lib
  } do
    s = F.file(f, "good")
    File.mkdir_p!(Path.join(config.home, "files"))
    File.write!(Path.join(config.home, "files/#{s}"), "")

    assert {:ok, %{cached: 0}} =
             Fetch.install(config, :ash, entry(with_app(f, [file_entry(s, 4)])), @lock_entry, lib)
  end

  test "unsafe path or mode rejects the dependency", %{f: f, config: config, build_lib: lib} do
    s = F.file(f, "x")

    for {path, mode} <- [
          {"../x.beam", 33188},
          {"/ebin/x.beam", 33188},
          {"lib/x.beam", 33188},
          {"ebin/x.beam", 0o100777},
          {"ebin/a\0b", 33188},
          {"ebin/..\\x", 33188},
          {"ebin\\x.beam", 33188}
        ] do
      assert {:fail, "unsafe path or mode (" <> _} =
               Fetch.install(
                 config,
                 :ash,
                 entry([file_entry(s, 1, path, mode)]),
                 @lock_entry,
                 lib
               ),
             "#{inspect({path, mode})}"
    end

    refute File.exists?(Path.join(lib, "ash"))
  end

  test "verify_app can reject the staged app and nothing is installed", %{
    f: f,
    config: config,
    build_lib: lib
  } do
    e = entry(with_app(f, [file_entry(F.file(f, "b"), 1)]))
    seen = self()

    verify = fn path ->
      send(seen, {:app, path})
      {:fail, "compile_env differs: ash [:mode]"}
    end

    assert {:fail, "compile_env differs: ash [:mode]"} =
             Fetch.install(config, :ash, e, @lock_entry, lib, verify_app: verify)

    assert_received {:app, path}
    assert String.ends_with?(path, ".precompiled/ash/ebin/ash.app")
    refute File.exists?(Path.join(lib, "ash"))
    refute File.exists?(Path.join(lib, ".precompiled/ash"))
  end

  test "a dependency without an .app file fails", %{f: f, config: config, build_lib: lib} do
    s = F.file(f, "beam")

    assert {:fail, "no ebin/ash.app in entry"} =
             Fetch.install(config, :ash, entry([file_entry(s, 4)]), @lock_entry, lib)
  end

  test "an exception while staging fails cleanly and leaves _build untouched", %{
    f: f,
    config: config,
    build_lib: lib
  } do
    e = entry(with_app(f, [file_entry(F.file(f, "x"), 1)]))
    File.mkdir_p!(lib)
    File.write!(Path.join(lib, ".precompiled"), "blocking file, not a directory")

    assert {:fail, "install failed: " <> _} = Fetch.install(config, :ash, e, @lock_entry, lib)
    refute File.exists?(Path.join(lib, "ash"))
  end

  test "include/ and src/ from deps/<dep> are linked into the installed dep", %{
    f: f,
    config: config,
    build_lib: lib,
    tmp_dir: dir
  } do
    deps = Path.join(dir, "deps")
    File.mkdir_p!(Path.join(deps, "ash/include"))
    File.write!(Path.join(deps, "ash/include/x.hrl"), "-record(x, {a}).\n")
    File.mkdir_p!(Path.join(deps, "ash/src"))
    File.write!(Path.join(deps, "ash/src/ash.erl"), "-module(ash).\n")
    File.mkdir_p!(Path.join(deps, "ash/priv"))
    File.write!(Path.join(deps, "ash/priv/data.txt"), "data")

    e = entry(with_app(f, [file_entry(F.file(f, "b"), 1)]))

    assert {:ok, _} = Fetch.install(config, :ash, e, @lock_entry, lib, deps_path: deps)
    assert File.read!(Path.join(lib, "ash/include/x.hrl")) == "-record(x, {a}).\n"
    assert File.read!(Path.join(lib, "ash/src/ash.erl")) == "-module(ash).\n"
    # The manifest supplied no priv/, so Mix's own priv link is mirrored.
    assert File.read!(Path.join(lib, "ash/priv/data.txt")) == "data"
  end

  test "a manifest-supplied priv/ is not replaced by deps/<dep>/priv", %{
    f: f,
    config: config,
    build_lib: lib,
    tmp_dir: dir
  } do
    deps = Path.join(dir, "deps")
    File.mkdir_p!(Path.join(deps, "ash/priv"))
    File.write!(Path.join(deps, "ash/priv/data.txt"), "from deps")

    e =
      entry(with_app(f, [file_entry(F.file(f, "b"), 1)]))
      |> Map.put("priv", [file_entry(F.file(f, "built"), 5, "priv/data.txt")])

    assert {:ok, _} = Fetch.install(config, :ash, e, @lock_entry, lib, deps_path: deps)
    assert File.read!(Path.join(lib, "ash/priv/data.txt")) == "built"
    refute File.exists?(Path.join(lib, "ash/include"))
  end

  test "marker_term/4 writes the marker format of the running Mix" do
    vsn = {"1.19.5", ~c"28"}

    assert Fetch.marker_term("1.19.5", vsn, Hex.SCM, @lock_entry) == {1, vsn, Hex.SCM}
    assert Fetch.marker_term("1.17.0", vsn, Hex.SCM, @lock_entry) == {1, vsn, Hex.SCM}

    assert Fetch.marker_term("1.20.0", vsn, Hex.SCM, @lock_entry) ==
             {2, vsn, Hex.SCM, @lock_entry}

    assert Fetch.marker_term("1.20.3", vsn, Hex.SCM, @lock_entry) ==
             {2, vsn, Hex.SCM, @lock_entry}
  end

  test "a sha256 or size that could become a bad path or count fails the dependency", %{
    f: f,
    config: config,
    build_lib: lib
  } do
    for {sha, size} <- [{"../x", 1}, {String.duplicate("A", 64), 1}, {nil, 1}, {F.sha("x"), -1}] do
      e = entry(with_app(f, [file_entry(sha, size)]))

      assert {:fail, "unsafe file entry (ebin/Elixir.Ash.beam)"} =
               Fetch.install(config, :ash, e, @lock_entry, lib),
             inspect({sha, size})
    end

    refute File.exists?(Path.join(lib, "ash"))
    refute File.exists?(Path.join(config.home, "files/../x"))
  end

  test "an unsafe path or mode names the offending path", %{f: f, config: config, build_lib: lib} do
    e = entry(with_app(f, [file_entry(F.file(f, "x"), 1, "ebin/x.beam", 0o100777)]))

    assert {:fail, ~s|unsafe path or mode ("ebin/x.beam")|} =
             Fetch.install(config, :ash, e, @lock_entry, lib)
  end

  test "get_body refuses a redirect to another port on the same host", %{config: config} do
    assert {:error, "redirect to another host refused"} =
             Fetch.get_body(config.source <> "/redirect_port/batch.json")
  end
end
