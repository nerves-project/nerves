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
    File.write!(Path.join(artifact_path, "CHECKSUM"), "ABC1234")

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
end
