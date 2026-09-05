# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.ContainerTest do
  use ExUnit.Case, async: true

  alias Nerves.BuildPlan
  alias Nerves.Container

  @moduletag :tmp_dir

  test "workspace checksum does not depend on the artifact fingerprint", %{tmp_dir: tmp_dir} do
    dockerfile = Path.join(tmp_dir, "Dockerfile")
    source = Path.join(tmp_dir, "source")
    input = Path.join(source, "input")
    File.write!(dockerfile, "FROM scratch\n")
    File.mkdir!(source)
    File.write!(input, "contents")

    package = %{
      app: :test_package,
      deps: [],
      dockerfile: dockerfile,
      path: source,
      source_fingerprint: "OLD",
      artifact_source_files: [input]
    }

    build_plan = %BuildPlan{packages: [package]}
    checksum = Container.workspace_checksum(build_plan, package)
    changed_fingerprint = %{package | source_fingerprint: "NEW"}

    assert Container.workspace_checksum(build_plan, changed_fingerprint) == checksum
  end
end
