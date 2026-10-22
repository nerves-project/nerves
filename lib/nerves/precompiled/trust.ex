defmodule Nerves.Precompiled.Trust do
  @moduledoc """
  The trust chain's top: a root document shipped with `nerves` names the
  keys allowed to sign batches; a batch names every manifest by hash. Both
  travel in an envelope signed over raw bytes. Sequence numbers only go up.

  Every entry point here parses attacker-reachable input (a shipped file, a
  cached file, or whatever a server hands back), so every helper is written
  to return an error tuple instead of raising, and the public functions that
  touch the network or disk also carry a function-level `rescue` as a second
  line of defense.
  """

  @type root :: map()

  @spec verify_envelope(map() | binary(), %{String.t() => binary()}, pos_integer()) ::
          {:ok, binary()} | {:error, :bad_envelope | :below_threshold}
  def verify_envelope(envelope, keys, threshold) when is_binary(envelope) do
    case safe_decode(envelope) do
      {:ok, map} when is_map(map) -> verify_envelope(map, keys, threshold)
      _ -> {:error, :bad_envelope}
    end
  end

  def verify_envelope(%{"payload" => p, "signatures" => sigs}, keys, threshold)
      when is_binary(p) and is_list(sigs) and is_integer(threshold) and threshold > 0 do
    case Base.url_decode64(p, padding: false) do
      {:ok, payload} ->
        valid =
          sigs
          |> Enum.filter(&valid?(&1, payload, keys))
          |> Enum.map(& &1["keyid"])
          |> Enum.uniq()

        if length(valid) >= threshold, do: {:ok, payload}, else: {:error, :below_threshold}

      :error ->
        {:error, :bad_envelope}
    end
  end

  def verify_envelope(_, _, _), do: {:error, :bad_envelope}

  defp valid?(%{"keyid" => kid, "sig" => sig}, payload, keys)
       when is_binary(kid) and is_binary(sig) do
    with {:ok, public} <- Map.fetch(keys, kid),
         true <- byte_size(public) == 32,
         {:ok, raw} <- Base.url_decode64(sig, padding: false),
         true <- byte_size(raw) == 64 do
      :crypto.verify(:eddsa, :none, payload, raw, [public, :ed25519])
    else
      _ -> false
    end
  end

  defp valid?(_, _, _), do: false

  @doc """
  The keys and threshold for a role, or `{%{}, nil}` when `root` doesn't name
  that role with a usable shape. Total: never raises, whatever `root` is.
  """
  @spec root_keys(root(), String.t()) :: {%{String.t() => binary()}, pos_integer() | nil}
  def root_keys(root, role) when is_map(root) do
    case root["roles"] do
      %{^role => %{"keyids" => ids, "threshold" => t}}
      when is_list(ids) and is_integer(t) and t > 0 ->
        if Enum.all?(ids, &is_binary/1) do
          {resolve_keys(root["keys"], ids), t}
        else
          {%{}, nil}
        end

      _ ->
        {%{}, nil}
    end
  end

  def root_keys(_root, _role), do: {%{}, nil}

  defp resolve_keys(keys, ids) when is_map(keys) do
    Enum.reduce(ids, %{}, fn id, acc ->
      with %{"public" => pub} <- keys[id],
           {:ok, bin} <- Base.url_decode64(pub, padding: false) do
        Map.put(acc, id, bin)
      else
        _ -> acc
      end
    end)
  end

  defp resolve_keys(_keys, _ids), do: %{}

  @doc """
  Where the batch sequence and adopted roots live for this source: under
  `config.home`, named by the source URL and the shipped root's first root
  key, so two sources (or two trust anchors) never share replay state.
  Always keyed by the SHIPPED root, so a rotation keeps the same dir.
  """
  @spec state_dir(map(), root()) :: Path.t()
  def state_dir(config, shipped_root) do
    hash = sha256_hex(config.source <> "|" <> first_root_keyid(shipped_root))
    Path.join(config.home, binary_part(hash, 0, 16))
  end

  defp first_root_keyid(%{"roles" => %{"root" => %{"keyids" => [id | _]}}}) when is_binary(id),
    do: id

  defp first_root_keyid(_), do: ""

  # The shipped file was verified by `load_root/1`; here it only names the
  # dir and seeds the chain fold.
  defp shipped_root(config) do
    {:ok, body} = File.read(config.root_path)
    {:ok, env} = safe_decode(body)
    {:ok, payload} = decode_payload(env)
    {:ok, root} = safe_decode(payload)
    root
  end

  defp state_dir(config), do: state_dir(config, shipped_root(config))

  defp sha256_hex(bin), do: Base.encode16(:crypto.hash(:sha256, bin), case: :lower)

  @doc """
  The root in use: the shipped root, advanced along the adopted chain in
  `roots.json`. The shipped root must verify under its own root role; each
  chain entry must also verify under the previous root's root role, have a
  higher version and be unexpired, and the first one that fails ends the
  chain. Only the root in use must be unexpired, so a release keeps working
  past its shipped root's expiry once a newer root has been adopted.
  """
  @spec load_root(map()) :: {:ok, root()} | {:error, String.t()}
  def load_root(config) do
    with {:ok, shipped} <- read_shipped(config.root_path) do
      {root, adopted} = fold_chain(shipped, read_chain(state_dir(config, shipped)))

      case check_expiry(expires_of(root)) do
        :ok ->
          {:ok, root}

        :error when adopted == [] ->
          {:error, "root document at #{config.root_path} expired at #{expires_of(root)}"}

        :error ->
          {:error, "cached root expired at #{expires_of(root)}"}
      end
    end
  rescue
    _ -> {:error, "root document at #{config.root_path} is invalid"}
  end

  defp read_shipped(path) do
    with {:ok, body} <- File.read(path),
         {:ok, env} <- safe_decode(body),
         {:ok, payload} <- self_verify(env),
         {:ok, root} <- safe_decode(payload) do
      {:ok, root}
    else
      _ -> {:error, "root document at #{path} is invalid"}
    end
  end

  defp read_chain(dir) do
    with {:ok, body} <- File.read(Path.join(dir, "roots.json")),
         {:ok, envs} when is_list(envs) <- safe_decode(body) do
      envs
    else
      _ -> []
    end
  end

  # {root in use, envelopes adopted on the way there}
  defp fold_chain(shipped, envs) do
    {root, adopted} =
      Enum.reduce_while(envs, {shipped, []}, fn env, {current, adopted} ->
        case adopt(env, current) do
          {:ok, next} -> {:cont, {next, [env | adopted]}}
          :error -> {:halt, {current, adopted}}
        end
      end)

    {root, Enum.reverse(adopted)}
  end

  # A root may follow `current` when it verifies under its own root role and
  # under current's, is newer, and has not expired.
  defp adopt(env, current) do
    {keys, t} = root_keys(current, "root")

    with {:ok, payload} <- self_verify(env),
         {:ok, root} <- safe_decode(payload),
         true <- newer?(root, current),
         {:ok, _} <- verify_envelope(env, keys, t),
         :ok <- check_expiry(expires_of(root)) do
      {:ok, root}
    else
      _ -> :error
    end
  end

  defp self_verify(env) do
    with {:ok, payload} <- decode_payload(env),
         {:ok, root} <- safe_decode(payload),
         {keys, t} <- root_keys(root, "root"),
         {:ok, ^payload} <- verify_envelope(env, keys, t) do
      {:ok, payload}
    else
      _ -> {:error, "root signature invalid"}
    end
  end

  defp expires_of(%{"expires" => e}) when is_binary(e), do: e
  defp expires_of(_), do: nil

  defp check_expiry(exp) when is_binary(exp) do
    case DateTime.from_iso8601(exp) do
      {:ok, dt, _} -> if DateTime.compare(dt, DateTime.utc_now()) == :gt, do: :ok, else: :error
      _ -> :error
    end
  end

  defp check_expiry(_), do: :error

  defp newer?(root, trusted) do
    with %{"version" => rv} when is_integer(rv) <- root,
         %{"version" => tv} when is_integer(tv) <- trusted do
      rv > tv
    else
      _ -> false
    end
  end

  @doc """
  Adopt the source's served root when it chains from `root` (the root in
  use), appending it to `roots.json`. Anything else keeps `root`.
  """
  @spec update_root(map(), root(), (String.t() -> {:ok, binary()} | {:error, term()})) ::
          {:ok, root()}
  def update_root(config, root, fetch) do
    with {:ok, body} <- fetch.(config.source <> "/root.json"),
         {:ok, env} when is_map(env) <- safe_decode(body),
         {:ok, candidate} <- adopt(env, root) do
      shipped = shipped_root(config)
      dir = state_dir(config, shipped)
      {_, adopted} = fold_chain(shipped, read_chain(dir))
      write_atomic(dir, "roots.json", :json.encode(adopted ++ [env]))
      {:ok, candidate}
    else
      _ -> {:ok, root}
    end
  rescue
    _ -> {:ok, root}
  end

  defp write_atomic(dir, name, data) do
    File.mkdir_p!(dir)
    final = Path.join(dir, name)
    tmp = final <> ".tmp"
    File.write!(tmp, data)
    File.rename!(tmp, final)
  end

  @spec fetch_batch(map(), root(), (String.t() -> {:ok, binary()} | {:error, term()})) ::
          {:ok, %{sequence: integer(), manifests: %{String.t() => String.t()}}}
          | {:error, String.t()}
  def fetch_batch(config, root, fetch) do
    {keys, t} = root_keys(root, "batch")

    with {:ok, body} <- fetch.(config.source <> "/batch.json") |> or_error("batch unavailable"),
         {:ok, payload} <- verify_envelope(body, keys, t) |> or_error("batch signature invalid"),
         {:ok, decoded} <- safe_decode(payload) |> or_error("batch malformed"),
         {:ok, seq, exp, manifests} <- batch_fields(decoded),
         :ok <- not_expired(exp),
         dir = state_dir(config),
         :ok <- monotonic(dir, seq) do
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "state"), Integer.to_string(seq))
      {:ok, %{sequence: seq, manifests: manifests}}
    end
  rescue
    _ -> {:error, "batch malformed"}
  end

  defp batch_fields(%{
         "version" => 1,
         "sequence" => seq,
         "expires" => exp,
         "manifests" => manifests
       })
       when is_integer(seq) and is_binary(exp) and is_map(manifests) do
    {:ok, seq, exp, manifests}
  end

  defp batch_fields(_), do: {:error, "batch malformed"}

  defp or_error({:ok, _} = ok, _), do: ok
  defp or_error(_, msg), do: {:error, msg}

  # `batch_fields/1` only hands this a binary `exp`, but it's kept defensive
  # (no raise even on a non-binary) since it still runs inside the function's
  # `with`, ahead of the belt-and-braces `rescue`.
  defp not_expired(exp) do
    case safe_parse_iso8601(exp) do
      {:ok, dt} ->
        if DateTime.compare(dt, DateTime.utc_now()) == :gt,
          do: :ok,
          else: {:error, "batch expired at #{exp}"}

      :error ->
        {:error, "batch malformed"}
    end
  end

  defp safe_parse_iso8601(exp) when is_binary(exp) do
    case DateTime.from_iso8601(exp) do
      {:ok, dt, _} -> {:ok, dt}
      _ -> :error
    end
  end

  defp safe_parse_iso8601(_), do: :error

  defp monotonic(dir, seq) do
    stored =
      case File.read(Path.join(dir, "state")) do
        {:ok, s} -> s |> String.trim() |> Integer.parse() |> elem_or(0)
        _ -> 0
      end

    if seq >= stored, do: :ok, else: {:error, "batch sequence #{seq} is older than #{stored}"}
  end

  defp elem_or({n, _}, _), do: n
  defp elem_or(_, d), do: d

  defp decode_payload(%{"payload" => p}) when is_binary(p),
    do: Base.url_decode64(p, padding: false)

  defp decode_payload(_), do: :error

  defp safe_decode(bin) when is_binary(bin) do
    {:ok, :json.decode(bin)}
  rescue
    _ -> :error
  end
end
