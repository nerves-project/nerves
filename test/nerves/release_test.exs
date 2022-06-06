defmodule Nerves.ReleaseTest do
  use NervesTest.Case, async: true

  @tag :release
  test "rootfs priorities from valid bootfile" do
    in_fixture("release_app", fn ->
      load_env()

      {_, 0} = System.cmd("mix", ["deps.get"], env: [{"MIX_ENV", "#{Mix.env()}"}])
      {_, 0} = System.cmd("mix", ["release"], env: [{"MIX_ENV", "#{Mix.env()}"}])

      generated =
        Path.join(Mix.Project.build_path(), "nerves/rootfs.priorities")
        |> only_basenames()

      expected = only_basenames("expected.rootfs.priorities")

      # This is only half a test since it just considers file names
      # and not full paths, but better than nothing
      assert generated == expected
    end)
  end

  defp only_basenames(path) do
    str = File.read!(path)

    for line <- String.split(str, "\n", trim: true),
        [p, n] = String.split(line, " "),
        do: [Path.basename(p), n]
  end
end
