# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.LegacyPackage do
  @moduledoc false

  alias Nerves.BuildPlan
  alias Nerves.MixPackage

  @supported_types [:system, :toolchain]
  defmodule LegacyAction do
    @moduledoc false

    use Nerves.BuildAction

    @impl Nerves.BuildAction
    def post_extract(build_plan, opts) do
      Nerves.LegacyPackage.apply_legacy_package(build_plan, opts)
    end
  end

  @spec convert(MixPackage.t(), BuildPlan.package_info()) :: keyword()
  def convert(%MixPackage{} = package, package_plan) do
    legacy_config = package.config[:nerves_package] || []

    case legacy_config[:type] do
      type when type in @supported_types ->
        env_var_override = legacy_config[:env_var_override] || default_env_var(type)
        artifact_path = maybe_override_artifact_path(env_var_override, package_plan.artifact_path)
        overridden? = artifact_path != package_plan.artifact_path

        {download_name, extension} =
          artifact_name(
            package.app,
            package.config[:version],
            package_plan.source_fingerprint,
            type
          )

        download_path = Path.join(package_plan.download_path, download_name <> extension)
        package_env = package_env(legacy_config[:env], type)

        [
          packages: [
            package_plan
            |> Map.put(:artifact_path, artifact_path)
            |> Map.put(:download_validators, if(overridden?, do: [], else: [:archive]))
            |> Map.put(
              :downloads,
              if(overridden?,
                do: [],
                else: [
                  %{
                    archive_path: download_path,
                    filename: Path.basename(download_path),
                    sites: legacy_config[:artifact_sites] || [],
                    version: package.config[:version]
                  }
                ]
              )
            )
            |> Map.put(
              :extractors,
              if(overridden?,
                do: [],
                else: [{:untar, source: download_path, destination: artifact_path}]
              )
            )
            |> Map.put(:build_script, generate_build_script(package_plan))
            |> Map.put(:shell_setup_script, generate_shell_setup_script(package_plan))
          ],
          env: env_var_env(env_var_override, artifact_path),
          actions: [
            {LegacyAction,
             type: type,
             dest: package.dest,
             artifact_path: artifact_path,
             package_env: package_env}
          ]
        ]

      _ ->
        []
    end
  end

  defp artifact_name(app, version, fingerprint, :system) do
    {"#{app}-portable-#{version}-#{fingerprint}", ".tar.gz"}
  end

  defp artifact_name(app, version, fingerprint, :toolchain) do
    host = "#{host_os()}_#{host_arch()}" |> normalize_host_tuple()

    {"#{app}-#{host}-#{version}-#{fingerprint}", ".tar.xz"}
  end

  defp host_os() do
    {_, type} = :os.type()
    to_string(type)
  end

  defp host_arch() do
    :erlang.system_info(:system_architecture)
    |> to_string()
    |> String.split("-")
    |> List.first()
  end

  defp normalize_host_tuple("darwin_aarch64"), do: "darwin_arm"
  defp normalize_host_tuple(host), do: host

  defp maybe_override_artifact_path(env_var_override, default_path) do
    case env_var_override && System.get_env(env_var_override) do
      nil ->
        default_path

      "" ->
        default_path

      path ->
        if File.dir?(path) do
          path
        else
          Mix.raise("#{env_var_override} must point to an extracted artifact directory")
        end
    end
  end

  @spec apply_legacy_package(BuildPlan.t(), keyword()) :: BuildPlan.t()
  def apply_legacy_package(%BuildPlan{} = build_plan, opts) do
    type = opts[:type]
    artifact_path = opts[:artifact_path]
    package_env = opts[:package_env]
    dest = opts[:dest]

    build_plan
    |> maybe_discover_toolchain(type, artifact_path)
    |> maybe_discover_system(type, artifact_path, dest)
    |> merge_package_env(package_env)
  end

  defp env_var_env(env_var_override, artifact_path), do: %{env_var_override => artifact_path}

  defp maybe_discover_toolchain(build_plan, :toolchain, toolchain_path) do
    bin_path = Path.join(toolchain_path, "bin")

    crosscompile =
      bin_path
      |> Path.join("*-gcc")
      |> Path.wildcard()
      |> choose_crosscompile()

    if is_nil(crosscompile) do
      Mix.raise("Could not find a cross-compiler in #{bin_path}")
    end

    current_path = Map.get(build_plan.env, "PATH", "")

    path =
      if bin_path in String.split(current_path, ":") do
        current_path
      else
        "#{bin_path}:#{current_path}"
      end

    BuildPlan.merge_env(build_plan, %{
      "PATH" => path,
      "CROSSCOMPILE" => crosscompile,
      "REBAR_TARGET_ARCH" => Path.basename(crosscompile)
    })
  end

  defp maybe_discover_toolchain(build_plan, _type, _path), do: build_plan

  defp maybe_discover_system(build_plan, :system, system_path, dest) do
    sysroot = Path.join(system_path, "staging")
    other_rootfs_inputs = build_plan.config[:rootfs_inputs] || []

    erts_dir = glob_first!(Path.join(sysroot, "usr/lib/erlang/erts-*"), "ERTS")

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

    erlinit_action =
      {Nerves.BuildAction.Erlinit,
       base_erlinit_conf: Path.join(dest, "rootfs_overlay/etc/erlinit.config"),
       shoehorn?: Map.has_key?(Mix.Project.deps_tree(), :shoehorn)}

    build_plan
    |> BuildPlan.merge_env(%{
      "ERTS_DIR" => erts_dir,
      "ERL_INTERFACE_DIR" =>
        glob_first!(Path.join(sysroot, "usr/lib/erlang/lib/erl_interface-*"), "erl_interface")
    })
    |> BuildPlan.merge_config(%{
      fwup_conf: Path.join(system_path, "images/fwup.conf"),
      fwup_provisioning_conf: Path.join(system_path, "images/fwup_include/provisioning.conf"),
      rootfs_inputs: [Path.join(system_path, "images/rootfs.tar") | other_rootfs_inputs]
    })
    |> Map.put(:actions, [erlinit_action | build_plan.actions])
    |> Map.put(:erts, erts_dir)
  end

  defp maybe_discover_system(build_plan, _type, _path, _dest), do: build_plan

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

  defp default_env_var(:system), do: "NERVES_SYSTEM"
  defp default_env_var(:toolchain), do: "NERVES_TOOLCHAIN"

  defp package_env(nil, :toolchain), do: toolchain_env()
  defp package_env(nil, :system), do: system_env()
  defp package_env(env, :toolchain), do: env ++ toolchain_env()
  defp package_env(env, :system), do: env ++ system_env()

  defp toolchain_env() do
    [
      {"CC", "${CROSSCOMPILE}-gcc"},
      {"CXX", "${CROSSCOMPILE}-g++"},
      {"AR", "${CROSSCOMPILE}-ar"},
      {"AS", "${CROSSCOMPILE}-as"},
      {"LD", "${CROSSCOMPILE}-ld"},
      {"STRIP", "${CROSSCOMPILE}-strip"}
    ]
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
      {"CMAKE_TOOLCHAIN_FILE", "${NERVES_SYSTEM}/nerves-env.cmake"},
      {"AR_FOR_BUILD", "ar"},
      {"AS_FOR_BUILD", "as"},
      {"CC_FOR_BUILD", "cc"},
      {"GCC_FOR_BUILD", "gcc"},
      {"CXX_FOR_BUILD", "g++"},
      {"LD_FOR_BUILD", "ld"},
      {"CPPFLAGS_FOR_BUILD", ""},
      {"CFLAGS_FOR_BUILD", ""},
      {"CXXFLAGS_FOR_BUILD", ""},
      {"LDFLAGS_FOR_BUILD", ""}
    ]
  end

  defp merge_package_env(build_plan, env) do
    Enum.reduce(env, build_plan, fn {key, value}, plan ->
      BuildPlan.merge_env(plan, %{key => interpolate(value, plan.env)})
    end)
  end

  defp interpolate(value, env) do
    Regex.replace(~r/\$\{([^}]+)\}/, value, fn _match, variable ->
      Map.get(env, variable, "")
    end)
  end

  defp choose_crosscompile([]), do: nil

  defp choose_crosscompile(gcc_paths) do
    gcc_paths
    |> Enum.find(List.first(gcc_paths), &String.contains?(&1, "buildroot"))
    |> String.replace_suffix("-gcc", "")
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
