# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.ArtifactResolverTest do
  use ExUnit.Case, async: false

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

  @tag :tmp_dir
  test "validates an artifact with an OpenSSL signature", %{tmp_dir: tmp_dir} do
    archive_path = Path.join(tmp_dir, "artifact.tar.gz")
    signature_path = "#{archive_path}.sig"
    raw_signature_path = Path.join(tmp_dir, "artifact.sig.bin")
    private_key_path = Path.join(tmp_dir, "private.pem")
    public_key_path = Path.join(tmp_dir, "public.pem")
    artifact_path = Path.join(tmp_dir, "artifact")

    :ok =
      :erl_tar.create(String.to_charlist(archive_path), [{~c"artifact/file", "contents"}], [
        :compressed
      ])

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
            {:openssl_signature,
             filename: "artifact.tar.gz", public_keys: [File.read!(public_key_path)]},
            :archive
          ],
          extractors: [{:untar, source: archive_path, destination: artifact_path}],
          validated_files: []
        }
      ]
    }

    assert %BuildPlan{} = ArtifactResolver.resolve(build_plan)
    assert File.read!(Path.join(artifact_path, "file")) == "contents"
  end
end
