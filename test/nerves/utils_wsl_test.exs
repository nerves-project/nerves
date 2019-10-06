defmodule Nerves.MixUtilsTest do
  use NervesTest.Case, async: false

  alias Nerves.Utils.WSL

  test "valid_windows_path?/1 handles various Windows-specific paths properly" do
    paths = [
      {"C:\\", true},
      {"c:\\\\projects", true},
      {"\\\\myserver\\sharename\\", true},
      {"\\\\1.2.3.4\\sharename\\", true},
      {"\\\\wsl$\\Ubuntu-18.04\\home\\username", true},
      {"C\\missing_colon", false},
      {"\\\\\\triple\\leading\\slash", false},
      {"/unix/path", false}
    ]

    Enum.each(paths, fn {path, windows?} ->
      assert WSL.valid_windows_path?(path) == windows?
    end)
  end

  test "without wslpath, get_wsl_paths correctly converts a Windows accessible path" do
    use_wslpath = false
    windows_accessible_path = "/mnt/c/project/firmware.fw"
    expected_windows_path = "C:\\project\\firmware.fw"

    {win_path, wsl_path} = WSL.get_wsl_paths(windows_accessible_path, use_wslpath)

    assert String.equivalent?(expected_windows_path, win_path)
    assert String.equivalent?(windows_accessible_path, wsl_path)
  end

  test "with wslpath, get_wsl_paths correctly converts a Windows accessible path" do
    if WSL.running_on_wsl?() do
      use_wslpath = true
      windows_accessible_path = "/mnt/c/project/firmware.fw"
      expected_windows_path = "C:\\project\\firmware.fw"

      {win_path, wsl_path} = WSL.get_wsl_paths(windows_accessible_path, use_wslpath)

      assert String.equivalent?(expected_windows_path, win_path)
      assert String.equivalent?(windows_accessible_path, wsl_path)
    end
  end

  test "without wslpath, get_wsl_paths correctly converts a Windows inaccessible path" do
    use_wslpath = false
    windows_inaccessible_path = "/home/name/project/firmware.fw"

    {win_path, wsl_path} = WSL.get_wsl_paths(windows_inaccessible_path, use_wslpath)

    assert win_path === nil
    assert String.equivalent?(windows_inaccessible_path, wsl_path)
  end

  test "with wslpath, get_wsl_paths correctly converts a Windows inaccessible path" do
    if WSL.running_on_wsl?() do
      use_wslpath = true
      windows_inaccessible_path = "/home/name/project/firmware.fw"

      {win_path, wsl_path} = WSL.get_wsl_paths(windows_inaccessible_path, use_wslpath)

      assert win_path === nil
      assert String.equivalent?(windows_inaccessible_path, wsl_path)
    end
  end

  test "without wslpath, get_wsl_paths correctly converts a relative path" do
    use_wslpath = false
    relative_path = "~/project/firmware.fw"
    expected_path = Path.expand("~/project/firmware.fw")

    {_win_path, wsl_path} = WSL.get_wsl_paths(relative_path, use_wslpath)

    assert String.equivalent?(expected_path, wsl_path)
  end

  test "with wslpath, get_wsl_paths correctly converts a relative path" do
    if WSL.running_on_wsl?() do
      use_wslpath = true
      relative_path = "~/project/firmware.fw"
      expected_path = Path.expand("~/project/firmware.fw")

      {_win_path, wsl_path} = WSL.get_wsl_paths(relative_path, use_wslpath)

      assert String.equivalent?(expected_path, wsl_path)
    end
  end

  test "without wslpath, get_wsl_paths correctly converts a Windows path" do
    use_wslpath = false
    windows_path = "C:\\project\\firmware.fw"
    expected_path = "/mnt/c/project/firmware.fw"

    {win_path, wsl_path} = WSL.get_wsl_paths(windows_path, use_wslpath)

    assert String.equivalent?(expected_path, wsl_path)
    assert String.equivalent?(windows_path, win_path)
  end

  test "with wslpath, get_wsl_paths correctly converts a Windows path" do
    if WSL.running_on_wsl?() do
      use_wslpath = true
      windows_path = "C:\\project\\firmware.fw"
      expected_path = "/mnt/c/project/firmware.fw"

      {win_path, wsl_path} = WSL.get_wsl_paths(windows_path, use_wslpath)

      assert String.equivalent?(expected_path, wsl_path)
      assert String.equivalent?(windows_path, win_path)
    end
  end

  test "without wslpath, make_file_accessible creates temporary location for a Windows inaccessible path" do
    if WSL.running_on_wsl?() do
      running_on_wsl = true
      use_wslpath = false
      windows_inaccessible_path = "/home/name/project/firmware.fw"

      {_path, location} =
        WSL.make_file_accessible(windows_inaccessible_path, running_on_wsl, use_wslpath)

      assert location === :temporary_location
    end
  end

  test "with wslpath, make_file_accessible creates temporary location for a Windows inaccessible path" do
    if WSL.running_on_wsl?() do
      running_on_wsl = true
      use_wslpath = true
      windows_inaccessible_path = "/home/name/project/firmware.fw"

      {_path, location} =
        WSL.make_file_accessible(windows_inaccessible_path, running_on_wsl, use_wslpath)

      assert location === :temporary_location
    end
  end

  test "without wslpath, make_file_accessible does not create a temporary location for a Windows accessible path" do
    if WSL.running_on_wsl?() do
      running_on_wsl = true
      use_wslpath = false
      windows_accessible_path = "/mnt/c/project/firmware.fw"

      {_path, location} =
        WSL.make_file_accessible(windows_accessible_path, running_on_wsl, use_wslpath)

      assert location === :original_location
    end
  end

  test "with wslpath, make_file_accessible does not create a temporary location for a Windows accessible path" do
    if WSL.running_on_wsl?() do
      running_on_wsl = true
      use_wslpath = true
      windows_accessible_path = "/mnt/c/project/firmware.fw"

      {_path, location} =
        WSL.make_file_accessible(windows_accessible_path, running_on_wsl, use_wslpath)

      assert location === :original_location
    end
  end

  test "without WSL, make_file_accessible does not create a temporary location" do
    if WSL.running_on_wsl?() do
      running_on_wsl = false
      use_wslpath = false
      path = "/home/name/project/firmware.fw"

      {_path, location} = WSL.make_file_accessible(path, running_on_wsl, use_wslpath)

      assert location === :original_location
    end
  end
end
