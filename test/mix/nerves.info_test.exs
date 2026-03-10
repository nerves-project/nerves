# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Nerves.InfoTest do
  use NervesTest.Case

  test "info returns versions" do
    in_fixture("simple_app", fn ->
      File.cwd!()
      |> Path.join("mix.exs")
      |> Code.require_file()

      load_env()

      Mix.Tasks.Nerves.Info.run([])

      assert_receive {:mix_shell, :info, ["Nerves:           " <> nerves]}
      assert_receive {:mix_shell, :info, ["Nerves Bootstrap: " <> bootstrap]}
      assert_receive {:mix_shell, :info, ["Elixir:           " <> elixir]}

      elixir_vsn = Version.parse!(elixir)
      bootstrap_vsn = Version.parse!(bootstrap)
      nerves_vsn = Version.parse!(nerves)

      assert Version.match?(elixir_vsn, "~> 1.15")
      assert Version.match?(bootstrap_vsn, "~> 1.5")
      assert Version.match?(nerves_vsn, "~> 1.13")
    end)
  end
end
