# SPDX-FileCopyrightText: 2022 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Nerves.UtilsTest do
  use ExUnit.Case

  doctest Mix.Nerves.Utils

  describe "interactive_shell/3" do
    test "runs a command" do
      path = "tmp_file.txt"

      _ = File.rm(path)
      Mix.Nerves.Utils.interactive_shell("touch", [path])

      assert File.exists?(path)
      File.rm!(path)
    end

    test "paths with spaces" do
      path = "tmp_file with spaces.txt"

      _ = File.rm(path)
      Mix.Nerves.Utils.interactive_shell("touch", [path])

      assert File.exists?(path)
      File.rm!(path)
    end

    test "paths with quotes" do
      path = "tmp_file with ' and \".txt"

      _ = File.rm(path)
      Mix.Nerves.Utils.interactive_shell("touch", [path])

      assert File.exists?(path)
      File.rm!(path)
    end

    test "setting environment" do
      path = "tmp_file.txt"
      env_name = "INTERACTIVE_SHELL_TEST"

      # If the variable is set before the test is run, then the check
      # afterwards will fail even though all is good
      assert System.get_env(env_name) == nil
      _ = File.rm(path)

      Mix.Nerves.Utils.interactive_shell("sh", ["-c", "touch $#{env_name}"],
        env: %{env_name => path}
      )

      assert File.exists?(path)
      File.rm!(path)

      assert System.get_env(env_name) == nil
    end

    test "interactive tty" do
      path = "tmp_file.txt"
      _ = File.rm(path)

      Mix.Nerves.Utils.interactive_shell("sh", [
        "-c",
        "[ -t 0 ] && echo interactive > #{path} || echo non-interactive > #{path}"
      ])

      assert File.read(path) == {:ok, "interactive\n"}
      File.rm!(path)
    end
  end
end
