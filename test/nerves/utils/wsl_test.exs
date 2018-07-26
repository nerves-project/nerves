defmodule Nerves.Utils.WSLTest do
  use ExUnit.Case

  alias Nerves.Utils.WSL

  describe "is_wsl?/1" do
    test "it returns true when osrelease contains Microsoft" do
      fixture_file = Path.join(File.cwd!(), "test/fixtures/wsl/osrelease_wsl")
      assert true == WSL.is_wsl?(fixture_file)
    end

    test "it returns false when the file does not contain Microsoft" do
      fixture_file = Path.join(File.cwd!(), "test/fixtures/wsl/osrelease_linux")
      assert false == WSL.is_wsl?(fixture_file)
    end

    test "it returns false when osrelease file does not exist" do
      fixture_file = Path.join(File.cwd!(), "test/fixtures/wsl/bogus")
      assert false == WSL.is_wsl?(fixture_file)
    end
  end
end
