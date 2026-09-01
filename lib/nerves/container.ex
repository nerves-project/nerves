# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-FileCopyrightText: 2026 Thomas Winkler
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Container do
  @moduledoc """
  Helpers for managing containers
  """

  alias Nerves.BuildPlan
  alias Nerves.Paths

  @apple_container_default_volume_size "128G"

  @doc """
  Return the locally cached image built from a package Dockerfile.
  """
  @spec package_image!(String.t(), BuildPlan.package_info()) :: String.t()
  def package_image!(tool, %{dockerfile: dockerfile} = package) when is_binary(dockerfile) do
    ensure_tool_running!(tool)

    if not File.regular?(dockerfile) do
      Mix.raise("Dockerfile for #{package.app} does not exist: #{dockerfile}")
    end

    image = dockerfile_image_name(dockerfile, package)

    if not image_exists?(tool, image) do
      build_image!(tool, image, dockerfile)
    end

    image
  end

  def package_image!(_tool, package) do
    Mix.raise("""
    #{package.app} does not specify a Dockerfile.

    Add `dockerfile: "Dockerfile"` to its `:nerves` configuration.
    """)
  end

  @doc false
  @spec legacy_system_dockerfile() :: Path.t()
  def legacy_system_dockerfile() do
    Path.join(:code.priv_dir(:nerves), "artifact/Dockerfile")
  end

  @doc false
  @spec prepare_artifact_workspace!(BuildPlan.t(), BuildPlan.package_info()) ::
          {String.t(), String.t(), Path.t()}
  def prepare_artifact_workspace!(build_plan, package) do
    dl_dir = Paths.download_dir()
    File.mkdir_p!(package.download_path)

    tool = tool()
    image = package_image!(tool, package)

    Mix.shell().info("Preparing container workspace...")
    ensure_work_dir(tool, package)
    populate_work_dir(build_plan, tool, package, image)

    {tool, image, dl_dir}
  end

  @doc false
  @spec artifact_run_args(
          BuildPlan.t(),
          BuildPlan.package_info(),
          String.t(),
          String.t(),
          Path.t(),
          [String.t()]
        ) :: [String.t()]
  def artifact_run_args(build_plan, package, tool, image, dl_dir, command \\ []) do
    artifact_dir = Path.relative_to(package.download_path, dl_dir)
    term = System.get_env("TERM") || "xterm-256color"

    [
      "run",
      "--rm",
      "-it"
    ] ++
      container_user_args(tool) ++
      resource_args(tool) ++
      [
        "--env",
        "NERVES_BR_DL_DIR=/workspace/dl",
        "--env",
        "TERM=#{term}",
        "--env",
        "NERVES_ARTIFACT_APP=#{package.app}",
        "--env",
        "NERVES_ARTIFACT_VERSION=#{package.version}",
        "--env",
        "NERVES_ARTIFACT_SOURCE_FINGERPRINT=#{package.source_fingerprint}",
        "--env",
        "NERVES_ARTIFACT_DIR=/workspace/dl/#{artifact_dir}",
        "--env",
        "NERVES_HOST_TUPLE=#{Nerves.TargetTuple.host_string(build_plan.config[:host_tuple])}"
      ] ++
      work_mount_args(tool, package) ++
      download_mount_args(tool, dl_dir) ++
      [
        "-w",
        "/workspace/build",
        image
      ] ++ command
  end

  @doc """
  Return the container tool to use for builds

  Set `NERVES_CONTAINER_TOOL` to `"container"`, `"podman"`, or `"docker"` to
  override. On Apple Silicon, Apple's `container` CLI is preferred when it is
  installed; Nerves starts its service when needed.
  """
  @spec tool() :: String.t()
  def tool() do
    override = System.get_env("NERVES_CONTAINER_TOOL")

    cond do
      override == "container" -> "container"
      override == "podman" -> "podman"
      override == "docker" -> "docker"
      apple_container_available?() -> "container"
      tool_running?("podman") -> "podman"
      tool_running?("docker") -> "docker"
      true -> "docker"
    end
  end

  # Returns true if the tool is installed and its daemon/VM is reachable.
  defp tool_running?(tool) do
    System.find_executable(tool) != nil and
      match?({_, 0}, System.cmd(tool, ["info"], stderr_to_stdout: true))
  end

  defp apple_container_available?() do
    match?({:unix, :darwin}, :os.type()) and
      match?("aarch64" <> _, to_string(:erlang.system_info(:system_architecture))) and
      System.find_executable("container") != nil
  end

  @doc """
  Return user/namespace args for the container run command.

  The flags vary by tool and OS:

  * **Podman (any OS)** — adds `--userns=keep-id`, which maps the calling
    user's uid into the container's user namespace. Without this, Podman's
    user namespace remapping strips permissions from bind-mounted files during
    tar extraction (manifesting as 000 instead of 644).

  * **Linux** — adds `--user UID:GID` so that files written to host
    bind-mounted directories are owned by the calling user, not by the
    container's `nerves` user (uid=1005).

  * **Docker on macOS** — no flags needed; Docker Desktop's virtiofs layer
    remaps uids transparently and the Dockerfile's `USER nerves` is correct.
  """
  @spec container_user_args(String.t()) :: [String.t()]
  def container_user_args(tool) do
    podman? = String.contains?(tool, "podman")
    linux? = match?({:unix, :linux}, :os.type())

    userns_args = if podman?, do: ["--userns=keep-id"], else: []

    user_args =
      if linux? do
        {uid, 0} = System.cmd("id", ["-u"])
        {gid, 0} = System.cmd("id", ["-g"])
        ["--user", "#{String.trim(uid)}:#{String.trim(gid)}"]
      else
        []
      end

    userns_args ++ user_args
  end

  @doc """
  Return the container volume name for a package's work directory.

  Only used on macOS where bind mounts are slow. On Linux the work
  directory is a regular host path under `_build`.
  """
  @spec volume_name(BuildPlan.package_info()) :: String.t()
  def volume_name(%{app: app}) when is_atom(app), do: "nerves-work-#{app}"

  @doc """
  Return the host-side work directory path for a package.

  On Linux, the build container bind-mounts this directory at `/workspace`.
  The path lives under the Elixir project's `_build` directory so it is
  scoped to the project and ignored by version control.
  """
  @spec work_dir(BuildPlan.package_info()) :: String.t()
  def work_dir(%{app: app}) when is_atom(app) do
    Mix.Project.build_path()
    |> Path.join("nerves")
    |> Path.join(to_string(app))
    |> Path.expand()
  end

  @doc """
  Return docker mount arguments for the work directory.

  On Linux, returns a bind mount from the host work directory.
  On macOS, returns a container volume mount.
  """
  @spec work_mount_args(String.t(), BuildPlan.package_info()) :: [String.t()]
  def work_mount_args(tool, pkg) do
    case :os.type() do
      {:unix, :linux} ->
        host_path = work_dir(pkg)
        ["-v", "#{host_path}:/workspace"]

      _ ->
        vol = volume_name(pkg)
        ensure_volume(tool, vol)
        volume_mount_args(tool, vol, "/workspace")
    end
  end

  @doc """
  Return mount arguments for a host download directory.
  """
  @spec download_mount_args(String.t(), Path.t()) :: [String.t()]
  def download_mount_args("container", path) do
    ["--mount", "type=bind,source=#{Path.expand(path)},target=/workspace/dl"]
  end

  def download_mount_args(_tool, path), do: ["-v", "#{path}:/workspace/dl"]

  @doc """
  Return Apple container VM resource arguments.

  Apple's default container VM has too little memory for Buildroot. Allocate
  all host schedulers and half the host RAM (at least 8 GB), unless overridden
  by `NERVES_CONTAINER_CPUS` or `NERVES_CONTAINER_MEMORY`.
  """
  @spec resource_args(String.t()) :: [String.t()]
  def resource_args("container") do
    cpus = System.get_env("NERVES_CONTAINER_CPUS") || to_string(System.schedulers_online())

    memory =
      System.get_env("NERVES_CONTAINER_MEMORY") || "#{max(div(host_memory_gb(), 2), 8)}G"

    ["--cpus", cpus, "--memory", memory]
  end

  def resource_args(_tool), do: []

  @doc """
  Ensure the work directory or volume exists.

  On Linux, creates the host-side directory tree.
  On macOS, creates the container volume.
  """
  @spec ensure_work_dir(String.t(), BuildPlan.package_info()) :: :ok
  def ensure_work_dir(tool, package) do
    ensure_tool_running!(tool)

    case :os.type() do
      {:unix, :linux} ->
        host_path = work_dir(package)
        File.mkdir_p!(Path.join(host_path, to_string(package.app)))
        File.mkdir_p!(Path.join(host_path, "build"))

        for dep <- package.deps do
          File.mkdir_p!(Path.join(host_path, to_string(dep)))
        end

        :ok

      _ ->
        ensure_volume(tool, volume_name(package))
    end
  end

  defp ensure_tool_running!("container") do
    case System.cmd("container", ["system", "status"], stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      _ ->
        Mix.shell().info("Starting Apple container system service")

        case System.cmd(
               "container",
               ["system", "start", "--enable-kernel-install"],
               stderr_to_stdout: true
             ) do
          {_, 0} ->
            :ok

          {output, _} ->
            Mix.raise("""
            The Apple container system service is not running and could not be started.

            #{String.trim(output)}

            Try running `container system start` manually.
            """)
        end
    end
  end

  defp ensure_tool_running!(_tool), do: :ok

  # Create a container volume if it doesn't already exist.
  # Docker's `volume create` is idempotent, but Podman returns an error
  # if the volume already exists, so check with `volume inspect` first.
  defp ensure_volume(tool, volume_name) do
    if volume_exists_with_tool?(tool, volume_name) do
      :ok
    else
      args =
        if tool == "container" do
          size =
            System.get_env("NERVES_CONTAINER_VOLUME_SIZE") || @apple_container_default_volume_size

          ["volume", "create", volume_name, "-s", size]
        else
          ["volume", "create", volume_name]
        end

      {output, exit_code} = System.cmd(tool, args, stderr_to_stdout: true)

      if exit_code != 0 do
        Mix.raise("Failed to create container volume #{volume_name}: #{String.trim(output)}")
      end

      :ok
    end
  end

  defp volume_exists_with_tool?("container", volume_name) do
    case System.cmd("container", ["volume", "list", "-q"], stderr_to_stdout: true) do
      {output, 0} -> volume_name in String.split(output, "\n", trim: true)
      _ -> false
    end
  end

  defp volume_exists_with_tool?(tool, volume_name) do
    match?({_, 0}, System.cmd(tool, ["volume", "inspect", volume_name], stderr_to_stdout: true))
  end

  defp volume_mount_args("container", volume_name, target) do
    ["--mount", "type=volume,source=#{volume_name},target=#{target}"]
  end

  defp volume_mount_args(_tool, volume_name, target) do
    ["--mount", "type=volume,src=#{volume_name},target=#{target}"]
  end

  defp host_memory_gb() do
    case System.cmd("sysctl", ["-n", "hw.memsize"]) do
      {result, 0} ->
        result
        |> String.trim()
        |> String.to_integer()
        |> div(1024 * 1024 * 1024)

      _ ->
        16
    end
  end

  defp image_exists?(tool, image) do
    match?({_, 0}, System.cmd(tool, ["image", "inspect", image], stderr_to_stdout: true))
  end

  defp build_image!(tool, image, dockerfile) do
    Mix.shell().info("Building artifact image #{image}...")

    args =
      if tool == "container",
        do: [
          "build",
          "--tag",
          image,
          "--build-arg",
          "ELIXIR_VERSION=#{System.version()}",
          "--build-arg",
          "OTP_RELEASE=#{System.otp_release()}",
          Path.dirname(dockerfile)
        ],
        else: [
          "build",
          "-t",
          image,
          "--build-arg",
          "ELIXIR_VERSION=#{System.version()}",
          "--build-arg",
          "OTP_RELEASE=#{System.otp_release()}",
          Path.dirname(dockerfile)
        ]

    {output, exit_code} = System.cmd(tool, args, stderr_to_stdout: true)

    if exit_code != 0 do
      Mix.raise("Failed to build artifact image #{image}:\n#{output}")
    end
  end

  defp dockerfile_image_name(dockerfile, package) do
    hash =
      [File.read!(dockerfile), System.version(), System.otp_release(), package.source_fingerprint]
      |> Enum.join(":")
      |> :erlang.md5()
      |> Base.encode16(case: :lower)
      |> binary_part(0, 12)

    "nerves-artifact:#{hash}"
  end

  @doc """
  Populate the work directory with package source and build deps.

  Refreshes the package source directory (`<pkg.app>/`) and each build dep
  directory while preserving `build/` for incremental builds. On Linux this
  is a direct file copy into the bind-mount path; on macOS it uses either a
  helper container or a temporary bind mount.
  """
  @spec populate_work_dir(BuildPlan.t(), String.t(), BuildPlan.package_info(), String.t()) :: :ok
  def populate_work_dir(build_plan, tool, pkg, image) do
    case :os.type() do
      {:unix, :linux} ->
        populate_work_dir_linux(build_plan, pkg)

      _ ->
        populate_work_dir_volume(build_plan, tool, pkg, image)
    end
  end

  @doc """
  Copy files from the work directory's package subdirectory back to the host.

  Used by `mix nerves.artifact.shell` to retrieve changed files
  (e.g., updated defconfig) when the shell exits.
  On Linux this is a direct file copy; on macOS it uses a helper container or
  a temporary bind mount.
  """
  @spec sync_work_dir(String.t(), BuildPlan.package_info(), String.t()) :: :ok
  def sync_work_dir(tool, package, image) do
    case {:os.type(), tool} do
      {{:unix, :linux}, _} ->
        src = Path.join(work_dir(package), to_string(package.app))
        sync_local_dir(src, package.path)

      {_, "container"} ->
        sync_work_dir_apple_container(package, image)

      _ ->
        sync_work_dir_docker_volume(tool, package, image)
    end
  end

  # --- Linux (bind mount) helpers ---

  defp populate_work_dir_linux(build_plan, pkg) do
    host_path = work_dir(pkg)
    pkg_dest = Path.join(host_path, to_string(pkg.app))
    build_dest = Path.join(host_path, "build")

    # Refresh source
    _ = File.rm_rf(pkg_dest)
    File.mkdir_p!(pkg_dest)
    copy_tree!(pkg.path, pkg_dest)

    # Refresh build deps
    for dep <- pkg.deps do
      dest = Path.join(host_path, to_string(dep))
      _ = File.rm_rf(dest)
      File.mkdir_p!(dest)

      dep_package = BuildPlan.find_package(build_plan, dep)
      copy_tree!(dep_package.path, dest)
    end

    # Ensure build exists
    File.mkdir_p!(build_dest)

    :ok
  end

  @copy_tree_excludes ["./_build", "./deps", "/.git"]

  # Copy the contents of src_dir into dest_dir while skipping generated Mix
  # directories that can contain broken symlinks or large caches.
  defp copy_tree!(src_dir, dest_dir) do
    archive =
      Path.join(staging_dir(), "nerves-copy-#{System.unique_integer([:positive])}.tar")

    tar_create_args =
      ["cf", archive] ++ Enum.map(@copy_tree_excludes, &"--exclude=#{&1}") ++ ["-C", src_dir, "."]

    try do
      case System.cmd("tar", tar_create_args, stderr_to_stdout: true) do
        {_, 0} ->
          case System.cmd("tar", ["xf", archive, "-C", dest_dir], stderr_to_stdout: true) do
            {_, 0} ->
              :ok

            {output, _} ->
              Mix.raise("Failed to extract staged copy into #{dest_dir}: #{String.trim(output)}")
          end

        {output, _} ->
          Mix.raise("Failed to copy #{src_dir} to #{dest_dir}: #{String.trim(output)}")
      end
    after
      File.rm(archive)
    end
  end

  defp with_staged_tree(src_dir, fun) do
    staged_dir =
      Path.join(staging_dir(), "nerves-stage-#{System.unique_integer([:positive])}")

    try do
      File.mkdir_p!(staged_dir)
      copy_tree!(src_dir, staged_dir)
      fun.(staged_dir)
    after
      File.rm_rf(staged_dir)
    end
  end

  defp staging_dir() do
    path = Path.join([Mix.Project.build_path(), "nerves", "staging"])
    File.mkdir_p!(path)
    path
  end

  defp sync_local_dir(src, dest) do
    case System.cmd("cp", ["-a", "#{src}/.", dest], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {output, _} -> Mix.raise("Failed to sync #{src} to #{dest}: #{String.trim(output)}")
    end

    :ok
  end

  # --- macOS (volume) helpers ---

  defp populate_work_dir_volume(build_plan, tool, pkg, image) do
    if tool == "container" do
      populate_work_dir_apple_container(build_plan, pkg, image)
    else
      populate_work_dir_docker_volume(build_plan, tool, pkg, image)
    end
  end

  defp populate_work_dir_apple_container(build_plan, pkg, image) do
    volume = volume_name(pkg)
    destination = "/workspace/#{pkg.app}"

    copy_staged_tree_to_apple_volume(pkg.path, volume, destination, image)

    Enum.each(pkg.deps, fn dep ->
      dep_package = BuildPlan.find_package(build_plan, dep)
      copy_staged_tree_to_apple_volume(dep_package.path, volume, "/workspace/#{dep}", image)
    end)

    prepare_apple_build_dir(volume, image)
  end

  # Apple's container CLI does not provide Docker's `cp` command. Copy staged
  # sources through a temporary bind mount into the case-sensitive EXT4 volume.
  defp copy_staged_tree_to_apple_volume(source, volume, destination, image) do
    with_staged_tree(source, fn staged_path ->
      args =
        [
          "run",
          "--rm",
          "--uid",
          "0",
          "--gid",
          "0"
        ] ++
          volume_mount_args("container", volume, "/workspace") ++
          [
            "--mount",
            "type=bind,source=#{staged_path},target=/source,readonly",
            image,
            "/bin/sh",
            "-c",
            "rm -rf #{destination} && mkdir -p #{destination} && cp -a /source/. #{destination} && chown -R nerves:nerves #{destination}"
          ]

      case System.cmd("container", args, stderr_to_stdout: true) do
        {_, 0} ->
          :ok

        {output, _} ->
          Mix.raise("Failed to copy source into container volume: #{String.trim(output)}")
      end
    end)
  end

  defp prepare_apple_build_dir(volume, image) do
    args =
      [
        "run",
        "--rm",
        "--uid",
        "0",
        "--gid",
        "0"
      ] ++
        volume_mount_args("container", volume, "/workspace") ++
        [
          image,
          "/bin/sh",
          "-c",
          "mkdir -p /workspace/build && chown -R nerves:nerves /workspace/build"
        ]

    case System.cmd("container", args, stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      {output, _} ->
        Mix.raise("Failed to prepare container build directory: #{String.trim(output)}")
    end
  end

  defp populate_work_dir_docker_volume(build_plan, tool, pkg, image) do
    vol = volume_name(pkg)
    pkg_dir = "/workspace/#{pkg.app}"

    # Prepare volume directories using a short-lived container run as root.
    # Previous contents may be owned by root or another UID, so root is
    # needed for the rm. After recreating, chown to the image's default
    # user (nerves) so the build container can write to them.
    dep_dirs =
      Enum.map_join(pkg.deps, " ", fn app -> "/workspace/#{app}" end)

    rm_dirs = "#{pkg_dir} #{dep_dirs}" |> String.trim()
    all_dirs = "#{pkg_dir} #{dep_dirs} /workspace/build" |> String.trim()

    {output, exit_code} =
      System.cmd(
        tool,
        [
          "run",
          "--rm",
          "--user",
          "root",
          "--mount",
          "type=volume,src=#{vol},target=/workspace",
          image,
          "/bin/sh",
          "-c",
          "rm -rf #{rm_dirs} && mkdir -p #{all_dirs} && chown -R nerves:nerves #{all_dirs}"
        ],
        stderr_to_stdout: true
      )

    if exit_code != 0 do
      Mix.raise("Failed to prepare volume directories: #{String.trim(output)}")
    end

    # Use a disposable stopped container to copy files into the volume.
    # `docker cp` works on stopped containers; the directories were created
    # above so trailing-slash destinations work.
    {id_raw, exit_code} =
      System.cmd(
        tool,
        [
          "create",
          "--mount",
          "type=volume,src=#{vol},target=/workspace",
          image,
          "true"
        ],
        stderr_to_stdout: true
      )

    if exit_code != 0 do
      Mix.raise("Failed to create helper container: #{String.trim(id_raw)}")
    end

    container_id = extract_container_id(id_raw)

    try do
      with_staged_tree(pkg.path, fn staged_path ->
        case System.cmd(tool, ["cp", "#{staged_path}/.", "#{container_id}:#{pkg_dir}/"],
               stderr_to_stdout: true
             ) do
          {_, 0} -> :ok
          {output, _} -> Mix.raise("Failed to copy source into volume: #{String.trim(output)}")
        end
      end)

      Enum.each(pkg.deps, fn dep ->
        dep_package = BuildPlan.find_package(build_plan, dep)

        with_staged_tree(dep_package.path, fn staged_path ->
          case System.cmd(
                 tool,
                 ["cp", "#{staged_path}/.", "#{container_id}:/workspace/#{dep}/"],
                 stderr_to_stdout: true
               ) do
            {_, 0} -> :ok
            {output, _} -> Mix.raise("Failed to copy #{dep} into volume: #{String.trim(output)}")
          end
        end)
      end)
    after
      _ = System.cmd(tool, ["rm", "-f", container_id], stderr_to_stdout: true)
      :ok
    end

    :ok
  end

  defp sync_work_dir_apple_container(package, image) do
    volume = volume_name(package)

    args =
      [
        "run",
        "--rm",
        "--uid",
        "0",
        "--gid",
        "0"
      ] ++
        volume_mount_args("container", volume, "/workspace") ++
        [
          "--mount",
          "type=bind,source=#{package.path},target=/destination",
          image,
          "/bin/sh",
          "-c",
          "find /workspace/#{package.app} -mindepth 1 -maxdepth 1 -exec cp -a -t /destination -- {} +"
        ]

    case System.cmd("container", args, stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      {output, _} ->
        Mix.raise("Failed to sync files from container volume: #{String.trim(output)}")
    end
  end

  defp sync_work_dir_docker_volume(tool, package, image) do
    vol = volume_name(package)

    {id_raw, exit_code} =
      System.cmd(
        tool,
        [
          "create",
          "--mount",
          "type=volume,src=#{vol},target=/workspace",
          image,
          "true"
        ],
        stderr_to_stdout: true
      )

    if exit_code != 0 do
      Mix.raise("Failed to create helper container: #{String.trim(id_raw)}")
    end

    container_id = extract_container_id(id_raw)

    try do
      case System.cmd(tool, ["cp", "#{container_id}:/workspace/#{package.app}/.", package.path],
             stderr_to_stdout: true
           ) do
        {_, 0} -> :ok
        {output, _} -> Mix.raise("Failed to copy files from volume: #{String.trim(output)}")
      end
    after
      System.cmd(tool, ["rm", "-f", container_id], stderr_to_stdout: true)
    end

    :ok
  end

  # Buildroot C++ compilation can use 2-4 GB of RAM. Below 3 GB the OOM killer
  # tends to kill cc1plus, producing a misleading "Killed signal terminated
  # program" error. On macOS, podman machine defaults to 2 GB.
  @min_container_memory_kb 3 * 1024 * 1024

  @doc """
  Return a shell script snippet that warns when container RAM is below
  #{div(@min_container_memory_kb, 1024)} MB.

  On macOS, both Docker and Podman run containers inside a VM whose memory
  is capped by the host tool's configuration. Buildroot's C++ compilation
  requires at least 3 GB; below that the OOM killer terminates `cc1plus`
  with a confusing "Killed" message. Running this snippet at the start of
  any container script surfaces the problem immediately.
  """
  @spec memory_check_script() :: String.t()
  def memory_check_script() do
    min_kb = @min_container_memory_kb
    min_mb = div(min_kb, 1024)

    """
    mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
    if [ "$mem_kb" -gt 0 ] && [ "$mem_kb" -lt #{min_kb} ]; then
      echo ""
      echo "WARNING: Container only has $((mem_kb / 1024)) MB of RAM (minimum recommended: #{min_mb} MB)."
      echo "If the build fails with 'Killed', increase VM memory:"
      echo "  Podman: podman machine stop && podman machine set --memory 4096 && podman machine start"
      echo "  Docker: Docker Desktop > Settings > Resources > Memory"
      echo ""
      echo "Continuing build in 5 seconds..."
      sleep 5
    fi
    """
    |> String.trim()
  end

  @doc """
  Check whether a container volume exists.
  """
  @spec volume_exists?(String.t()) :: boolean()
  def volume_exists?(name) do
    case System.find_executable(tool()) do
      nil -> false
      _ -> volume_exists_with_tool?(tool(), name)
    end
  end

  @doc """
  List container build volumes matching the Nerves build prefix.
  """
  @spec list_docker_volumes() :: [String.t()]
  def list_docker_volumes() do
    tool = tool()

    case System.find_executable(tool) do
      nil ->
        []

      _ ->
        args =
          if tool == "container",
            do: ["volume", "list", "-q"],
            else: ["volume", "ls", "--filter", "name=nerves-work", "-q"]

        case System.cmd(tool, args, stderr_to_stdout: true) do
          {output, 0} ->
            output
            |> String.trim()
            |> String.split("\n", trim: true)
            |> Enum.filter(&String.starts_with?(&1, "nerves-work"))

          _ ->
            []
        end
    end
  end

  # Private helpers

  @doc """
  Extract the container ID from `docker create` / `podman create` output.

  The ID is typically the last non-empty line, but there may be image pull
  progress or warnings before it.
  """
  @spec extract_container_id(String.t()) :: String.t()
  def extract_container_id(output) do
    id =
      output
      |> String.split("\n", trim: true)
      |> List.last("")
      |> String.trim()

    if id == "" do
      Mix.raise("Container tool returned an empty container ID. Output: #{String.trim(output)}")
    end

    id
  end
end
