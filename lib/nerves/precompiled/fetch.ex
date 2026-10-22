defmodule Nerves.Precompiled.Fetch do
  @moduledoc """
  Bytes in, verified files in `_build` out. Manifests are checked against
  the hash the batch names; files against the hash the manifest names,
  before anything reaches the build directory. Install is atomic per
  dependency: staged under `_build/<t>/lib/.precompiled/<dep>`, renamed
  into place with Mix's "already compiled" marker.
  """

  @max_body 8 * 1024 * 1024
  @max_manifest 64 * 1024 * 1024
  @max_redirects 5
  @ok_modes [0o644, 0o755, 0o100644, 0o100755]

  @spec get_body(String.t(), keyword()) :: {:ok, binary()} | {:error, String.t()}
  def get_body(url, opts \\ []) do
    ensure_httpc_started()
    request(url, Keyword.get(opts, :max_bytes, @max_body), 0)
  end

  defp ensure_httpc_started() do
    case :inets.start(:httpc, profile: :nerves) do
      :ok -> :ok
      {:error, {:already_started, _}} -> :ok
      other -> other
    end
  end

  defp request(_url, _max, n) when n > @max_redirects, do: {:error, "too many redirects"}

  defp request(url, max, n) do
    uri = URI.parse(url)

    http_opts =
      [autoredirect: false, timeout: 60_000] ++
        ssl_opts(uri) ++ Nerves.HTTPClient.proxy_request_options(url)

    headers = [{~c"user-agent", String.to_charlist("Nerves/#{Nerves.version()}")}]

    case :httpc.request(
           :get,
           {String.to_charlist(url), headers},
           http_opts,
           [sync: false, stream: :self, receiver: self(), body_format: :binary],
           :nerves
         ) do
      {:ok, request_id} -> await_body(request_id, uri, max, n, [], 0)
      {:error, reason} -> {:error, "request failed: #{inspect(reason)}"}
    end
  end

  # `stream: :self` only streams a 2xx response: a redirect or an error
  # status instead arrives as a single whole-body message, same as
  # `Nerves.HTTPClient.get/2`'s receive loop.
  defp await_body(ref, uri, max, n, acc, size) do
    receive do
      {:http, {^ref, :stream_start, _headers}} ->
        await_body(ref, uri, max, n, acc, size)

      {:http, {^ref, :stream, chunk}} ->
        size = size + byte_size(chunk)

        if size > max do
          cancel(ref)
          {:error, "response larger than #{max} bytes"}
        else
          await_body(ref, uri, max, n, [acc, chunk], size)
        end

      {:http, {^ref, :stream_end, _headers}} ->
        {:ok, IO.iodata_to_binary(acc)}

      {:http, {^ref, {{_, status, _}, h, _body}}} when status in [301, 302, 303, 307, 308] ->
        case List.keyfind(h, ~c"location", 0) do
          {_, loc} -> follow(uri, URI.merge(uri, to_string(loc)), max, n)
          nil -> {:error, "HTTP #{status} without location"}
        end

      {:http, {^ref, {{_, status, _}, _h, _body}}} ->
        {:error, "HTTP #{status}"}

      {:http, {^ref, {:error, reason}}} ->
        {:error, "request failed: #{inspect(reason)}"}
    after
      60_000 ->
        cancel(ref)
        {:error, "request timed out"}
    end
  end

  defp cancel(ref) do
    :httpc.cancel_request(ref, :nerves)
    flush(ref)
  end

  # `cancel_request/2` stops future deliveries but does not retroactively
  # unsend messages already in our mailbox; drain them so a canceled
  # request's stray chunks never leak into a later call's receive.
  defp flush(ref) do
    receive do
      {:http, {^ref, _}} -> flush(ref)
    after
      0 -> :ok
    end
  end

  defp follow(%URI{host: h, scheme: s}, %URI{host: h, scheme: s} = next, max, n),
    do: request(URI.to_string(next), max, n + 1)

  defp follow(_from, _to, _max, _n), do: {:error, "redirect to another host refused"}

  defp ssl_opts(%URI{scheme: "https"}) do
    [
      ssl: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        depth: 3,
        customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
      ]
    ]
  end

  defp ssl_opts(_), do: []

  @spec manifest(map(), String.t(), String.t()) ::
          {:ok, map()} | {:miss, String.t()} | {:fail, String.t()}
  def manifest(config, name, expected_sha) do
    case get_body("#{config.source}/manifests/#{name}.json", max_bytes: @max_manifest) do
      {:ok, bytes} ->
        if sha256(bytes) == expected_sha,
          do: decode(bytes),
          else: {:fail, "manifest hash differs from batch"}

      {:error, "HTTP 404"} ->
        {:miss, "no manifest"}

      {:error, reason} ->
        {:miss, "manifest unavailable: #{reason}"}
    end
  end

  defp decode(bytes) do
    {:ok, :json.decode(bytes)}
  rescue
    _ -> {:fail, "manifest is not JSON"}
  end

  @spec install(map(), atom(), map(), tuple(), Path.t(), keyword()) ::
          {:ok, %{files: non_neg_integer(), bytes: non_neg_integer(), cached: non_neg_integer()}}
          | {:fail, String.t()}
  def install(config, dep, entry, lock_entry, build_lib, opts \\ []) do
    files = (entry["ebin"] || []) ++ (entry["priv"] || [])
    staging = Path.join([build_lib, ".precompiled", Atom.to_string(dep)])
    dest = Path.join(build_lib, Atom.to_string(dep))
    verify_app = Keyword.get(opts, :verify_app, fn _ -> :ok end)

    try do
      with :ok <- validate(files, dep),
           {:ok, stats} <- stage(config, files, staging),
           :ok <- verify_app.(Path.join([staging, "ebin", "#{dep}.app"])) do
        write_marker(staging, lock_entry)
        File.rm_rf!(dest)
        File.mkdir_p!(build_lib)
        File.rename!(staging, dest)

        link_sources(
          dep,
          entry,
          dest,
          Keyword.get_lazy(opts, :deps_path, &Mix.Project.deps_path/0)
        )

        {:ok, stats}
      else
        {:fail, _} = fail ->
          File.rm_rf!(staging)
          fail
      end
    rescue
      e ->
        File.rm_rf!(staging)
        {:fail, "install failed: #{Exception.message(e)}"}
    end
  end

  # Mix links deps/<dep>/include (and src for rebar deps, and priv) into
  # _build when it builds a dep; a dep installed here is never built, so
  # mirror that or a dependent's -include_lib/Record.extract fails.
  defp link_sources(dep, entry, dest, deps_path) do
    source = Path.join(deps_path, Atom.to_string(dep))
    priv = if (entry["priv"] || []) == [], do: ["priv"], else: []

    for name <- ["include", "src" | priv],
        from = Path.join(source, name),
        to = Path.join(dest, name),
        File.dir?(from) and not File.exists?(to) do
      Mix.Utils.symlink_or_copy(from, to)
    end

    :ok
  end

  defp validate(files, dep) do
    app = "ebin/#{dep}.app"

    cond do
      Enum.any?(files, fn f ->
        not (safe_path?(f["path"]) and safe_mode?(f["mode"]) and is_binary(f["sha256"]) and
                 is_integer(f["size"]))
      end) ->
        bad = Enum.find(files, fn f -> not (safe_path?(f["path"]) and safe_mode?(f["mode"])) end)
        {:fail, "unsafe path or mode (#{inspect(bad["path"])})"}

      not Enum.any?(files, &(&1["path"] == app)) ->
        {:fail, "no #{app} in entry"}

      true ->
        :ok
    end
  end

  @spec safe_path?(term()) :: boolean()
  def safe_path?(path) when is_binary(path) do
    String.valid?(path) and not String.contains?(path, <<0>>) and
      not String.contains?(path, "\\") and
      (String.starts_with?(path, "ebin/") or String.starts_with?(path, "priv/")) and
      Path.type(path) == :relative and not Enum.member?(Path.split(path), "..") and
      Path.expand(path, "/x") |> String.starts_with?("/x/")
  end

  def safe_path?(_), do: false

  @spec safe_mode?(term()) :: boolean()
  def safe_mode?(mode), do: mode in @ok_modes

  defp stage(config, files, staging) do
    File.rm_rf!(staging)
    File.mkdir_p!(staging)
    cache = Path.join(config.home, "files")
    File.mkdir_p!(cache)

    Enum.reduce_while(files, {:ok, %{files: 0, bytes: 0, cached: 0}}, fn f, {:ok, acc} ->
      case fetch_file(config, cache, f) do
        {:ok, cached_path, cached?} ->
          target = Path.join(staging, f["path"])
          File.mkdir_p!(Path.dirname(target))
          File.cp!(cached_path, target)
          File.chmod!(target, Bitwise.band(f["mode"], 0o777))

          {:cont,
           {:ok,
            %{
              acc
              | files: acc.files + 1,
                bytes: acc.bytes + f["size"],
                cached: acc.cached + if(cached?, do: 1, else: 0)
            }}}

        {:fail, _} = fail ->
          {:halt, fail}
      end
    end)
  end

  defp fetch_file(config, cache, %{"sha256" => sha, "size" => size, "path" => path}) do
    cached = Path.join(cache, sha)

    if File.exists?(cached) and verify(cached, sha, size) == :ok do
      {:ok, cached, true}
    else
      tmp = cached <> ".tmp-#{System.unique_integer([:positive])}"

      with {:ok, body} <-
             get_body("#{config.source}/files/#{sha}", max_bytes: size) |> file_error(sha),
           :ok <- File.write(tmp, body),
           :ok <- verify(tmp, sha, size) |> name_path(path) do
        File.rename!(tmp, cached)
        {:ok, cached, false}
      else
        {:fail, _} = fail ->
          File.rm(tmp)
          fail
      end
    end
  end

  defp file_error({:ok, _} = ok, _), do: ok

  defp file_error({:error, "response larger" <> _}, _),
    do: {:fail, "file larger than declared size"}

  defp file_error({:error, reason}, sha), do: {:fail, "file not available: #{sha} (#{reason})"}

  defp verify(path, sha, size) do
    case File.stat(path) do
      {:ok, %{size: ^size}} ->
        if sha256(File.read!(path)) == sha, do: :ok, else: {:fail, "sha256 mismatch"}

      {:ok, _} ->
        {:fail, "size mismatch"}

      _ ->
        {:fail, "unreadable"}
    end
  end

  defp name_path(:ok, _), do: :ok
  defp name_path({:fail, why}, path), do: {:fail, "#{why} (#{path})"}

  defp write_marker(staging, lock_entry) do
    marker =
      :erlang.term_to_binary(
        {2, {System.version(), :erlang.system_info(:otp_release)}, Hex.SCM, lock_entry}
      )

    File.mkdir_p!(Path.join(staging, ".mix"))
    File.write!(Path.join([staging, ".mix", "compile.elixir_scm"]), marker)
  end

  defp sha256(bytes), do: Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)
end
