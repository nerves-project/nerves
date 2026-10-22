defmodule Nerves.Precompiled.ConfigTest do
  use ExUnit.Case, async: false
  alias Nerves.Precompiled.Config

  setup do
    old = Application.get_env(:nerves, :precompiled)

    on_exit(fn ->
      Application.put_env(:nerves, :precompiled, old)
      System.delete_env("NERVES_PRECOMPILED")
      System.delete_env("NERVES_PRECOMPILED_HOME")
    end)
  end

  test "no source means nil" do
    Application.put_env(:nerves, :precompiled, [])
    assert Config.load() == nil
    Application.delete_env(:nerves, :precompiled)
    assert Config.load() == nil
  end

  test "source enables, with defaults" do
    Application.put_env(:nerves, :precompiled, source: "https://example.test/api/precompiled/")
    c = Config.load()
    assert c.source == "https://example.test/api/precompiled"
    assert c.except == []
    assert c.root_path == Path.join(:code.priv_dir(:nerves), "precompiled/root.json")
    assert c.home == Path.expand("~/.nerves/precompiled")
  end

  test "overrides and the kill switch" do
    Application.put_env(:nerves, :precompiled,
      source: "https://x",
      except: [:ash],
      root: "/tmp/root.json"
    )

    System.put_env("NERVES_PRECOMPILED_HOME", "/tmp/pc")
    assert %{except: [:ash], root_path: "/tmp/root.json", home: "/tmp/pc"} = Config.load()
    System.put_env("NERVES_PRECOMPILED", "0")
    assert Config.load() == nil
  end

  test "except entries that are neither atoms nor strings are ignored" do
    Application.put_env(:nerves, :precompiled, source: "https://x", except: [1, "ash", :jason])

    {config, out} = with_shell(&Config.load/0)
    assert config.except == [:ash, :jason]
    assert out =~ "except"
  end

  defp with_shell(fun) do
    stderr =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        stdio = ExUnit.CaptureIO.capture_io(fn -> send(self(), {:result, fun.()}) end)
        send(self(), {:stdio, stdio})
      end)

    assert_received {:result, result}
    assert_received {:stdio, stdio}
    {result, stdio <> stderr}
  end
end
