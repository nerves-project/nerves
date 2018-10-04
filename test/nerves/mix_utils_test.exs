defmodule Nerves.MixUtilsTest do
  use NervesTest.Case, async: false

  alias Mix.Nerves.Utils

  test "without wslpath, get_wsl_paths correctly converts a Windows accessible path" do
    use_wslpath = false
    windows_accessible_path = "/mnt/c/project/firmware.fw"
    expected_windows_path = "C:\\project\\firmware.fw"

    {win_path, wsl_path} = Utils.get_wsl_paths(windows_accessible_path, use_wslpath)

    assert String.equivalent?(expected_windows_path, win_path)
    assert String.equivalent?(windows_accessible_path, wsl_path)
  end

  test "with wslpath, get_wsl_paths correctly converts a Windows accessible path" do
    if Utils.is_wsl?() do
      use_wslpath = true
      windows_accessible_path = "/mnt/c/project/firmware.fw"
      expected_windows_path = "C:\\project\\firmware.fw"

      {win_path, wsl_path} = Utils.get_wsl_paths(windows_accessible_path, use_wslpath)

      assert String.equivalent?(expected_windows_path, win_path)
      assert String.equivalent?(windows_accessible_path, wsl_path)
    end
  end

  test "without wslpath, get_wsl_paths correctly converts a Windows inaccessible path" do
    use_wslpath = false
    windows_inaccessible_path = "/home/name/project/firmware.fw"

    {win_path, wsl_path} = Utils.get_wsl_paths(windows_inaccessible_path, use_wslpath)

    assert win_path === nil
    assert String.equivalent?(windows_inaccessible_path, wsl_path)
  end

  test "with wslpath, get_wsl_paths correctly converts a Windows inaccessible path" do
    if Utils.is_wsl?() do
      use_wslpath = true
      windows_inaccessible_path = "/home/name/project/firmware.fw"

      {win_path, wsl_path} = Utils.get_wsl_paths(windows_inaccessible_path, use_wslpath)

      assert win_path === nil
      assert String.equivalent?(windows_inaccessible_path, wsl_path)
    end
  end

  test "without wslpath, get_wsl_paths correctly converts a relative path" do
    use_wslpath = false
    relative_path = "~/project/firmware.fw"
    expected_path = Path.expand("~/project/firmware.fw")

    {_win_path, wsl_path} = Utils.get_wsl_paths(relative_path, use_wslpath)

    assert String.equivalent?(expected_path, wsl_path)
  end

  test "with wslpath, get_wsl_paths correctly converts a relative path" do
    if Utils.is_wsl?() do
      use_wslpath = true
      relative_path = "~/project/firmware.fw"
      expected_path = Path.expand("~/project/firmware.fw")

      {_win_path, wsl_path} = Utils.get_wsl_paths(relative_path, use_wslpath)

      assert String.equivalent?(expected_path, wsl_path)
    end
  end

  test "without wslpath, get_wsl_paths correctly converts a Windows path" do
    use_wslpath = false
    windows_path = "C:\\project\\firmware.fw"
    expected_path = "/mnt/c/project/firmware.fw"

    {win_path, wsl_path} = Utils.get_wsl_paths(windows_path, use_wslpath)

    assert String.equivalent?(expected_path, wsl_path)
    assert String.equivalent?(windows_path, win_path)
  end

  test "with wslpath, get_wsl_paths correctly converts a Windows path" do
    if Utils.is_wsl?() do
      use_wslpath = true
      windows_path = "C:\\project\\firmware.fw"
      expected_path = "/mnt/c/project/firmware.fw"

      {win_path, wsl_path} = Utils.get_wsl_paths(windows_path, use_wslpath)

      assert String.equivalent?(expected_path, wsl_path)
      assert String.equivalent?(windows_path, win_path)
    end
  end

  test "without wslpath, make_firmware_accessible creates temporary location for a Windows inaccessible path" do
    if Utils.is_wsl?() do
      is_wsl = true
      use_wslpath = false
      windows_inaccessible_path = "/home/name/project/firmware.fw"

      {_path, location} = Utils.make_firmware_accessible(windows_inaccessible_path, is_wsl, use_wslpath)

      assert location === :temporary_location
    end
  end

  test "with wslpath, make_firmware_accessible creates temporary location for a Windows inaccessible path" do
    if Utils.is_wsl?() do
      is_wsl = true
      use_wslpath = true
      windows_inaccessible_path = "/home/name/project/firmware.fw"

      {_path, location} = Utils.make_firmware_accessible(windows_inaccessible_path, is_wsl, use_wslpath)

      assert location === :temporary_location
    end
  end

  test "without wslpath, make_firmware_accessible does not create a temporary location for a Windows accessible path" do
    if Utils.is_wsl?() do
      is_wsl = true
      use_wslpath = false
      windows_accessible_path = "/mnt/c/project/firmware.fw"

      {_path, location} = Utils.make_firmware_accessible(windows_accessible_path, is_wsl, use_wslpath)

      assert location === :original_location
    end
  end

  test "with wslpath, make_firmware_accessible does not create a temporary location for a Windows accessible path" do
    if Utils.is_wsl?() do
      is_wsl = true
      use_wslpath = true
      windows_accessible_path = "/mnt/c/project/firmware.fw"

      {_path, location} = Utils.make_firmware_accessible(windows_accessible_path, is_wsl, use_wslpath)

      assert location === :original_location
    end
  end

  test "without WSL, make_firmware_accessible does not create a temporary location" do
    if Utils.is_wsl?() do
      is_wsl = false
      use_wslpath = false
      path = "/home/name/project/firmware.fw"

      {_path, location} = Utils.make_firmware_accessible(path, is_wsl, use_wslpath)

      assert location === :original_location
    end
  end

end
