defmodule Nerves.Provider.DockerTest do
  use NervesTest.Case, async: false

  alias Nerves.Package.Providers.Docker

  test "Generated docker container Id is valid" do
    id = Nerves.Utils.random_alpha_num(16)
    assert Regex.match?(~r/^[a-zA-Z0-9_]*$/, id)
  end

  test "Generated docker container Ids are different" do
    id1 = Nerves.Utils.random_alpha_num(16)
    id2 = Nerves.Utils.random_alpha_num(16)
    refute id1 == id2
  end

  test "parse versions with leading zeros" do
    assert {:ok, _} = Docker.parse_docker_version("17.0.1")
    assert {:ok, _} = Docker.parse_docker_version("17.03.1")
    assert {:ok, _} = Docker.parse_docker_version("0017000.00300.00001000-ce")
  end
end
