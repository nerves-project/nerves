defmodule Nerves.Precompiled.Trust do
  @moduledoc """
  The trust chain's top: a root document shipped with `nerves` names the
  keys allowed to sign batches; a batch names every manifest by hash. Both
  travel in an envelope signed over raw bytes. Sequence numbers only go up.
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
         {:ok, raw} <- Base.url_decode64(sig, padding: false) do
      :crypto.verify(:eddsa, :none, payload, raw, [public, :ed25519])
    else
      _ -> false
    end
  end

  defp valid?(_, _, _), do: false

  @spec root_keys(root(), String.t()) :: {%{String.t() => binary()}, pos_integer()}
  def root_keys(root, role) do
    %{"keyids" => ids, "threshold" => t} = root["roles"][role]

    keys =
      Enum.reduce(ids, %{}, fn id, acc ->
        with %{"public" => pub} <- root["keys"][id],
             {:ok, bin} <- Base.url_decode64(pub, padding: false) do
          Map.put(acc, id, bin)
        else
          _ -> acc
        end
      end)

    {keys, t}
  end

  @spec load_root(map()) :: {:ok, root()} | {:error, String.t()}
  def load_root(config) do
    with {:ok, shipped} <- read_root_file(config.root_path, nil) do
      case read_root_file(Path.join(config.home, "root.json"), shipped) do
        {:ok, cached} when is_map(cached) -> {:ok, cached}
        _ -> {:ok, shipped}
      end
    end
  end

  # A root file must verify under its own root role; when `trusted` is given
  # (a cached update), also under the trusted root's root role, and be newer.
  defp read_root_file(path, trusted) do
    with {:ok, body} <- File.read(path),
         {:ok, env} <- safe_decode(body),
         {:ok, payload} <- self_verify(env),
         {:ok, root} <- safe_decode(payload),
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

  defp chained(_env, _root, nil), do: :ok

  defp chained(env, root, trusted) do
    {keys, t} = root_keys(trusted, "root")

    with true <- root["version"] > trusted["version"],
         {:ok, _} <- verify_envelope(env, keys, t) do
      :ok
    else
      _ -> {:error, "root update not signed by the current root"}
    end
  end

  @spec update_root(map(), root(), (String.t() -> {:ok, binary()} | {:error, term()})) ::
          {:ok, root()}
  def update_root(config, root, fetch) do
    with {:ok, body} <- fetch.(config.source <> "/root.json"),
         {:ok, env} <- safe_decode(body),
         {:ok, payload} <- self_verify(env),
         {:ok, candidate} <- safe_decode(payload),
         :ok <- chained(env, candidate, root) do
      File.mkdir_p!(config.home)
      File.write!(Path.join(config.home, "root.json"), body)
      {:ok, candidate}
    else
      _ -> {:ok, root}
    end
  end

  @spec fetch_batch(map(), root(), (String.t() -> {:ok, binary()} | {:error, term()})) ::
          {:ok, %{sequence: integer(), manifests: %{String.t() => String.t()}}}
          | {:error, String.t()}
  def fetch_batch(config, root, fetch) do
    {keys, t} = root_keys(root, "batch")

    with {:ok, body} <- fetch.(config.source <> "/batch.json") |> or_error("batch unavailable"),
         {:ok, payload} <- verify_envelope(body, keys, t) |> or_error("batch signature invalid"),
         {:ok, %{"version" => 1, "sequence" => seq, "expires" => exp, "manifests" => manifests}} <-
           safe_decode(payload) |> or_error("batch malformed"),
         :ok <- not_expired(exp),
         :ok <- monotonic(config, seq) do
      File.mkdir_p!(config.home)
      File.write!(Path.join(config.home, "state"), Integer.to_string(seq))
      {:ok, %{sequence: seq, manifests: manifests}}
    end
  end

  defp or_error({:ok, _} = ok, _), do: ok
  defp or_error(_, msg), do: {:error, msg}

  defp not_expired(exp) do
    case DateTime.from_iso8601(exp) do
      {:ok, dt, _} ->
        if DateTime.compare(dt, DateTime.utc_now()) == :gt,
          do: :ok,
          else: {:error, "batch expired at #{exp}"}

      _ ->
        {:error, "batch malformed"}
    end
  end

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
