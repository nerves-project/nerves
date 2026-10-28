# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.ArtifactChecksumTest do
  use ExUnit.Case, async: false

  alias Nerves.Artifact.Checksum
  alias Nerves.ArtifactResolver
  alias Nerves.BuildPlan
  alias Nerves.BuildPlanHelpers

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    BuildPlanHelpers.reset_plan()
    package_path = Path.join(tmp_dir, "sources")
    File.mkdir_p!(package_path)
    archive_path = Path.join(tmp_dir, "artifact.tar.gz")

    :ok =
      :erl_tar.create(String.to_charlist(archive_path), [{~c"artifact/file", "contents"}], [
        :compressed
      ])

    package = %{
      BuildPlanHelpers.package_info(:test_system, package_path, Path.join(tmp_dir, "artifact"))
      | downloads: [
          %{
            archive_path: archive_path,
            filename: "artifact.tar.gz",
            sites: [],
            version: "1.0.0"
          }
        ],
        download_path: tmp_dir,
        download_validators: [
          {:checksum, filename: "artifact.tar.gz"},
          {:archive, filename: "artifact.tar.gz"}
        ],
        extractors: [
          {:untar, source: archive_path, destination: Path.join(tmp_dir, "artifact")}
        ]
    }

    plan = %BuildPlan{packages: [package]}
    :persistent_term.put({Nerves, :build_plan}, {plan, false})
    %{package: package, plan: plan, archive_path: archive_path}
  end

  test "generates a deterministic manifest and verifies before extraction", %{
    package: package,
    plan: plan,
    archive_path: archive_path
  } do
    run_task([])
    manifest_path = Path.join(package.path, "checksum.exs")
    manifest = File.read!(manifest_path)

    expected =
      "sha256:" <> Base.encode16(:crypto.hash(:sha256, File.read!(archive_path)), case: :lower)

    assert Checksum.read!(manifest_path) == %{"artifact.tar.gz" => expected}
    refute File.exists?(package.artifact_path)

    run_task([])
    assert File.read!(manifest_path) == manifest
    assert ^plan = ArtifactResolver.resolve(plan)
    assert File.read!(Path.join(package.artifact_path, "file")) == "contents"
  end

  test "selects only the requested package, downloads missing archives, and omits signatures", %{
    package: package,
    archive_path: archive_path,
    tmp_dir: tmp_dir
  } do
    remote_path = Path.join(tmp_dir, "remote")
    File.mkdir_p!(remote_path)
    File.rename!(archive_path, Path.join(remote_path, "artifact.tar.gz"))

    [download] = package.downloads
    download = %{download | sites: [{:prefix, remote_path}]}

    signature_download = %{
      download
      | filename: "artifact.tar.gz.sig",
        archive_path: "#{archive_path}.sig",
        sites: []
    }

    package = %{package | downloads: [download, signature_download]}
    unrelated = BuildPlanHelpers.package_info(:unrelated, "/unreachable", "/unreachable")
    plan = %BuildPlan{packages: [package, unrelated]}
    :persistent_term.put({Nerves, :build_plan}, {plan, false})

    run_task(["test_system"])
    assert File.exists?(archive_path)

    assert Map.keys(Checksum.read!(Path.join(package.path, "checksum.exs"))) == [
             "artifact.tar.gz"
           ]

    refute File.exists?(signature_download.archive_path)
  end

  test "checksums all planned archives in checksum.exs", %{
    package: package,
    archive_path: archive_path
  } do
    second_path = Path.join(package.download_path, "second.tar.gz")
    File.cp!(archive_path, second_path)
    [download] = package.downloads

    package = %{
      package
      | downloads: [
          %{download | filename: "second.tar.gz", archive_path: second_path},
          download
        ],
        extractors: [
          {:untar, source: second_path, destination: "#{package.artifact_path}-second"}
          | package.extractors
        ],
        download_validators: [
          {:checksum, filename: "second.tar.gz"} | package.download_validators
        ]
    }

    :persistent_term.put({Nerves, :build_plan}, {%BuildPlan{packages: [package]}, false})
    run_task([])
    manifest_path = Path.join(package.path, "checksum.exs")
    assert map_size(Checksum.read!(manifest_path)) == 2
    assert File.read!(manifest_path) =~ ~r/artifact.tar.gz.*\n.*second.tar.gz/
  end

  test "leaves an existing manifest untouched when an archive is unavailable", %{
    package: package,
    archive_path: archive_path
  } do
    manifest_path = Path.join(package.path, "checksum.exs")
    File.write!(manifest_path, "original")
    missing_path = "#{archive_path}.missing"
    [download] = package.downloads

    package = %{
      package
      | downloads: [
          download,
          %{download | filename: "missing.tar.gz", archive_path: missing_path}
        ],
        extractors: package.extractors ++ [{:untar, source: missing_path}]
    }

    :persistent_term.put({Nerves, :build_plan}, {%BuildPlan{packages: [package]}, false})

    assert_raise Mix.Error, ~r/Could not download/, fn -> run_task([]) end
    assert File.read!(manifest_path) == "original"
  end

  test "rejects a downloaded error page without overwriting the manifest", %{
    package: package,
    archive_path: archive_path,
    tmp_dir: tmp_dir
  } do
    remote_path = Path.join(tmp_dir, "remote")
    File.mkdir_p!(remote_path)
    File.write!(Path.join(remote_path, "artifact.tar.gz"), "<html>Not found</html>")
    File.rm!(archive_path)
    manifest_path = Path.join(package.path, "checksum.exs")
    File.write!(manifest_path, "original")
    [download] = package.downloads
    package = %{package | downloads: [%{download | sites: [{:prefix, remote_path}]}]}
    :persistent_term.put({Nerves, :build_plan}, {%BuildPlan{packages: [package]}, false})

    assert_raise Mix.Error, ~r/Invalid artifact/, fn -> run_task([]) end
    assert File.read!(manifest_path) == "original"
  end

  test "reports packages without archives", %{package: package} do
    plan = %BuildPlan{packages: [%{package | extractors: []}]}
    :persistent_term.put({Nerves, :build_plan}, {plan, false})
    assert_raise Mix.Error, ~r/No artifact archives/, fn -> run_task([]) end
  end

  defp run_task(args) do
    Mix.Task.reenable("nerves.artifact.checksum")
    Mix.Task.run("nerves.artifact.checksum", args)
  end
end
