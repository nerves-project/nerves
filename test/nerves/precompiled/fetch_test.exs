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

    assert {:error, "HTTP 404"} = Fetch.get_body(config.source <> "/manifests/nope.json")
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

    marker =
      Path.join(lib, "ash/.mix/compile.elixir_scm") |> File.read!() |> :erlang.binary_to_term()

    assert marker ==
             {2, {System.version(), :erlang.system_info(:otp_release)}, Hex.SCM, @lock_entry}

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
end
