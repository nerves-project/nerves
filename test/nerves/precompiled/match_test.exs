defmodule Nerves.Precompiled.MatchTest do
  use ExUnit.Case, async: true
  alias Nerves.Precompiled.Match

  @spark {:hex, :spark, "2.7.8", "inner", [:mix], [], "hexpm", "SPARKOUTER"}
  @ash {:hex, :ash, "3.5.2", "inner", [:mix],
        [{:spark, "~> 2.7", [hex: :spark, repo: "hexpm", optional: false]}], "hexpm", "ASHOUTER"}
  @nerves {:hex, :nerves, "2.0.0-pre.4", "i", [:make, :mix],
           [{:tablet, "~> 0.3", [hex: :tablet, repo: "hexpm", optional: false]}], "hexpm", "NO"}
  @tablet {:hex, :tablet, "0.3.1", "i", [:mix], [], "hexpm", "TO"}
  @sys {:hex, :nerves_system_rpi4, "1.31.0", "i", [:mix], [], "hexpm", "SO"}
  @git {:git, "https://example/x.git", "abc", []}
  @lock %{
    spark: @spark,
    ash: @ash,
    nerves: @nerves,
    tablet: @tablet,
    nerves_system_rpi4: @sys,
    gitdep: @git
  }

  defp ctx(over \\ %{}) do
    Map.merge(
      %{
        name: "ash",
        version: "3.5.2",
        lock_entry: @ash,
        lock: @lock,
        system: {"nerves_system_rpi4", "1.31.0"},
        elixir: "1.20.3",
        otp: "29",
        config: fn _app, _path -> :error end
      },
      over
    )
  end

  defp entry(over \\ %{}) do
    Map.merge(
      %{
        "ebin" => [
          %{
            "path" => "ebin/Elixir.Ash.beam",
            "sha256" => String.duplicate("a", 64),
            "size" => 1,
            "mode" => 33188
          }
        ],
        "priv" => [],
        "build" => %{
          "elixir" => "1.20.3",
          "otp" => "29",
          "system_version" => "1.31.0",
          "run_id" => "r",
          "image_digest" => "d",
          "deps" => %{"spark" => %{"version" => "2.7.8", "checksum" => "SPARKOUTER"}},
          "compile_env" => [],
          "package_checksum" => "ASHOUTER"
        }
      },
      over
    )
  end

  defp manifest(system \\ "nerves_system_rpi4", e \\ entry()),
    do: %{"versions" => %{"3.5.2" => %{system => e}}}

  describe "candidate?/3" do
    test "hex deps are candidates, tooling and nerves' children are not" do
      assert Match.candidate?(:ash, @lock, [])
      refute Match.candidate?(:nerves, @lock, [])
      refute Match.candidate?(:nerves_system_rpi4, @lock, [])
      refute Match.candidate?(:tablet, @lock, [])
      refute Match.candidate?(:gitdep, @lock, [])
      refute Match.candidate?(:ash, @lock, [:ash])
      refute Match.candidate?(:unknown, @lock, [])
    end
  end

  describe "select/2" do
    test "an exact match is selected" do
      assert {:ok, _entry, "nerves_system_rpi4"} = Match.select(manifest(), ctx())
    end

    test "pure_elixir matches any system" do
      assert {:ok, _, "pure_elixir"} =
               Match.select(
                 manifest(
                   "pure_elixir",
                   entry(%{"build" => Map.put(entry()["build"], "system_version", nil)})
                 ),
                 ctx()
               )
    end

    test "missing version or system is a miss" do
      assert {:miss, "not built for 3.5.2"} = Match.select(%{"versions" => %{}}, ctx())

      assert {:miss, "not built for nerves_system_rpi4 1.31.0"} =
               Match.select(manifest("nerves_system_bbb"), ctx())
    end

    test "toolchain and system version must match exactly" do
      assert {:miss, "built with Elixir 1.19.1, running 1.20.3"} =
               Match.select(
                 manifest(
                   "nerves_system_rpi4",
                   entry(%{"build" => Map.put(entry()["build"], "elixir", "1.19.1")})
                 ),
                 ctx()
               )

      assert {:miss, "built with OTP 28, running 29"} =
               Match.select(
                 manifest(
                   "nerves_system_rpi4",
                   entry(%{"build" => Map.put(entry()["build"], "otp", "28")})
                 ),
                 ctx()
               )

      assert {:miss, "built for nerves_system_rpi4 1.30.0, project has 1.31.0"} =
               Match.select(
                 manifest(
                   "nerves_system_rpi4",
                   entry(%{"build" => Map.put(entry()["build"], "system_version", "1.30.0")})
                 ),
                 ctx()
               )
    end

    test "package checksum must match the lock" do
      assert {:miss, "package checksum differs from mix.lock"} =
               Match.select(
                 manifest(
                   "nerves_system_rpi4",
                   entry(%{"build" => Map.put(entry()["build"], "package_checksum", "OTHER")})
                 ),
                 ctx()
               )

      assert {:miss, "build predates package_checksum"} =
               Match.select(
                 manifest(
                   "nerves_system_rpi4",
                   entry(%{"build" => Map.delete(entry()["build"], "package_checksum")})
                 ),
                 ctx()
               )
    end

    test "deps lock is a subset check with exact version and checksum" do
      deps = %{"spark" => %{"version" => "2.7.2", "checksum" => "SPARKOUTER"}}

      assert {:miss, "built against spark 2.7.2, lock has 2.7.8"} =
               Match.select(
                 manifest(
                   "nerves_system_rpi4",
                   entry(%{"build" => Map.put(entry()["build"], "deps", deps)})
                 ),
                 ctx()
               )

      deps = %{"spark" => %{"version" => "2.7.8", "checksum" => "X"}}

      assert {:miss, "built against spark 2.7.8 with another checksum"} =
               Match.select(
                 manifest(
                   "nerves_system_rpi4",
                   entry(%{"build" => Map.put(entry()["build"], "deps", deps)})
                 ),
                 ctx()
               )

      deps = %{"sourceror" => %{"version" => "1.0.0", "checksum" => "S"}}

      assert {:miss, "built against sourceror 1.0.0, not in lock"} =
               Match.select(
                 manifest(
                   "nerves_system_rpi4",
                   entry(%{"build" => Map.put(entry()["build"], "deps", deps)})
                 ),
                 ctx()
               )

      assert {:miss, "build predates deps lock"} =
               Match.select(
                 manifest(
                   "nerves_system_rpi4",
                   entry(%{"build" => Map.put(entry()["build"], "deps", nil)})
                 ),
                 ctx()
               )
    end

    test "deps with a non-existing atom name does not create atoms" do
      name = "zz_never_an_atom_#{System.unique_integer([:positive])}"
      expected_msg = "built against #{name} 1.0.0, not in lock"

      deps = %{name => %{"version" => "1.0.0", "checksum" => "X"}}

      assert {:miss, ^expected_msg} =
               Match.select(
                 manifest(
                   "nerves_system_rpi4",
                   entry(%{"build" => Map.put(entry()["build"], "deps", deps)})
                 ),
                 ctx()
               )

      # Verify the atom was not created
      assert_raise ArgumentError, fn -> String.to_existing_atom(name) end
    end

    test "compile_env_from_app reads the .app into the manifest shape", %{} do
      dir = System.tmp_dir!() |> Path.join("match-#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      app = Path.join(dir, "ash.app")
      File.write!(app, "{application, ash, [{compile_env, [{ash, [mode], {ok, fast}}]}]}.\n")

      assert [%{"app" => "ash", "path" => ["mode"], "value" => v}] =
               Match.compile_env_from_app(app)

      assert :erlang.binary_to_term(Base.url_decode64!(v, padding: false)) == {:ok, :fast}
      assert Match.compile_env_from_app(Path.join(dir, "none.app")) == nil
    end

    test "compile_env must equal the project's config" do
      value = fn term -> Base.url_encode64(:erlang.term_to_binary(term), padding: false) end
      ce = [%{"app" => "ash", "path" => ["mode"], "value" => value.({:ok, :fast})}]

      m =
        manifest(
          "nerves_system_rpi4",
          entry(%{"build" => Map.put(entry()["build"], "compile_env", ce)})
        )

      assert {:ok, _, _} = Match.select(m, ctx(%{config: fn "ash", ["mode"] -> {:ok, :fast} end}))

      assert {:miss, "compile_env differs: ash [:mode]"} =
               Match.select(m, ctx(%{config: fn "ash", ["mode"] -> :error end}))

      assert {:miss, "build predates compile_env"} =
               Match.select(
                 manifest(
                   "nerves_system_rpi4",
                   entry(%{"build" => Map.delete(entry()["build"], "compile_env")})
                 ),
                 ctx()
               )
    end
  end
end
