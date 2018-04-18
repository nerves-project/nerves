defmodule Nerves.Artifact.ResolverTest do
  use NervesTest.Case, async: false

  alias Nerves.Artifact

  setup_all do
    {:ok, pid} = Nerves.TestServer.Router.start_link()
    [server: pid]
  end

  test "artifact resolver can download from open sites" do
    in_fixture("resolver", fn ->
      set_artifact_path()

      sites = [
        {:prefix, "http://127.0.0.1:4000/no_auth/"}
      ]

      pkg = %{app: :example, version: "0.1.0", path: "./", config: [artifact_sites: sites]}

      resolvers = Artifact.expand_sites(pkg)
      assert {:ok, _path} = Artifact.Resolver.get(resolvers, pkg)
    end)
  end

  test "artifact resolver can download using query param token auth" do
    in_fixture("resolver", fn ->
      set_artifact_path()

      sites = [
        {:prefix, "http://127.0.0.1:4000/token_auth/", query_params: %{"id" => 1234}}
      ]

      pkg = %{app: :example, version: "0.1.0", path: "./", config: [artifact_sites: sites]}

      resolvers = Artifact.expand_sites(pkg)
      assert {:ok, _path} = Artifact.Resolver.get(resolvers, pkg)
    end)
  end

  test "artifact resolver unauthorized using incorrect token auth" do
    in_fixture("resolver", fn ->
      set_artifact_path()

      sites = [
        {:prefix, "http://127.0.0.1:4000/token_auth/", query_params: %{"id" => 5678}}
      ]

      pkg = %{app: :example, version: "0.1.0", path: "./", config: [artifact_sites: sites]}

      resolvers = Artifact.expand_sites(pkg)
      assert {:error, _reason} = Artifact.Resolver.get(resolvers, pkg)
    end)
  end

  test "artifact resolver can download using authorization header" do
    in_fixture("resolver", fn ->
      set_artifact_path()
      token = Base.encode64("abcd:1234")

      sites = [
        {:prefix, "http://127.0.0.1:4000/header_auth/",
         headers: %{"Authorization" => "basic #{token}"}}
      ]

      pkg = %{app: :example, version: "0.1.0", path: "./", config: [artifact_sites: sites]}

      resolvers = Artifact.expand_sites(pkg)
      assert {:ok, _path} = Artifact.Resolver.get(resolvers, pkg)
    end)
  end

  test "artifact resolver unauthorized using incorrect authorization header" do
    in_fixture("resolver", fn ->
      set_artifact_path()
      token = Base.encode64("abcd:5678")

      sites = [
        {:prefix, "http://127.0.0.1:4000/header_auth/",
         headers: %{"Authorization" => "basic #{token}"}}
      ]

      pkg = %{app: :example, version: "0.1.0", path: "./", config: [artifact_sites: sites]}

      resolvers = Artifact.expand_sites(pkg)
      assert {:error, _} = Artifact.Resolver.get(resolvers, pkg)
    end)
  end

  test "github api validates required fields" do
    in_fixture("resolver", fn ->
      set_artifact_path()

      sites = [
        {:github_api, "my_org/my_repo", username: "my_user"}
      ]

      pkg = %{app: :example, version: "0.1.0", path: "./", config: [artifact_sites: sites]}
      resolvers = Artifact.expand_sites(pkg)

      assert_raise Mix.Error, fn ->
        Artifact.Resolver.get(resolvers, pkg)
      end

      sites = [
        {:github_api, "my_org/my_repo", token: "my_token"}
      ]

      pkg = %{app: :example, version: "0.1.0", path: "./", config: [artifact_sites: sites]}
      resolvers = Artifact.expand_sites(pkg)

      assert_raise Mix.Error, fn ->
        Artifact.Resolver.get(resolvers, pkg)
      end

      sites = [
        {:github_api, "my_org/my_repo", username: "my_username", token: "my_token"}
      ]

      pkg = %{app: :example, version: "0.1.0", path: "./", config: [artifact_sites: sites]}
      resolvers = Artifact.expand_sites(pkg)

      assert_raise Mix.Error, fn ->
        Artifact.Resolver.get(resolvers, pkg)
      end
    end)
  end

  defp set_artifact_path() do
    # Test tar file for artifact test server
    artifact_tar = Path.join([File.cwd!(), "artifact.tar.gz"])
    System.put_env("TEST_ARTIFACT_TAR", artifact_tar)
  end
end
