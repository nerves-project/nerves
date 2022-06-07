defmodule Nerves.Package.Utils.Squashfs do
  @moduledoc false
  use GenServer

  require Logger

  @file_types ["c", "b", "l", "d", "-"]
  @device_types ["c", "b"]
  @posix [r: 4, w: 2, x: 1, s: 1, t: 1]
  @sticky ["s", "t", "S", "T"]

  @spec start_link(String.t()) :: GenServer.on_start()
  def start_link(rootfs) do
    params = unsquashfs(rootfs)

    dir =
      Path.dirname(rootfs)
      |> Path.join("squashfs")

    case Nerves.Port.cmd("unsquashfs", [rootfs, "-d", dir]) do
      {_result, 0} ->
        GenServer.start_link(__MODULE__, [rootfs, dir, params])

      {error, _} ->
        {:error, error}
    end
  end

  @spec stop(GenServer.server()) :: :ok
  def stop(pid) do
    GenServer.call(pid, :stop)
    GenServer.stop(pid)
  end

  @spec pseudofile(GenServer.server()) :: String.t()
  def pseudofile(pid) do
    GenServer.call(pid, {:pseudofile})
  end

  @spec pseudofile_fragment(GenServer.server(), String.t()) :: String.t()
  def pseudofile_fragment(pid, fragment) do
    GenServer.call(pid, {:pseudofile_fragment, fragment})
  end

  @spec fragment(GenServer.server(), String.t(), Path.t(), Keyword.t()) :: Path.t()
  def fragment(pid, fragment, path, opts \\ []) do
    GenServer.call(pid, {:fragment, fragment, path, opts})
  end

  @spec files(GenServer.server()) :: [Path.t()]
  def files(pid) do
    GenServer.call(pid, {:files})
  end

  # def merge(pid, file_systems, pseudofiles, path) do
  #   GenServer.call(pid, {:mergefs, file_systems, pseudofiles, path})
  # end

  defp unsquashfs(rootfs) do
    case Nerves.Port.cmd("unsquashfs", ["-n", "-ll", rootfs]) do
      {result, 0} ->
        String.split(result, "\n")
        |> parse

      {error, _} ->
        raise "Error parsing Rootfs: #{inspect(error)}"
    end
  end

  @impl GenServer
  def init([rootfs, stage, params]) do
    {:ok,
     %{
       rootfs: rootfs,
       params: params,
       stage: stage
     }}
  end

  @impl GenServer
  def handle_call(:stop, _from, s) do
    _ = File.rm_rf!(s.stage)
    {:reply, :ok, s}
  end

  def handle_call({:files}, _from, s) do
    files =
      Enum.reduce(s.params, [], fn
        {"d", _, _, _, _}, acc -> acc
        {_, file, _, _, _}, acc -> [file | acc]
      end)

    {:reply, files, s}
  end

  def handle_call({:pseudofile}, _from, s) do
    {:reply, params_to_pseudofile(s.params), s}
  end

  def handle_call({:pseudofile_fragment, fragment}, _from, s) do
    fragment =
      Enum.filter(s.params, fn {_, file, _, _, _} ->
        file in fragment
      end)

    {:reply, params_to_pseudofile(fragment), s}
  end

  def handle_call({:fragment, fragment, path, opts}, _from, s) do
    pseudo_fragment =
      fragment
      |> Enum.map(&path_to_paths/1)
      |> List.flatten()
      |> Enum.uniq()

    pseudo_fragment = Enum.filter(s.params, fn {_, file, _, _, _} -> file in pseudo_fragment end)
    fragment = Enum.filter(s.params, fn {_, file, _, _, _} -> file in fragment end)

    pseudofile = params_to_pseudofile(pseudo_fragment)

    tmp_dir =
      Path.dirname(path)
      |> Path.join("tmp")

    File.mkdir_p!(tmp_dir)
    pseudofile_name = opts[:name] || "pseudofile"

    pseudofile_path =
      Path.dirname(path)
      |> Path.join(pseudofile_name)

    File.write!(pseudofile_path, pseudofile)

    Enum.each(fragment, fn {_, file, _, _, _} ->
      src = Path.join(s.stage, file)
      dest = Path.join(tmp_dir, file)

      Path.dirname(dest)
      |> File.mkdir_p!()

      File.cp!(src, dest)
    end)

    IO.puts(path)

    _ =
      Nerves.Port.cmd("mksquashfs", [
        tmp_dir,
        path,
        "-pf",
        pseudofile_path,
        "-noappend",
        "-no-recovery",
        "-no-progress"
      ])

    _ = File.rm_rf!(tmp_dir)

    # File.rm!(pseudofile_path)

    {:reply, {:ok, path}, s}
  end

  # def handle_call({:mergefs, file_systems, pseudofiles, path}, from, s) do
  #
  #   stage_path =
  #     s.stage
  #     |> Path.dirname
  #
  #   unionfs = Path.join(stage_path, "union")
  #   Enum.each(fs, fn() ->
  #     Nerves.Port.cmd("unsquashfs", ["-d", s.stage, "-f", fs])
  #   end)
  #
  #   pseudofile = Enum.reduce(pseudofiles, "", fn(file, acc) ->
  #     File.read!(file) <> acc <> "\n"
  #   end)
  #   pseudofile <> "\n" <> params_to_pseudofile(s.params)
  #
  #   pseudofile_path = Path.join(stage_path, "pseudofile")
  #   File.write!(pseudofile_path, pseudofile)
  #
  #   Nerves.Port.cmd("mksquashfs", [s.stage, path, "-pf", pseudofile_path, "-noappend", "-no-recovery", "-no-progress"])
  #
  #   #File.rm!(pseudofile_path)
  #
  #   {:reply, {:ok, path}, s}
  # end

  defp params_to_pseudofile(fragment) do
    Enum.map(fragment, fn
      {type, file, {major, minor}, {p0, p1, p2, p3}, {o, g}} when type in @device_types ->
        "#{file} #{type} #{p0}#{p1}#{p2}#{p3} #{o} #{g} #{major} #{minor}"

      {_type, file, _attr, {p0, p1, p2, p3}, {o, g}} ->
        file = if file == "", do: "/", else: file
        "#{file} m #{p0}#{p1}#{p2}#{p3} #{o} #{g}"
    end)
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  defp parse(_, _ \\ [])
  defp parse([], collect), do: collect

  defp parse([line | tail], collect) do
    collect =
      case parse_line(line) do
        nil -> collect
        value -> [value | collect]
      end

    parse(tail, collect)
  end

  defp parse_line(""), do: nil

  defp parse_line(<<type::binary-size(1), permissions::binary-size(9), _::utf8, tail::binary>>)
       when type in @file_types do
    permissions = parse_permissions(permissions)
    [own, tail] = String.split(tail, " ", parts: 2)
    own = parse_own(own)
    tail = String.trim(tail)

    {attr, tail} =
      if type in @device_types do
        [major, tail] = String.split(tail, ",", parts: 2)
        tail = String.trim(tail)
        [minor, tail] = String.split(tail, " ", parts: 2)
        {{major, minor}, tail}
      else
        [_, tail] = String.split(tail, " ", parts: 2)
        {nil, tail}
      end

    <<_modified::binary-size(16), tail::binary>> = tail
    <<"squashfs-root", file::binary>> = String.trim(tail)

    file =
      if type == "l" do
        [file, _] = String.split(file, "->")
        String.trim(file)
      else
        file
      end

    {type, file, attr, permissions, own}
  end

  defp parse_line(_), do: nil

  defp parse_permissions(<<owner::binary-size(3), group::binary-size(3), other::binary-size(3)>>) do
    sticky = 0
    sticky = sticky + sticky_to_int(owner, 4) + sticky_to_int(group, 2) + sticky_to_int(other, 1)
    {sticky, posix_to_int(owner), posix_to_int(group), posix_to_int(other)}
  end

  defp parse_own(own) do
    [owner, group] = String.split(own, "/")
    {owner, group}
  end

  defp sticky_to_int(<<_::binary-size(1), _::binary-size(1), bit::binary-size(1)>>, weight)
       when bit in @sticky,
       do: weight

  defp sticky_to_int(_, _), do: 0

  defp posix_to_int(<<r::binary-size(1), w::binary-size(1), x::binary-size(1)>>) do
    Enum.reduce([r, w, x], 0, fn p, a ->
      Keyword.get(@posix, String.to_atom(p), 0) + a
    end)
  end

  defp path_to_paths(path) do
    path
    |> Path.split()
    |> Enum.reduce(["/"], fn p, acc ->
      [h | _t] = acc
      [Path.join(h, p) | acc]
    end)
    |> Enum.uniq()
  end
end
