defmodule Nerves.EnvTest do
  use NervesTest.Case, async: false
  alias Nerves.Env

  test "populate Nerves env" do
    in_fixture("simple_app", fn ->
      packages =
        ~w(system toolchain system_platform toolchain_platform)
        |> Enum.sort()

      env_pkgs =
        packages
        |> load_env
        |> Enum.map(& &1.app)
        |> Enum.map(&Atom.to_string/1)
        |> Enum.sort()

      assert packages == env_pkgs
    end)
  end

  test "determine host arch" do
    assert Env.parse_arch("win32") == "x86_64"
    assert Env.parse_arch("x86_64-apple-darwin14.1.0") == "x86_64"
    assert Env.parse_arch("armv7l-unknown-linux-gnueabihf") == "arm"
    assert Env.parse_arch("aarch64-unknown-linux-gnu") == "aarch64"
    assert Env.parse_arch("unknown") == "x86_64"
  end

  test "determine host platform" do
    assert Env.parse_platform("win32") == "win"
    assert Env.parse_platform("x86_64-apple-darwin14.1.0") == "darwin"
    assert Env.parse_platform("x86_64-unknown-linux-gnu") == "linux"
    assert Env.parse_platform("armv7l-unknown-linux-gnueabihf") == "linux"
    assert Env.parse_platform("aarch64-unknown-linux-gnu") == "linux"

    assert_raise Mix.Error, fn ->
      Env.parse_platform("unknown")
    end
  end

  test "override host os and host arch" do
    System.put_env("HOST_OS", "rpi")
    assert Nerves.Env.host_os() == "rpi"
    System.delete_env("HOST_OS")
    System.put_env("HOST_ARCH", "arm")
    assert Nerves.Env.host_arch() == "arm"
    System.delete_env("HOST_ARCH")
  end

  test "compiling Nerves packages from the top of an umbrella raises an error" do
    in_fixture("umbrella", fn ->
      File.cwd!()
      |> Path.join("mix.exs")
      |> Code.require_file()

      Mix.Tasks.Deps.Get.run([])

      assert_raise Mix.Error, fn ->
        Mix.Tasks.Nerves.Precompile.run([])
        Mix.Tasks.Compile.run([])
      end
    end)
  end

  describe "data_dir/0" do
    test "XDG_DATA_HOME" do
      System.put_env("XDG_DATA_HOME", "xdg_data_home")
      assert "xdg_data_home/nerves" = Nerves.Env.data_dir()
    end

    test "falls back to $HOME/.nerves" do
      System.delete_env("XDG_DATA_HOME")
      assert Path.expand("~/.nerves") == Nerves.Env.data_dir()
    end
  end

  describe "source_date_epoch" do
    setup do
      on_exit(fn ->
        System.delete_env("SOURCE_DATE_EPOCH")
        Application.delete_env(:nerves, :source_date_epoch)
      end)
    end

    test "from environment" do
      in_fixture("simple_app", fn ->
        packages = ~w(system toolchain system_platform toolchain_platform)
        System.put_env("SOURCE_DATE_EPOCH", "1234")
        load_env(packages)
        assert System.get_env("SOURCE_DATE_EPOCH") == "1234"
      end)
    end

    test "from config" do
      in_fixture("simple_app", fn ->
        packages = ~w(system toolchain system_platform toolchain_platform)
        Application.put_env(:nerves, :source_date_epoch, "1234")
        load_env(packages)
        assert System.get_env("SOURCE_DATE_EPOCH") == "1234"
      end)
    end

    test "nil" do
      in_fixture("simple_app", fn ->
        packages = ~w(system toolchain system_platform toolchain_platform)
        load_env(packages)
        assert System.get_env("SOURCE_DATE_EPOCH") == nil
      end)
    end

    test "invalid value" do
      System.put_env("SOURCE_DATE_EPOCH", "foo")
      assert {:error, _} = Nerves.Env.source_date_epoch()
      System.put_env("SOURCE_DATE_EPOCH", "")
      assert {:error, _} = Nerves.Env.source_date_epoch()
      System.delete_env("SOURCE_DATE_EPOCH")
      Application.put_env(:nerves, :source_date_epoch, "foo")
      assert {:error, _} = Nerves.Env.source_date_epoch()
      Application.put_env(:nerves, :source_date_epoch, "")
      assert {:error, _} = Nerves.Env.source_date_epoch()
    end

    test "mix raises when invalid" do
      in_fixture("simple_app", fn ->
        System.put_env("SOURCE_DATE_EPOCH", "")

        assert_raise Mix.Error, fn ->
          Nerves.Env.start()
        end
      end)
    end
  end

  describe "images_path" do
    test "without overrides" do
      in_fixture("simple_app", fn ->
        assert Env.images_path() == Path.join([Mix.Project.build_path(), "nerves", "images"])
      end)
    end

    test "override in mix config" do
      in_fixture("simple_app", fn ->
        config =
          Mix.Project.config()
          |> Keyword.put(:images_path, "/tmp")

        assert Env.images_path(config) == "/tmp"
      end)
    end
  end
end
