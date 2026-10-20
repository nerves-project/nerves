# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
path = System.fetch_env!("COVER_PATH")
export = System.fetch_env!("COVER_EXPORT")

nerves_path = Path.join([path, "_build", "test", "lib", "nerves", "ebin"])

deps_paths =
  for package <- ["interactive_cmd"],
      do: Path.join([path, "_build", "test", "lib", package, "ebin"])

Code.prepend_paths([nerves_path | deps_paths])

{:ok, _pid} = :cover.start()
:ok = :cover.local_only()

beams =
  nerves_path
  |> File.ls!()
  |> Enum.filter(&(Path.extname(&1) == ".beam"))
  |> Enum.map(&String.to_charlist(Path.join(nerves_path, &1)))

if beams == [] do
  raise "No BEAM files found for coverage in #{nerves_path}"
end

for result <- :cover.compile_beam(beams) do
  case result do
    {:ok, _module} -> :ok
    {:error, reason} -> raise "Could not compile BEAM for coverage: #{inspect(reason)}"
  end
end

System.at_exit(fn _status ->
  output = Path.join(path, "cover")
  File.mkdir_p!(output)
  filename = Path.join(output, export <> ".coverdata")
  :ok = :cover.export(String.to_charlist(filename))
end)
