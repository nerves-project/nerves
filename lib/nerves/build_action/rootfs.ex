# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildAction.Rootfs do
  @moduledoc """
  Release step that builds the root filesystem image.

  Reads the system's base rootfs (preferring `rootfs.tar`, falling back
  to extracting `rootfs.squashfs`), merges it with the scrubbed release
  and user rootfs overlays, then creates a combined rootfs image.

  Supported rootfs types:

    * `:squashfs` — SquashFS via `sqfstar` (default)
    * `:erofs` — EROFS via `mkfs.erofs`
    * `:ext4` — EXT4 via `mkfs.ext4` (read-only)

  ## Merge priority (first wins)

    1. Generated build-plan overlays
    2. User `rootfs_overlay/` directory
    3. Assembled + scrubbed Mix release (defaults to `srv/erlang/`)
    4. System base rootfs
  """

  use Nerves.BuildAction

  alias Nerves.Artifact.Archive
  alias Nerves.BuildAction.BootOrder
  alias Nerves.MixUtils
  alias Nerves.Tar

  @supported_types [:squashfs, :erofs, :ext4]

  @type fs_format() :: :squashfs | :erofs | :ext4
  @type normalized_rootfs_type() :: {fs_format(), [String.t()]}
  @type rootfs_type() :: normalized_rootfs_type() | fs_format() | nil

  @spec default_config() :: %{
          rootfs_path: String.t(),
          rootfs_type: {:squashfs | :erofs | :ext4, [String.t()]},
          target_release_path: String.t(),
          bootfile: String.t()
        }
  def default_config() do
    project_config = Mix.Project.config()
    images_path = Path.join([Mix.Project.build_path(), "nerves", "images"])

    firmware_config = Application.get_env(:nerves, :firmware) || []

    rootfs_type =
      if firmware_config[:mksquashfs_flags] do
        MixUtils.warning("""
        :mksquashfs_flags is deprecated. Use :rootfs_type in your firmware config instead.

            config :nerves, :firmware,
              rootfs_type: {:squashfs, #{inspect(firmware_config[:mksquashfs_flags])}}
        """)

        {:squashfs, firmware_config[:mksquashfs_flags]}
      else
        firmware_config[:rootfs_type] || :squashfs
      end

    %{
      rootfs_path: Path.join(images_path, "#{project_config[:app]}.rootfs"),
      rootfs_type: rootfs_type,
      target_release_path: "srv/erlang",
      bootfile: firmware_config[:bootfile] || "start.boot"
    }
  end

  @spec validate!(Nerves.BuildPlan.t()) :: :ok
  def validate!(%Nerves.BuildPlan{} = build_plan) do
    required_config = [
      :rootfs_inputs,
      :images_path,
      :rootfs_path,
      :rootfs_type,
      :target_release_path,
      :bootfile
    ]

    _optional_config = [:rootfs_overlay]

    missing_keys = Enum.reject(required_config, &Map.has_key?(build_plan.config, &1))

    if missing_keys != [] do
      raise Nerves.InvalidPlan,
        message: "BuildPlan is missing required configuration for #{inspect(missing_keys)}"
    end

    rootfs_inputs = build_plan.config[:rootfs_inputs]

    if rootfs_inputs == nil or rootfs_inputs == [] do
      raise Nerves.InvalidPlan, message: ":rootfs_inputs must contain at least one tar file."
    end

    classified_inputs = Enum.map(rootfs_inputs, fn f -> {f, Archive.file_type(f)} end)
    violations = Enum.filter(classified_inputs, fn {_, type} -> type != :tar end)

    if violations != [] do
      raise Nerves.InvalidPlan,
        message: """
        :rootfs_inputs must contain tar files

        The following violations were found:

        #{Enum.map_join(violations, "\n", fn {path, class} -> "#{path}: #{class}" end)}

        If you're using a custom Nerves system, please add `BR2_TARGET_ROOTFS_TAR=y` to the `nerves_defconfig`.
        """
    end

    :ok
  end

  @doc """
  Run the rootfs step
  """
  @impl Nerves.BuildAction
  def rootfs_creation_steps(%Nerves.BuildPlan{} = build_plan, %Mix.Release{} = release, opts) do
    opts = Map.merge(build_plan.config, Map.new(opts))
    validate!(build_plan)

    # 1. Read all of the rootfs_inputs
    base_entries = Enum.map(opts[:rootfs_inputs], &Tar.Reader.read_tar/1)

    # 2. Scan the scrubbed release directory
    release_entries = Tar.FSReader.scan_directory(release.path, opts[:target_release_path])

    # 3. Scan generated and user rootfs overlays
    overlay_entries = scan_overlays(build_plan.rootfs_overlays, opts[:rootfs_overlay])

    # 3.5. Create default entries for the target_release_path directories in case they're
    # .   not provided by anyone else.
    default_entries = Tar.FSReader.synthesize_dirs(opts[:target_release_path])

    # 4. Merge: overlay > release > system (first entry wins)
    merged = merge([overlay_entries, release_entries, base_entries, default_entries])

    # 5. Sort: boot-critical files first, then alphabetical
    priority_map = BootOrder.build_priority_map(release, opts)
    sorted = BootOrder.sort(merged, priority_map)

    # 6. Write combined tar
    File.mkdir_p!(opts[:images_path])
    combined_tar = Path.join(opts[:images_path], "combined.tar")
    Tar.Writer.write_tar(combined_tar, sorted)

    # 7. Create rootfs image from tar
    create_rootfs_image!(
      normalize_rootfs_type(opts[:rootfs_type]),
      opts[:rootfs_path],
      combined_tar
    )

    release
  end

  # ---------------------------------------------------------------------------
  # User rootfs overlay
  # ---------------------------------------------------------------------------

  defp scan_overlays(generated_overlays, user_overlays) do
    Enum.flat_map(generated_overlays ++ List.wrap(user_overlays), &scan_overlay/1)
  end

  defp scan_overlay(nil), do: []

  defp scan_overlay(overlay) when is_binary(overlay) do
    if File.dir?(overlay) do
      Tar.FSReader.scan_directory(overlay, "/")
    else
      []
    end
  end

  # ---------------------------------------------------------------------------
  # Merge
  # ---------------------------------------------------------------------------

  defp merge(entries_list) do
    entries_list
    |> List.flatten()
    |> Enum.uniq_by(& &1.path)
  end

  # ---------------------------------------------------------------------------
  # Rootfs type and flags resolution
  # ---------------------------------------------------------------------------

  @doc """
  Normalize a rootfs_type to the tuple form
  """
  @spec normalize_rootfs_type(rootfs_type) :: normalized_rootfs_type()
  def normalize_rootfs_type(rootfs_type) do
    case rootfs_type do
      nil -> {:squashfs, default_rootfs_flags(:squashfs)}
      type when type in @supported_types -> {type, default_rootfs_flags(type)}
      {type, nil} when type in @supported_types -> {type, default_rootfs_flags(type)}
      {type, flags} when type in @supported_types and is_list(flags) -> {type, flags}
      type -> Mix.raise("Unsupported :rootfs_type: #{inspect(type)}")
    end
  end

  # Squashfs-tools 4.6.1: use `-all-time 0 -mkfs-time 0` for reproducible builds
  # Squashfs-tools 4.7.4: can use `-repro 0` for reproducible builds
  defp default_rootfs_flags(:squashfs),
    do: ["-mkfs-time", "0", "-all-time", "0", "-no-xattrs", "-quiet"]

  # EROFS defaults:
  # -b 4096  -> U-Boot's EROFS support doesn't support 16KB so this is a safer default
  # -C 16386 -> Slightly faster boot time on eMMC/MicroSD than default
  # -zlz4hc,level=12 -> Use compression by default; 12 works better without a noticeable creation slowdown
  # -Eragments,ztailpacking -> Linux 5.17+ improvement
  # -T 0 -> reproducible builds
  # -U clear -> reproducible builds
  defp default_rootfs_flags(:erofs),
    do: [
      "-b",
      "4096",
      "-C",
      "16384",
      "-zlz4hc,level=12",
      "-Efragments,ztailpacking",
      "-T",
      "0",
      "-U",
      "clear"
    ]

  defp default_rootfs_flags(:ext4), do: ["-O", "^resize_inode,^has_journal", "-m", "0"]

  # ---------------------------------------------------------------------------
  # Rootfs image creation
  # ---------------------------------------------------------------------------

  defp create_rootfs_image!({:squashfs, flags}, image_path, tar_path) do
    mkfs_squashfs!(image_path, tar_path, flags)
  end

  defp create_rootfs_image!({:erofs, flags}, image_path, tar_path) do
    mkfs_erofs!(image_path, tar_path, flags)
  end

  defp create_rootfs_image!({:ext4, flags}, image_path, tar_path) do
    mkfs_ext4!(image_path, tar_path, flags)
  end

  # ---------------------------------------------------------------------------
  # Squashfs creation
  # ---------------------------------------------------------------------------

  defp mkfs_squashfs!(squashfs_path, tar_path, flags) do
    find_sqfstar!()

    MixUtils.info("  Creating SquashFS filesystem...")

    flags_str = Enum.join(flags, " ")

    case MixUtils.shell_command(
           "sqfstar -force #{flags_str} #{escape(squashfs_path)} < #{escape(tar_path)}"
         ) do
      {_, 0} ->
        :ok

      {output, code} ->
        Mix.raise("sqfstar failed (exit #{code}):\n#{output}")
    end
  end

  defp find_sqfstar!() do
    if !System.find_executable("sqfstar") do
      Mix.raise("""
      sqfstar not found.

      sqfstar is part of squashfs-tools 4.5+. Install it with:
        brew install squashfs  (macOS)
        apt install squashfs-tools  (Debian/Ubuntu)
      """)
    end
  end

  # ---------------------------------------------------------------------------
  # EROFS creation
  # ---------------------------------------------------------------------------

  defp mkfs_erofs!(erofs_path, tar_path, flags) do
    mkfs_erofs = find_mkfs_erofs!()

    MixUtils.info("  Creating EROFS filesystem...")

    args = ["--tar=f"] ++ flags ++ [erofs_path, tar_path]

    case MixUtils.cmd(mkfs_erofs, args, stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      {output, code} ->
        Mix.raise("mkfs.erofs failed (exit #{code}):\n#{output}")
    end
  end

  defp find_mkfs_erofs!() do
    case System.find_executable("mkfs.erofs") do
      nil ->
        Mix.raise("""
        mkfs.erofs not found.

        mkfs.erofs is part of erofs-utils. Install it with:
          brew install erofs-utils  (macOS)
          apt install erofs-utils   (Debian/Ubuntu)
        """)

      path ->
        path
    end
  end

  # ---------------------------------------------------------------------------
  # EXT4 creation
  # ---------------------------------------------------------------------------

  defp mkfs_ext4!(ext4_path, tar_path, flags) do
    mkfs_ext4 = find_mkfs_ext4!()

    MixUtils.info("  Creating EXT4 filesystem...")

    # TODO - Allow user to specify size since estimating it is error prone.
    # This is also what Buildroot does.
    tar_bytes = File.stat!(tar_path).size
    content_kb = div(tar_bytes, 1024)
    image_kb = content_kb + div(content_kb * 3, 20) + 1024

    args = ["-d", tar_path] ++ flags ++ [ext4_path, "#{image_kb}"]

    case MixUtils.cmd(mkfs_ext4, args, stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      {output, code} ->
        Mix.raise("mkfs.ext4 failed (exit #{code}):\n#{output}")
    end
  end

  defp find_mkfs_ext4!() do
    # e2fsprogs is keg-only on Homebrew, so check its sbin path too
    cond do
      exe = System.find_executable("mkfs.ext4") ->
        exe

      exe = find_homebrew_mkfs_ext4() ->
        exe

      true ->
        Mix.raise("""
        mkfs.ext4 not found.

        mkfs.ext4 is part of e2fsprogs. Install it with:
          apt install e2fsprogs   (Debian/Ubuntu)

        On macOS, you'll need to manually install e2fsprogs since Homebrew's
        version isn't currently linked against libarchive.
        """)
    end
  end

  defp find_homebrew_mkfs_ext4() do
    case MixUtils.cmd("brew", ["--prefix", "e2fsprogs"], stderr_to_stdout: true) do
      {prefix, 0} ->
        mkfs_path = Path.join([String.trim(prefix), "sbin", "mkfs.ext4"])
        if File.exists?(mkfs_path), do: mkfs_path, else: nil

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  defp escape(path) do
    # Shell-escape paths for use in System.shell/2
    "'" <> String.replace(path, "'", "'\\''") <> "'"
  end
end
