# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.ArtifactResolverTest do
  use ExUnit.Case, async: false

  alias Nerves.Artifact.Checksum
  alias Nerves.ArtifactResolver
  alias Nerves.BuildPlan

  @tag :tmp_dir
  test "uses a locally built artifact with its source fingerprint", %{tmp_dir: tmp_dir} do
    artifact_path = Path.join(tmp_dir, "test_system-1.0.0")
    File.mkdir_p!(artifact_path)
    File.write!(Path.join(artifact_path, ".fingerprint"), "ABC1234")

    build_plan = %BuildPlan{
      packages: [
        %{
          app: :test_system,
          artifact_path: artifact_path,
          source_fingerprint: "ABC1234",
          downloads: [
            %{archive_path: "/unreachable", filename: "unreachable", sites: [], version: "1.0.0"}
          ],
          extractors: [],
          validated_files: []
        }
      ]
    }

    assert ^build_plan = ArtifactResolver.resolve(build_plan)
  end

  describe "checksum validation" do
    @describetag :tmp_dir

    setup %{tmp_dir: tmp_dir} do
      archive_path = Path.join(tmp_dir, "artifact.tar.gz")
      File.cp!("test/fixtures/resolver/artifact.tar.gz", archive_path)
      package_path = Path.join(tmp_dir, "sources")
      File.mkdir_p!(package_path)
      manifest_path = Path.join(package_path, "checksum.exs")
      Checksum.write!(manifest_path, %{"artifact.tar.gz" => Checksum.checksum!(archive_path)})

      package = %{
        app: :test_system,
        path: package_path,
        artifact_path: Path.join(tmp_dir, "extracted"),
        download_path: tmp_dir,
        source_fingerprint: "ABC1234",
        downloads: [
          %{archive_path: archive_path, filename: "artifact.tar.gz", sites: [], version: "1.0.0"}
        ],
        download_validators: [
          {:checksum, filename: "artifact.tar.gz"},
          {:archive, filename: "artifact.tar.gz"}
        ],
        extractors: [
          {:untar, source: archive_path, destination: Path.join(tmp_dir, "extracted")}
        ]
      }

      %{
        plan: %BuildPlan{packages: [package]},
        package: package,
        archive_path: archive_path,
        manifest_path: manifest_path
      }
    end

    test "rejects a tampered cached archive before touching the destination", context do
      :ok =
        :erl_tar.create(
          String.to_charlist(context.archive_path),
          [{~c"artifact/file", "tampered"}],
          [:compressed]
        )

      File.mkdir_p!(context.package.artifact_path)
      marker = Path.join(context.package.artifact_path, "existing")
      File.write!(marker, "keep")

      assert_raise Mix.Error, ~r/Checksum mismatch/, fn ->
        ArtifactResolver.resolve(context.plan)
      end

      assert File.read!(marker) == "keep"
      refute File.exists?(Path.join(context.package.artifact_path, ".fingerprint"))
    end

    test "rejects missing manifests and missing entries", context do
      File.rm!(context.manifest_path)

      assert_raise Mix.Error, ~r/Could not read checksum manifest/, fn ->
        ArtifactResolver.resolve(context.plan)
      end

      File.write!(context.manifest_path, "%{}")

      assert_raise Mix.Error, ~r/No checksum for artifact.tar.gz/, fn ->
        ArtifactResolver.resolve(context.plan)
      end

      refute File.exists?(context.package.artifact_path)
    end

    test "rejects malformed or executable manifests without evaluating them", context do
      marker = Path.join(context.package.path, "executed")

      for contents <- [
            "File.touch!(#{inspect(marker)}); %{}",
            "%{\"artifact.tar.gz\" => \"sha256:invalid\"}",
            "%{\"artifact.tar.gz\" => \"md5:#{String.duplicate("0", 32)}\"}",
            "not a map"
          ] do
        File.write!(context.manifest_path, contents)

        assert_raise Mix.Error, ~r/Invalid checksum manifest/, fn ->
          ArtifactResolver.resolve(context.plan)
        end
      end

      refute File.exists?(marker)
      refute File.exists?(context.package.artifact_path)
    end
  end

  @tag :tmp_dir
  test "validates an artifact with an OpenSSL signature", %{tmp_dir: tmp_dir} do
    archive_path = Path.join(tmp_dir, "artifact.tar.gz")
    signature_path = "#{archive_path}.sig"
    raw_signature_path = Path.join(tmp_dir, "artifact.sig.bin")
    private_key_path = Path.join(tmp_dir, "private.pem")
    public_key_path = Path.join(tmp_dir, "public.pem")
    artifact_path = Path.join(tmp_dir, "artifact")
    manifest_path = Path.join(tmp_dir, "checksum.exs")

    :ok =
      :erl_tar.create(String.to_charlist(archive_path), [{~c"artifact/file", "contents"}], [
        :compressed
      ])

    Checksum.write!(manifest_path, %{"artifact.tar.gz" => Checksum.checksum!(archive_path)})

    assert {_, 0} =
             System.cmd("openssl", ["genrsa", "-out", private_key_path, "2048"],
               stderr_to_stdout: true
             )

    assert {_, 0} =
             System.cmd(
               "openssl",
               ["rsa", "-in", private_key_path, "-pubout", "-out", public_key_path],
               stderr_to_stdout: true
             )

    assert {_, 0} =
             System.cmd(
               "openssl",
               [
                 "dgst",
                 "-sha256",
                 "-sign",
                 private_key_path,
                 "-out",
                 raw_signature_path,
                 archive_path
               ],
               stderr_to_stdout: true
             )

    assert {_, 0} =
             System.cmd("openssl", ["base64", "-in", raw_signature_path, "-out", signature_path],
               stderr_to_stdout: true
             )

    build_plan = %BuildPlan{
      packages: [
        %{
          app: :test_system,
          path: tmp_dir,
          artifact_path: artifact_path,
          download_path: tmp_dir,
          source_fingerprint: "ABC1234",
          downloads: [
            %{
              archive_path: archive_path,
              filename: "artifact.tar.gz",
              sites: [],
              version: "1.0.0"
            }
          ],
          download_validators: [
            {:checksum, filename: "artifact.tar.gz"},
            {:openssl_signature,
             filename: "artifact.tar.gz", public_keys: [File.read!(public_key_path)]},
            {:archive, filename: "artifact.tar.gz"}
          ],
          extractors: [{:untar, source: archive_path, destination: artifact_path}],
          validated_files: []
        }
      ]
    }

    assert %BuildPlan{} = ArtifactResolver.resolve(build_plan)
    assert File.read!(Path.join(artifact_path, "file")) == "contents"

    File.rm!(Path.join(artifact_path, ".fingerprint"))
    File.write!(signature_path, Base.encode64("invalid"))

    assert_raise Mix.Error, ~r/Invalid OpenSSL signature/, fn ->
      ArtifactResolver.resolve(build_plan)
    end

    File.write!(
      manifest_path,
      "%{\"artifact.tar.gz\" => \"sha256:#{String.duplicate("0", 64)}\"}"
    )

    assert_raise Mix.Error, ~r/Checksum mismatch/, fn ->
      ArtifactResolver.resolve(build_plan)
    end
  end
end
