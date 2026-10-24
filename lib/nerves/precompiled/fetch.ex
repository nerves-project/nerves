# SPDX-FileCopyrightText: 2026 Tom Hoenderdos
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Precompiled.Fetch do
  @moduledoc """
  Bytes in, verified files in `_build` out. Manifests are checked against
  the hash the batch names; files against the hash the manifest names,
  before anything reaches the build directory. Install is atomic per
  dependency: staged under `_build/<t>/lib/.precompiled/<dep>`, renamed
  into place with Mix's "already compiled" marker.
  """

  # 8 MiB: root, batch and any other document
  @max_body_bytes 8_388_608
  # 64 MiB: manifests of packages with many versions and systems run past 8 MiB
  @max_manifest_bytes 67_108_864
  @ok_modes [0o644, 0o755, 0o100644, 0o100755]

  @spec get_body(String.t(), keyword()) :: {:ok, binary()} | {:error, String.t()}
  def get_body(url, opts \\ []) do
    url
    |> Nerves.HTTPClient.get(
      into: "",
      max_bytes: Keyword.get(opts, :max_bytes, @max_body_bytes),
      same_origin: true,
      progress?: false
    )
    |> map_error()
  end

  defp map_error({:ok, body}), do: {:ok, body}

  defp map_error({:error, {:too_large, max_bytes}}),
    do: {:error, "response larger than #{max_bytes} bytes"}

  defp map_error({:error, :cross_origin_redirect}),
    do: {:error, "redirect to another host refused"}

  defp map_error({:error, :too_many_redirects}), do: {:error, "too many redirects"}
  defp map_error({:error, reason}) when is_binary(reason), do: {:error, reason}
  defp map_error({:error, reason}), do: {:error, inspect(reason)}

  @spec manifest(map(), String.t(), String.t()) ::
          {:ok, map()} | {:miss, String.t()} | {:fail, String.t()}
  def manifest(config, name, expected_sha) do
    case get_body("#{config.source}/manifests/#{name}.json", max_bytes: @max_manifest_bytes) do
      {:ok, bytes} ->
        if sha256(bytes) == expected_sha,
          do: decode(bytes),
          else: {:fail, "manifest hash differs from batch"}

      {:error, "Status 404 Not Found"} ->
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
      why = Enum.find_value(files, &bad_file/1) -> {:fail, why}
      not Enum.any?(files, &(&1["path"] == app)) -> {:fail, "no #{app} in entry"}
      true -> :ok
    end
  end

  # `sha256` becomes a cache file name and `size` a download cap, so both
  # are checked as strictly as the path before anything touches the disk.
  defp bad_file(%{} = f) do
    cond do
      not (safe_path?(f["path"]) and safe_mode?(f["mode"])) ->
        "unsafe path or mode (#{inspect(f["path"])})"

      not (sha256?(f["sha256"]) and is_integer(f["size"]) and f["size"] >= 0) ->
        "unsafe file entry (#{f["path"]})"

      true ->
        nil
    end
  end

  defp bad_file(other), do: "unsafe file entry (#{inspect(other)})"

  defp sha256?(sha), do: is_binary(sha) and sha =~ ~r/\A[0-9a-f]{64}\z/

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
    vsn = {System.version(), :erlang.system_info(:otp_release)}
    marker = :erlang.term_to_binary(marker_term(vsn, Hex.SCM, lock_entry))

    File.mkdir_p!(Path.join(staging, ".mix"))
    File.write!(Path.join([staging, ".mix", "compile.elixir_scm"]), marker)
  end

  @doc """
  Mix's "already compiled" marker (`Mix.Dep.ElixirSCM`) in the format the
  running Mix reads: Elixir 1.20 added the lock (format 2); 1.17 to 1.19
  read format 1 and would treat format 2 as stale and recompile the dep.
  """
  @spec marker_term({String.t(), charlist()}, module(), tuple()) :: tuple()
  def marker_term(vsn, scm, lock_entry), do: marker_term(System.version(), vsn, scm, lock_entry)

  @spec marker_term(String.t(), {String.t(), charlist()}, module(), tuple()) :: tuple()
  def marker_term(elixir_version, vsn, scm, lock_entry) do
    if Version.match?(elixir_version, ">= 1.20.0"),
      do: {2, vsn, scm, lock_entry},
      else: {1, vsn, scm}
  end

  defp sha256(bytes), do: Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)
end
