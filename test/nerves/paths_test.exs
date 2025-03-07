defmodule Nerves.PathsTest do
  use NervesTest.Case

  describe "data_dir/0" do
    test "XDG_DATA_HOME" do
      System.put_env("XDG_DATA_HOME", "xdg_data_home")
      assert "xdg_data_home/nerves" = Nerves.Paths.data_dir()
    end

    test "falls back to $HOME/.nerves" do
      System.delete_env("XDG_DATA_HOME")
      assert Path.expand("~/.nerves") == Nerves.Paths.data_dir()
    end
  end

  describe "artifact_dir/0" do
    test "XDG_DATA_HOME" do
      System.delete_env("NERVES_ARTIFACTS_DIR")
      System.put_env("XDG_DATA_HOME", "xdg_data_home")
      assert Path.expand("xdg_data_home/nerves/artifacts") == Nerves.Paths.artifacts_dir()
    end

    test "falls back to $HOME/.nerves" do
      System.delete_env("XDG_DATA_HOME")
      System.delete_env("NERVES_ARTIFACTS_DIR")
      assert Path.expand("~/.nerves/artifacts") == Nerves.Paths.artifacts_dir()
    end
  end

  describe "download_dir/0" do
    test "XDG_DATA_HOME" do
      System.delete_env("NERVES_DL_DIR")
      System.put_env("XDG_DATA_HOME", "xdg_data_home")
      assert Path.expand("xdg_data_home/nerves/dl") == Nerves.Paths.download_dir()
    end

    test "falls back to $HOME/.nerves" do
      System.delete_env("XDG_DATA_HOME")
      System.delete_env("NERVES_DL_DIR")
      assert Path.expand("~/.nerves/dl") == Nerves.Paths.download_dir()
    end
  end
end
