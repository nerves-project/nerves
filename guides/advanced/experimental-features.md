<!--
  SPDX-FileCopyrightText: 2020 Frank Hunleth
  SPDX-FileCopyrightText: 2020 Justin Schneck
  SPDX-FileCopyrightText: 2020 Kian-Meng, Ang
  SPDX-FileCopyrightText: 2021 Bruce Wong
  SPDX-License-Identifier: CC-BY-4.0
-->
# Experimental features

The features described in this document are experimental. They are under
consideration and or actively being developed.

## Firmware patches

Firmware update files (`.fw`) contain everything your target needs to boot and
run your application. Commonly, this single file package will contain your root
filesystem, the Linux kernel, a bootloader, and some extra files and metadata
specific to your target. Packaging all these files together provides a convenient
and reliable means of distributing firmware that can be used to boot new devices
as well as upgrade existing ones. Unfortunately, this mechanism is not conducive
to applying updates to devices that use expensive metered network connections
where the cost of every byte counts. This problem can be alleviated with firmware
patches.

A firmware patch file's content structure is identical to that of a regular
firmware update file. The main difference is that the contents of these files
are no longer a bit for bit representation but instead the delta between two
known versions of firmware.

To generate a firmware patch file, you will need to supply two full firmware
update files, the firmware that the target is updating from (currently running)
and the firmware the device will be updating to (the desired new firmware).
Attempting to apply a firmware patch to a target that is not running the "from"
firmware will return an error.

See [fwup_delta](https://hex.pm/packages/fwup_delta) for an Elixir library that
creates patches.

### Preparing your Nerves system for patches

Firmware update patches will require modifications to the `fwup.conf` of your
Nerves system. These updates must be applied in full to a running target before
it is capable of applying firmware update patches.

In your `fwup.conf`, find the references to `rootfs.img`, in typical systems
there will be 4 references.

* `file-resource`:
  Unchanged
* Inside the `complete` task:
  Unchanged. When writing a complete firmware on to a new device. A patch
  cannot be applied on the target.
* Inside the `upgrade.a` task:
  When new firmware is written in to firmware slot `a`.
* Inside the `upgrade.b` task:
  When new firmware is written in to firmware slot `b`.

We only need to modify the actions taken in the `upgrade.a` and `upgrade.b` steps.

Change the reference in the `upgrade.a` task:

```text
on-resource rootfs.img { raw_write(${ROOTFS_A_PART_OFFSET}) }
```

To:

```text
on-resource rootfs.img {
  delta-source-raw-offset=${ROOTFS_B_PART_OFFSET}
  delta-source-raw-count=${ROOTFS_B_PART_COUNT}
  raw_write(${ROOTFS_A_PART_OFFSET})
}
```

Change the reference in the `upgrade.b` task:

```text
on-resource rootfs.img { raw_write(${ROOTFS_B_PART_OFFSET}) }
```

To:

```text
on-resource rootfs.img {
  delta-source-raw-offset=${ROOTFS_A_PART_OFFSET}
  delta-source-raw-count=${ROOTFS_A_PART_COUNT}
  raw_write(${ROOTFS_B_PART_OFFSET})
}
```

You'll also need to ensure that your system is being build using
`nerves_system_br` >= 1.11.2. This will be in your mix dependencies. If you
attempt to apply a firmware patch to a device that does not support it, you
will receive an error similar to the following:

```sh
Running fwup...
fwup: Upgrading partition B
fwup: File 'rootfs.img' isn't expected size (7373 vs 49201152) and xdelta3 patch support not enabled on it. (Add delta-source-raw-offset or delta-source-raw-count at least)
```

### Tips for smaller patches

Creating small firmware deltas requires tradeoffs. Internally, the `xdelta3`
tool finds common data between firmware images. It's good, but the following
work against it:

1. Compression - a small change at the beginning propogates and removes common
   byte sequences. Turn off compression or move frequently changing data to the
   end of the image.
2. Nondeterministic builds - Remove timestamps and debug information with local
   paths. Anything that changes between builds increases delta size.
3. File system packing - SquashFS packs filesystem data structures and small
   files. Files that change size or disappear between firmwares can cause inode
   tables and the like to change especially when packed
4. xdelta3 source windows - A larger source window allows xdelta3 to scan more
   data for matches. However, it also requires more memory on device. Source
   windows over 8 MB can cause cache thrashing on devices and make updates take
   a long time even though they are smaller.


One way to start is to experiment with setting `mksquashfs_flags` to your
project's mix config.

```elixir
# Customize non-Elixir parts of the firmware. See
# https://hexdocs.pm/nerves/advanced-configuration.html for details.

config :nerves, :firmware,
  rootfs_overlay: "rootfs_overlay",
  mksquashfs_flags: ["-noI", "-noId", "-noD", "-noF", "-noX"]
```

Patch sizes can also be optimized by configuring the build system's
`source_date_epoch` date. This will help with reproducible builds by preventing
timestamps modifications from affecting the output bit representation.

```elixir
# Set the SOURCE_DATE_EPOCH date for reproducible builds.
# See https://reproducible-builds.org/docs/source-date-epoch/ for more information

config :nerves, source_date_epoch: "1596027629"
```

## Nerves package environment variables

Packages can provide custom system environment variables to be exported when
`Nerves.Env.bootstrap/0` is called. The initial use case for this feature is to
export system specific information for llvm-based tools. Here is an example from
`nerves_system_rpi0`

```elixir
  defp nerves_package do
    [
      # ...
      env: [
        {"TARGET_ARCH", "arm"},
        {"TARGET_CPU", "arm1176jzf_s"},
        {"TARGET_OS", "linux"},
        {"TARGET_ABI", "gnueabi"}
      ]
      # ...
    ]
  end
```
