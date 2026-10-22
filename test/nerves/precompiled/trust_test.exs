defmodule Nerves.Precompiled.TrustTest do
  use ExUnit.Case, async: false
  alias Nerves.Precompiled.Trust
  alias Nerves.PrecompiledFixture, as: F
  @moduletag :tmp_dir

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

    %{f: f, config: config, fetch: &fetch/1}
  end

  defp fetch(url) do
    case Nerves.HTTPClient.get(url, into: "") do
      {:ok, body} -> {:ok, body}
      other -> other
    end
  end

  test "loads and verifies the shipped root", %{config: config, f: f} do
    assert {:ok, root} = Trust.load_root(config)
    assert {keys, 1} = Trust.root_keys(root, "batch")
    assert Map.keys(keys) == [f.key.keyid]
  end

  test "a shipped root with a bad signature is refused", %{config: config, f: f} do
    bad = put_in(f.root_env, ["signatures"], [])
    File.write!(config.root_path, :json.encode(bad))
    assert {:error, _} = Trust.load_root(config)
  end

  test "fetches a valid batch and stores the sequence", %{config: config, f: f, fetch: fetch} do
    F.publish(f, %{"ash" => %{"versions" => %{}}}, sequence: 5)
    {:ok, root} = Trust.load_root(config)

    assert {:ok, %{sequence: 5, manifests: %{"ash" => _}}} =
             Trust.fetch_batch(config, root, fetch)

    assert File.read!(Path.join(config.home, "state")) =~ "5"
  end

  test "an expired batch is refused", %{config: config, f: f, fetch: fetch} do
    F.publish(f, %{}, expires: "2020-01-01T00:00:00Z")
    {:ok, root} = Trust.load_root(config)
    assert {:error, "batch expired" <> _} = Trust.fetch_batch(config, root, fetch)
  end

  test "a replayed older batch is refused and state unchanged", %{
    config: config,
    f: f,
    fetch: fetch
  } do
    {:ok, root} = Trust.load_root(config)
    F.publish(f, %{}, sequence: 7)
    assert {:ok, _} = Trust.fetch_batch(config, root, fetch)
    F.publish(f, %{}, sequence: 6)
    assert {:error, "batch sequence 6 is older than 7"} = Trust.fetch_batch(config, root, fetch)
    assert File.read!(Path.join(config.home, "state")) =~ "7"
  end

  test "a batch signed by an unknown key is refused", %{config: config, f: f, fetch: fetch} do
    {pub, priv} = :crypto.generate_key(:eddsa, :ed25519)

    other = %{
      keyid: Base.encode16(:crypto.hash(:sha256, pub), case: :lower),
      public: pub,
      private: priv
    }

    F.publish(f, %{}, signers: [other])
    {:ok, root} = Trust.load_root(config)
    assert {:error, "batch signature invalid"} = Trust.fetch_batch(config, root, fetch)
  end

  test "a newer root signed by the current root is adopted and cached", %{
    config: config,
    f: f,
    fetch: fetch
  } do
    {pub, priv} = :crypto.generate_key(:eddsa, :ed25519)

    k2 = %{
      keyid: Base.encode16(:crypto.hash(:sha256, pub), case: :lower),
      public: pub,
      private: priv
    }

    root2 = F.root_payload(k2.keyid, pub, "2031-01-01T00:00:00Z", 2)
    F.serve_root(f, F.sign(root2, [f.key, k2]))
    {:ok, root} = Trust.load_root(config)
    assert {:ok, new_root} = Trust.update_root(config, root, fetch)
    assert {%{} = keys, 1} = Trust.root_keys(new_root, "batch")
    assert Map.keys(keys) == [k2.keyid]
    assert File.exists?(Path.join(config.home, "root.json"))
    assert {:ok, ^new_root} = Trust.load_root(config)
  end

  test "a newer root signed only by a stranger is ignored", %{config: config, f: f, fetch: fetch} do
    {pub, priv} = :crypto.generate_key(:eddsa, :ed25519)

    k2 = %{
      keyid: Base.encode16(:crypto.hash(:sha256, pub), case: :lower),
      public: pub,
      private: priv
    }

    F.serve_root(f, F.sign(F.root_payload(k2.keyid, pub, "2031-01-01T00:00:00Z", 2), [k2]))
    {:ok, root} = Trust.load_root(config)
    assert {:ok, ^root} = Trust.update_root(config, root, fetch)
    refute File.exists?(Path.join(config.home, "root.json"))
  end

  test "verify_envelope rejects garbage and duplicate signatures" do
    assert {:error, :bad_envelope} = Trust.verify_envelope("nope", %{}, 1)
    f = F.new(System.tmp_dir!())
    env = F.sign("x", [f.key])
    dup = Map.update!(env, "signatures", fn [s] -> [s, s] end)

    assert {:error, :below_threshold} =
             Trust.verify_envelope(dup, %{f.key.keyid => f.key.public}, 2)
  end
end
