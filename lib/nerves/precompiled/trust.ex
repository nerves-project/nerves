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

  @spec load_root(map()) :: {:ok, root()} | {:error, String.t()}
  def load_root(config) do
    with {:ok, shipped} <- read_root_file(config.root_path, nil) do
      case read_root_file(Path.join(config.home, "root.json"), shipped) do
        {:ok, cached} when is_map(cached) -> {:ok, cached}
        _ -> {:ok, shipped}
      end
    end
  rescue
    _ -> {:error, "root document at #{config.root_path} is invalid"}
  end

  # A root file must verify under its own root role, not be expired, and
  # when `trusted` is given (a cached update), also verify under the
  # trusted root's root role, and be newer.
  defp read_root_file(path, trusted) do
    with {:ok, body} <- File.read(path),
         {:ok, env} <- safe_decode(body),
         {:ok, payload} <- self_verify(env),
         {:ok, root} <- safe_decode(payload),
         :ok <- expires_ok(root, path, trusted),
         :ok <- chained(env, root, trusted) do
      {:ok, root}
    else
      {:error, reason} when is_binary(reason) -> {:error, reason}
      _ -> {:error, "root document at #{path} is invalid"}
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

  defp expires_ok(root, path, nil) do
    case check_expiry(expires_of(root)) do
      :ok -> :ok
      :error -> {:error, "root document at #{path} expired at #{expires_of(root)}"}
    end
  end

  defp expires_ok(root, _path, _trusted) do
    case check_expiry(expires_of(root)) do
      :ok -> :ok
      :error -> {:error, "root expired"}
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

  defp chained(_env, _root, nil), do: :ok

  defp chained(env, root, trusted) do
    {keys, t} = root_keys(trusted, "root")

    with true <- newer?(root, trusted),
         {:ok, _} <- verify_envelope(env, keys, t) do
      :ok
    else
      _ -> {:error, "root update not signed by the current root"}
    end
  end

  defp newer?(root, trusted) do
    with %{"version" => rv} when is_integer(rv) <- root,
         %{"version" => tv} when is_integer(tv) <- trusted do
      rv > tv
    else
      _ -> false
    end
  end

  @spec update_root(map(), root(), (String.t() -> {:ok, binary()} | {:error, term()})) ::
          {:ok, root()}
  def update_root(config, root, fetch) do
    with {:ok, body} <- fetch.(config.source <> "/root.json"),
         {:ok, env} <- safe_decode(body),
         {:ok, payload} <- self_verify(env),
         {:ok, candidate} <- safe_decode(payload),
         :ok <- expires_ok(candidate, nil, root),
         :ok <- chained(env, candidate, root) do
      File.mkdir_p!(config.home)
      File.write!(Path.join(config.home, "root.json"), body)
      {:ok, candidate}
    else
      _ -> {:ok, root}
    end
  rescue
    _ -> {:ok, root}
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
         :ok <- monotonic(config, seq) do
      File.mkdir_p!(config.home)
      File.write!(Path.join(config.home, "state"), Integer.to_string(seq))
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

  defp monotonic(config, seq) do
    stored =
      case File.read(Path.join(config.home, "state")) do
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
