# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildAction.NervesV1System do
  @moduledoc false

  use Nerves.BuildAction
  alias Nerves.BuildPlan

  @impl Nerves.BuildAction
  def pre_download(build_plan, opts) do
    app = Keyword.fetch!(opts, :app)
    artifact_sites = Keyword.fetch!(opts, :artifact_sites)
    package = BuildPlan.find_package(build_plan, app)
    rootfs_inputs = build_plan.config[:rootfs_inputs] || []

    artifact_path = maybe_override_artifact_path("NERVES_SYSTEM", package.artifact_path)

    package =
      if artifact_path == package.artifact_path do
        archive_name =
          "#{app}-portable-#{package.version}-#{package.source_fingerprint}.tar.gz"

        archive_path = Path.join(package.download_path, archive_name)

        Map.merge(package, %{
          download_validators: [:archive],
          downloads: [
            %{
              archive_path: archive_path,
              filename: archive_name,
              sites: artifact_sites,
              version: package.version
            }
          ],
          extractors: [{:untar, source: archive_path, destination: artifact_path}],
          build_script: generate_build_script(package),
          shell_setup_script: generate_shell_setup_script(package)
        })
      else
        Map.merge(package, %{
          artifact_path: artifact_path,
          download_validators: [],
          downloads: [],
          extractors: [],
          build_script: generate_build_script(package),
          shell_setup_script: generate_shell_setup_script(package)
        })
      end

    package_env = opts[:package_env] || []

    system_config = %{
      fwup_conf: Path.join(package.artifact_path, "images/fwup.conf"),
      fwup_provisioning_conf:
        Path.join(package.artifact_path, "images/fwup_include/provisioning.conf"),
      rootfs_inputs: [Path.join(package.artifact_path, "images/rootfs.tar") | rootfs_inputs]
    }

    actions =
      [
        Nerves.BuildAction.IExStartupCheck,
        {Nerves.BuildAction.Erlinit,
         base_erlinit_conf: Path.join(package.path, "rootfs_overlay/etc/erlinit.config"),
         shoehorn?: Map.has_key?(Mix.Project.deps_tree(), :shoehorn)},
        {Nerves.BuildAction.SortApps, []},
        {Nerves.BuildAction.AppModes, []},
        Nerves.BuildAction.Trimmer,
        Nerves.BuildAction.CheckExecutables,
        Nerves.BuildAction.StripAll,
        {Nerves.BuildAction.Rootfs, []},
        {Nerves.BuildAction.Firmware, []}
      ]

    build_plan
    |> BuildPlan.replace_package(package)
    |> BuildPlan.merge_env(system_env())
    |> BuildPlan.merge_env(package_env)
    |> BuildPlan.merge_config(system_config)
    |> Map.put(:actions, actions ++ build_plan.actions)
  end

  @impl Nerves.BuildAction
  def post_extract(build_plan, opts) do
    app = Keyword.fetch!(opts, :app)
    package = BuildPlan.find_package(build_plan, app)

    build_plan
    |> ensure_rootfs_tar(package.artifact_path)
    |> discover_system(package.artifact_path)
  end

  defp maybe_override_artifact_path(env_var_override, default_path) do
    case System.get_env(env_var_override) do
      nil ->
        default_path

      "" ->
        default_path

      path ->
        if File.dir?(path) do
          path
        else
          Mix.raise("$#{env_var_override} must point to an extracted artifact directory")
        end
    end
  end

  defp discover_system(build_plan, system_path) do
    sysroot = Path.join(system_path, "staging")
    erts_dir = glob_first!(Path.join(sysroot, "usr/lib/erlang/erts-*"), "ERTS")

    build_plan
    |> BuildPlan.merge_env(%{
      "NERVES_SYSTEM" => system_path,
      "ERTS_DIR" => erts_dir,
      "ERL_INTERFACE_DIR" =>
        glob_first!(Path.join(sysroot, "usr/lib/erlang/lib/erl_interface-*"), "erl_interface")
    })
    |> Map.put(:erts, erts_dir)
  end

  defp ensure_rootfs_tar(build_plan, system_path) do
    rootfs_tar_path = Path.join(system_path, "images/rootfs.tar")

    if not File.exists?(rootfs_tar_path) do
      rootfs_squashfs_path = Path.join(system_path, "images/rootfs.squashfs")

      if not File.exists?(rootfs_squashfs_path) do
        Mix.raise(
          "Nerves system doesn't include images/rootfs.tar or images/rootfs.squashfs. Check if it's corrupt."
        )
      end

      squashfs_to_tar!(rootfs_squashfs_path, rootfs_tar_path)
    end

    build_plan
  end

  defp generate_build_script(package) do
    if :nerves_system_br in package.deps do
      """
      set -e
      /workspace/nerves_system_br/create-build.sh /workspace/#{package.app}/nerves_defconfig /workspace/build
      make
      make system NERVES_ARTIFACT_NAME=$NERVES_ARTIFACT_NAME
      """
    else
      ""
    end
  end

  defp generate_shell_setup_script(package) do
    if :nerves_system_br in package.deps do
      """
      set -e

      echo "Creating the build directory..."

      /workspace/nerves_system_br/create-build.sh /workspace/#{package.app}/nerves_defconfig /workspace/build
      """
    else
      ""
    end
  end

  defp system_env() do
    [
      {"NERVES_SDK_SYSROOT", "${NERVES_SYSTEM}/staging"},
      {"NERVES_SDK_IMAGES", "${NERVES_SYSTEM}/images"},
      {"REBAR_PLT_DIR", "${NERVES_SDK_SYSROOT}/usr/lib/erlang"},
      {"ERL_LIB_DIR", "${NERVES_SDK_SYSROOT}/usr/lib/erlang"},
      {"ERL_SYSTEM_LIB_DIR", "${NERVES_SDK_SYSROOT}/usr/lib/erlang/lib"},
      {"CFLAGS",
       "${TARGET_GCC_FLAGS} -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64  -pipe -O2 --sysroot ${NERVES_SDK_SYSROOT}"},
      {"CPPFLAGS",
       "-D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 --sysroot ${NERVES_SDK_SYSROOT}"},
      {"CXXFLAGS",
       "${TARGET_GCC_FLAGS} -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64  -pipe -O2 --sysroot ${NERVES_SDK_SYSROOT}"},
      {"LDFLAGS", "--sysroot=${NERVES_SDK_SYSROOT}"},
      {"ERL_CFLAGS", "-I${ERTS_DIR}/include -I${ERL_INTERFACE_DIR}/include"},
      {"ERL_LDFLAGS", "-L${ERL_INTERFACE_DIR}/lib -lei"},
      {"ERTS_INCLUDE_DIR", "${ERTS_DIR}/include"},
      {"ERL_EI_LIBDIR", "${ERL_INTERFACE_DIR}/lib"},
      {"ERL_EI_INCLUDE_DIR", "${ERL_INTERFACE_DIR}/include"},
      {"ERL_INTERFACE_LIB_DIR", "${ERL_INTERFACE_DIR}/lib"},
      {"ERL_INTERFACE_INCLUDE_DIR", "${ERL_INTERFACE_DIR}/include"},
      {"PKG_CONFIG_SYSROOT_DIR", "${NERVES_SDK_SYSROOT}"},
      {"PKG_CONFIG_LIBDIR", "${NERVES_SDK_SYSROOT}/usr/lib/pkgconfig"},
      {"PKG_CONFIG_PATH", ""},
      {"CMAKE_TOOLCHAIN_FILE", "${NERVES_SYSTEM}/nerves-env.cmake"}
    ]
  end

  defp glob_first!(pattern, description) do
    case Path.wildcard(pattern) do
      [path | _] -> path
      [] -> Mix.raise("Could not find #{description} under #{Path.dirname(pattern)}")
    end
  end

  defp squashfs_to_tar!(squashfs_path, tar_path) do
    if !System.find_executable("sqfs2tar") do
      Mix.raise("""
      Nerves systems should now include a rootfs.tar rather than a rootfs.squashfs.

      Could not convert #{squashfs_path}.

      If you're able to update the Nerves package that has this file, then that's the best
      solution. That could either be bumping the version or modifying the `nerves_defconfig`
      to add `BR2_TARGET_ROOTFS_TAR=y`.

      Alternatively Nerves can automatically convert the rootfs.squashfs to a rootfs.tar.
      To do this, it needs `sqfs2tar` which is a part of `squashfs-tools-ng`. See
      https://github.com/AgentD/squashfs-tools-ng for installation instructions.
      """)
    end

    case System.shell("sqfs2tar #{escape(squashfs_path)} > #{escape(tar_path)}") do
      {_, 0} ->
        :ok

      {output, code} ->
        Mix.raise("sqfs2tar failed on #{squashfs_path} (exit #{code}):\n#{output}")
    end
  end

  defp escape(path) do
    # Shell-escape paths for use in System.shell/2
    "'" <> String.replace(path, "'", "'\\''") <> "'"
  end
end
