# Experimental features

The features described in this document are experimental. They are under
consideration and or actively being developed.

## Firmware patches

Firmware update files (`.fw`) contain everything your target needs to boot and
run your application. Commonly, this single file package will contain your root
filesystem, the linux kernel, a bootloader, and some extra files and metadata
specific to your target. Packaging all these files together provides a convenient
and reliable means of distributing firmware that can be used to boot new devices
as well as upgrade existing ones. Unfortunately, this mechanism is not conducive
to applying updates to devices that are use expensive metered network connections
where the cost of every byte counts. This problem can be alleviated with firmware
patches.

A firmware patch file's content structure is identical to that of a regular
firmware update file, it contains your root file system, the linux kernel, and
so on. The main difference is that the contents of these files are no longer a
bit for bit representation but instead the delta between two known versions of
firmware. Currently, the system will only apply patches to the root file system,
but there are plans to support other files. It is important to note that in order
to generate a firmware patch file, you will need to supply two full firmware
update files, the firmware that the target is updating from (currently running)
and the firmware the device will be updating to (the desired new firmware).
Attempting to apply a firmware patch to a target that is not running the "from"
firmware will result in returning an error when attempting to apply it.
Generating and applying firmware patch files will require that your host machine
and your target have `fwup` >= 1.6.0 installed.


### Preparing your Nerves system

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

```
on-resource rootfs.img { raw_write(${ROOTFS_A_PART_OFFSET}) }
```

To:

```
on-resource rootfs.img {
  delta-source-raw-offset=${ROOTFS_B_PART_OFFSET}
  delta-source-raw-count=${ROOTFS_B_PART_COUNT}
  raw_write(${ROOTFS_A_PART_OFFSET})
}
```

Change the reference in the `upgrade.b` task:

```
on-resource rootfs.img { raw_write(${ROOTFS_B_PART_OFFSET}) }
```

To:

```
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

```
Running fwup...
fwup: Upgrading partition B
fwup: File 'rootfs.img' isn't expected size (7373 vs 49201152) and xdelta3 patch support not enabled on it. (Add delta-source-raw-offset or delta-source-raw-count at least)
```

### Preparing your project

Generating a root filesystem patch requires a bit comparison between two root
file systems. We use xdelta3 and provide it the "from" and "to" SquashFS files.
SquashFS will compress the root filesystem structure and data by default. The
resulting patch file size is often quite higher compared to the expected source
modification size due to the bit for bit comparison being inefficient when
comparing compressed data. SquashFS can be configured to disable compression,
allowing us to create more efficient patches. Disabling SquashFS compression
allows us to create more effective patches. Add the following `mksquashfs_flags`
to your project's mix config.

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

### Testing firmware patches locally

Create a new project using `mix nerves.new <project name>` and apply the steps
listed in the `Preparing your project` section. Then, choose a target, in this
example, I will be using a Raspberry Pi Zero W `rpi0` and building an app
called `test_patch`.

```
export MIX_TARGET=rpi0
mix deps.get
```

Create your initial firmware and burn it to an SD card

```
mix firmware.burn
```

Connect the SD card and power on the device by connecting a micro USB cable to
the host USB port on the Raspberry Pi. You can ssh into the device at
`nerves.local` and you should get an IEX prompt.

```
ssh nerves.local

Interactive Elixir (1.10.3) - press Ctrl+C to exit (type h() ENTER for help)
Toolshed imported. Run h(Toolshed) for more info.
RingLogger is collecting log messages from Elixir and Linux. To see the
messages, either attach the current IEx session to the logger:

  RingLogger.attach

or print the next messages in the log:

  RingLogger.next

iex(1)> TestPatch.hello
:world
```

Make some changes to the function. Open `lib/<app_name>.ex` and modify the
`hello/0` function.

```elixir
def hello do
  :patched
end
```

Now lets generate a patch firmware.

`mix firmware.patch`

You should see output similar to the following:

```
Finished generating patch firmware

Source
test_patch/_build/rpi0_dev/nerves/images/test_patch.fw
uuid: 6cf7f75f-eb93-5a91-e28c-fd414602b6e7"

size: 22079567 bytes

Target
nerves-project/tests/test_patch/_build/rpi0_dev/nerves/images/patch/target.fw
uuid: 69752f24-291f-5f00-4ad3-ca359017009f"

size: 22077072 bytes

Patch
test_patch/_build/rpi0_dev/nerves/images/patch.fw
size: 4425660 bytes
```

Lets update the device using the patch file.

```
mix upload --firmware /path/to/test_patch/_build/rpi0_dev/nerves/images/patch.fw
```

The size difference between the `Target` output firmware size `22077072` and the
patched firmware size `4425660` has a pretty significant size reduction. For
such a small change, we might expect more. A lot of this size come from the
files that are also included in the firmware that are not currently being patched
such as the linux kernel and other files that do not change frequently.
We anticipate that all other files wil offer similar support, but we started
with the first most impactful file, the SquashFS root filesystem, so we can begin
testing this workflow using devices.
