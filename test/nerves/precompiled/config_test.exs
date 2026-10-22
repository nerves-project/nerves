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
end
