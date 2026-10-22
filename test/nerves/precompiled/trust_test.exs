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

  defp shipped(config) do
    config.root_path
    |> File.read!()
    |> :json.decode()
    |> Map.fetch!("payload")
    |> Base.url_decode64!(padding: false)
    |> :json.decode()
  end

  defp state_dir(config), do: Trust.state_dir(config, shipped(config))

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

    assert File.read!(Path.join(state_dir(config), "state")) =~ "5"
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
    assert File.read!(Path.join(state_dir(config), "state")) =~ "7"
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
    assert File.exists?(Path.join(state_dir(config), "root.json"))
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
    refute File.exists?(Path.join(state_dir(config), "root.json"))
  end

  test "a served root with a missing or zero root threshold is ignored, never raises", %{
    config: config,
    f: f,
    fetch: fetch
  } do
    {pub, priv} = :crypto.generate_key(:eddsa, :ed25519)
    keyid = Base.encode16(:crypto.hash(:sha256, pub), case: :lower)
    k2 = %{keyid: keyid, public: pub, private: priv}
    {:ok, root} = Trust.load_root(config)

    missing_threshold =
      raw_root(keyid, pub, "2031-01-01T00:00:00Z", 2, root: %{"keyids" => [keyid]})

    F.serve_root(f, F.sign(missing_threshold, [f.key, k2]))
    assert {:ok, ^root} = Trust.update_root(config, root, fetch)
    refute File.exists?(Path.join(state_dir(config), "root.json"))

    zero_threshold =
      raw_root(keyid, pub, "2031-01-01T00:00:00Z", 2,
        root: %{"keyids" => [keyid], "threshold" => 0}
      )

    F.serve_root(f, F.sign(zero_threshold, [f.key, k2]))
    assert {:ok, ^root} = Trust.update_root(config, root, fetch)
    refute File.exists?(Path.join(state_dir(config), "root.json"))
  end

  test "a served root whose only key is undersized is ignored, never raises", %{
    config: config,
    f: f,
    fetch: fetch
  } do
    {pub, priv} = :crypto.generate_key(:eddsa, :ed25519)
    keyid = Base.encode16(:crypto.hash(:sha256, pub), case: :lower)
    short_pub = :crypto.strong_rand_bytes(10)
    {:ok, root} = Trust.load_root(config)

    payload =
      :json.encode(%{
        "version" => 2,
        "expires" => "2031-01-01T00:00:00Z",
        "keys" => %{keyid => %{"type" => "ed25519", "public" => F.b64(short_pub)}},
        "roles" => %{
          "root" => %{"keyids" => [keyid], "threshold" => 1},
          "batch" => %{"keyids" => [keyid], "threshold" => 1}
        }
      })
      |> IO.iodata_to_binary()

    F.serve_root(f, F.sign(payload, [%{keyid: keyid, public: pub, private: priv}]))
    assert {:ok, ^root} = Trust.update_root(config, root, fetch)
    refute File.exists?(Path.join(state_dir(config), "root.json"))
  end

  test "a batch whose root lacks a batch role is refused, not raised", %{
    config: config,
    f: f,
    fetch: fetch
  } do
    payload =
      :json.encode(%{
        "version" => 1,
        "expires" => "2030-01-01T00:00:00Z",
        "keys" => %{f.key.keyid => %{"type" => "ed25519", "public" => F.b64(f.key.public)}},
        "roles" => %{
          "root" => %{"keyids" => [f.key.keyid], "threshold" => 1}
        }
      })
      |> IO.iodata_to_binary()

    File.write!(config.root_path, :json.encode(F.sign(payload, [f.key])))
    F.publish(f, %{}, sequence: 1)
    {:ok, root} = Trust.load_root(config)
    assert {:error, "batch signature invalid"} = Trust.fetch_batch(config, root, fetch)
  end

  test "a shipped root past its own expiry is refused, not raised", %{tmp_dir: dir} do
    f = F.new(dir, root_expires: "2020-01-01T00:00:00Z")

    config = %{
      source: F.base_url(),
      except: [],
      root_path: f.root_path,
      home: Path.join(dir, "home")
    }

    assert {:error, "root document at " <> rest} = Trust.load_root(config)
    assert rest =~ "expired at 2020-01-01T00:00:00Z"
  end

  test "a served root with a higher version but expired is ignored, never raises", %{
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

    root2 = F.root_payload(k2.keyid, pub, "2020-01-01T00:00:00Z", 2)
    F.serve_root(f, F.sign(root2, [f.key, k2]))
    {:ok, root} = Trust.load_root(config)
    assert {:ok, ^root} = Trust.update_root(config, root, fetch)
    refute File.exists?(Path.join(state_dir(config), "root.json"))
  end

  # Builds a root payload like F.root_payload/4 but lets the caller override
  # the "root" role's shape (to exercise a missing/zero threshold).
  defp raw_root(keyid, public, expires, version, root: root_role) do
    :json.encode(%{
      "version" => version,
      "expires" => expires,
      "keys" => %{keyid => %{"type" => "ed25519", "public" => F.b64(public)}},
      "roles" => %{
        "root" => root_role,
        "batch" => %{"keyids" => [keyid], "threshold" => 1}
      }
    })
    |> IO.iodata_to_binary()
  end

  test "verify_envelope rejects garbage and duplicate signatures" do
    assert {:error, :bad_envelope} = Trust.verify_envelope("nope", %{}, 1)
    f = F.new(System.tmp_dir!())
    env = F.sign("x", [f.key])
    dup = Map.update!(env, "signatures", fn [s] -> [s, s] end)

    assert {:error, :below_threshold} =
             Trust.verify_envelope(dup, %{f.key.keyid => f.key.public}, 2)
  end

  test "state is kept per source: two sources do not see each other's sequence", %{
    config: config,
    f: f,
    fetch: fetch
  } do
    other = %{config | source: "http://localhost:#{Nerves.TestServer.port()}/precompiled"}
    {:ok, root} = Trust.load_root(config)

    F.publish(f, %{}, sequence: 7)
    assert {:ok, %{sequence: 7}} = Trust.fetch_batch(config, root, fetch)
    F.publish(f, %{}, sequence: 6)
    assert {:ok, %{sequence: 6}} = Trust.fetch_batch(other, root, fetch)
    assert {:error, "batch sequence 6 is older than 7"} = Trust.fetch_batch(config, root, fetch)

    refute state_dir(config) == state_dir(other)
    assert Path.dirname(state_dir(config)) == config.home
    assert File.read!(Path.join(state_dir(other), "state")) =~ "6"
  end

  test "the state dir is keyed by the shipped root, not a rotated one", %{
    config: config,
    f: f,
    fetch: fetch
  } do
    {pub, priv} = :crypto.generate_key(:eddsa, :ed25519)
    k2 = %{keyid: F.sha(pub), public: pub, private: priv}
    F.serve_root(f, F.sign(F.root_payload(k2.keyid, pub, "2031-01-01T00:00:00Z", 2), [f.key, k2]))
    {:ok, root} = Trust.load_root(config)
    {:ok, rotated} = Trust.update_root(config, root, fetch)
    F.publish(f, %{}, sequence: 4, signers: [k2])
    assert {:ok, %{sequence: 4}} = Trust.fetch_batch(config, rotated, fetch)
    assert File.read!(Path.join(state_dir(config), "state")) =~ "4"
  end
end
