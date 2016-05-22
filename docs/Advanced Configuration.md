# Advanced Configuration

## Target Specific Configuration

Different target boards have different layouts for GPIO, LEDs, and more. Often, this requires that configurations be specified per-target. In this example, we will be looking at how to configure the LEDs for two different targets. First, let's start by modifying our `config.exs` to include configs for each target.

```elixir
use Mix.Config

config :blinky, led_list: [ :red, :green ]

import_config "#{Mix.Project.config[:target]}.exs"
```

This will load separate Mix Configs for each target passed. Let's say we have targets `rpi` and `bbb`. Each of those files would look like this.

```elixir
# rpi
config :nerves_io_led, names: [
  red: "led0",
  green: "led1"
]
```

```elixir
# bbb
config :nerves_io_led, names: [
  led0: "beaglebone:green:usr0",
  led1: "beaglebone:green:usr1",
  led2: "beaglebone:green:usr2",
  led3: "beaglebone:green:usr3"
]
```

## Root Filesystem Additions

Sometimes, you want to ship additional files and configurations with your firmware. You can do this by providing your own directory of root file system additions. This is done by configuring the firmware assembler and telling it where to find the folder it should use as an overlay:

```
# config/config.exs

config :nerves, :firmware,
  rootfs_additions: "config/rootfs-additions"
```

This declares that the contents of the folder at `config/rootfs-additions` will be merged into the root file system when `mix firmware` is called. You can also specify different rootfs additions per target as illustrated above.

## Overwriting Files in the Root File System

Any files in the `rootfs_additions` will overwrite those present in the underlying system. This can be useful if you want to change the contents of included files in the underlying Nerves system. Let's say, for example, that you want to change the behaviour of `erlinit`. You can include your own `erlinit.config`:

```
# config/rootfs-additions/etc/erlinit.config

# Uncomment to hang the board rather than rebooting when Erlang exits
#--hang-on-exit

# Enable UTF-8 filename handling in Erlang and custom inet configuration
-e LANG=en_US.UTF-8;LANGUAGE=en;ERL_INETRC=/etc/erl_inetrc

# Mount the configdata partition
# See http://www.linuxfromscratch.org/lfs/view/6.3/chapter08/fstab.html about
# ignoring warning the Linux kernel warning about using UTF8 with vfat.
-m /dev/mmcblk0p3:/root:vfat::

# Erlang release search path
-r /srv/erlang

# Hostname
-d "/usr/bin/boardid -b bbb -n 4"
-n nerves-%.4s

```

It is important to note that if you replace a config file, the entire file is replaced, rather than merging the contents. Therefore, you should first obtain and modify the original file. A trick for doing this is to expand the `rootfs.squashfs`. You can do this using `unsquashfs`:

```
$ unsquashfs path/to/rootfs.squashfs
```

This file is typically found in `_build/(Target)/(Mix.env)/nerves/system/images/rootfs.squashfs`. It will be expanded into the current directory under `squashfs-root`

## Overwriting Files in the Boot Partition

Different targets have different boot partition contents. To overwrite files in the boot partition, you will need to do this in your own `fwup.conf` file:

```
# config/config.exs

config :nerves, :firmware,
  fwup_conf: "config/fwup.conf"
```

In your included `fwup.conf` file, you can use absolute paths, or environment variables to point to the location of included files.

Let's say you have a Raspberry Pi and you want to change the contents of the `cmdline.txt` file. You can do this by editing the `fwup.conf` as follows:

```
# fwup.conf

file-resource cmdline.txt {
    host-path = "${NERVES_APP}/config/cmdline.txt"
}
```

You can use the `NERVES_APP` environment variable to point to the root of your Elixir app. This variable is automatically managed for you by `nerves_bootstrap`.

## Partitions

Nerves firmware uses Master Boot Record partition layout, which only supports 4 primary partitions. By default, the root filesystem partition is mounted as read-only. This is to prevent corruption of the root filesystem due to "improper shutdowns". With embedded systems, it is expected that the power can be pulled from the device at any time. This could be problematic if you are performing a write operation on the filesystem. Because of this, we also add a read/write partition by default, called `app_data`. This is mounted at `/root` and is dictated in `etc/erlinit.config`

```
+----------------------------+
| MBR                        |
+----------------------------+
| Boot partition (FAT32)     |
+----------------------------+
| p1*: Rootfs A (squashfs)   |
+----------------------------+
| p1*: Rootfs B (squashfs)   |
+----------------------------+
| p2: App Data  (FAT32)      |
+----------------------------+
```

You can enable and mount an additional read/write partition by modifying the `fwup.conf` file. This strategy is typically used to define two locations where data can be written. Let's say you want to persist some infrequently-written configuration data and some frequently-written log data. It would best be handled by separate partitions so that the important, infrequently-written configuration data is not corrupted due to a loss of power while writing the more frequent log data.

First, start by defining a new space on the disk for the partition:

```
# The boot partition
define(BOOT_PART_OFFSET, 63)
define(BOOT_PART_COUNT, 16321)

# Let the rootfs have room to grow up to 128 MiB and align
# it to the nearest 1 MB boundary
define(ROOTFS_A_PART_OFFSET, 16384)
define(ROOTFS_A_PART_COUNT, 289044)
define(ROOTFS_B_PART_OFFSET, 305428)
define(ROOTFS_B_PART_COUNT, 289044)

# Config partition
define(CONFIG_PART_OFFSET, 594472)
define(CONFIG_PART_COUNT, 1048576)

# Log partition
define(LOG_PART_OFFSET, 1643048)
define(LOG_PART_COUNT, 1048576)
```

In this example, we are changing the app data partition to `CONFIG_PART` and adding `LOG_PART`.

Next, we change the mapping to include these two new partitions:

```
mbr mbr-a {
    partition 0 {
        block-offset = ${BOOT_PART_OFFSET}
        block-count = ${BOOT_PART_COUNT}
        type = 0xc # FAT32
        boot = true
    }
    partition 1 {
        block-offset = ${ROOTFS_A_PART_OFFSET}
        block-count = ${ROOTFS_A_PART_COUNT}
        type = 0x83 # Linux
    }
    partition 2 {
        block-offset = ${CONFIG_PART_OFFSET}
        block-count = ${CONFIG_PART_COUNT}
        type = 0xc # FAT32
    }
    partition 3 {
        block-offset = ${LOG_PART_OFFSET}
        block-count = ${LOG_PART_COUNT}
        type = 0x83 # Linux
    }
}

mbr mbr-b {
    partition 0 {
        block-offset = ${BOOT_PART_OFFSET}
        block-count = ${BOOT_PART_COUNT}
        type = 0xc # FAT32
        boot = true
    }
    partition 1 {
        block-offset = ${ROOTFS_B_PART_OFFSET}
        block-count = ${ROOTFS_B_PART_COUNT}
        type = 0x83 # Linux
    }
    partition 2 {
        block-offset = ${CONFIG_PART_OFFSET}
        block-count = ${CONFIG_PART_COUNT}
        type = 0xc # FAT32
    }
    partition 3 {
        block-offset = ${LOG_PART_OFFSET}
        block-count = ${LOG_PART_COUNT}
        type = 0x83 # Linux
    }
}
```

This layout defines our system as follows:

```
+----------------------------+
| MBR                        |
+----------------------------+
| Boot partition (FAT32)     |
+----------------------------+
| p1*: Rootfs A (squashfs)   |
+----------------------------+
| p1*: Rootfs B (squashfs)   |
+----------------------------+
| p2: Config      (FAT32)    |
| p3: Log         (EXT4)     |
+----------------------------+
```

### Mounting the Partition

Mounting your new partition can be handled by either `erlinit` or by your Elixir application. To have `erlinit` mount the partition for you, you will need to supply your own `erlinit.config` file to set the required `-m` option:

```
# Mount the configdata partition
# See http://www.linuxfromscratch.org/lfs/view/6.3/chapter08/fstab.html about
# ignoring warning the Linux kernel warning about using UTF8 with vfat.
-m /dev/mmcblk0p3:/root:vfat::;/dev/mmcblk0p4:/mnt/log:ext4::
```

The other option is to handle it in your Elixir code. This can be useful if you want to scan the disk for corruption and reformat or seed it. `Erlinit` can only attempt to mount the partition.

First, we can initialize it:

```elixir
System.cmd("mke2fs", ["-t", "ext4", "-L", "LOGDATA", "/dev/mmcblk0p4"])
```

Then, we can mount the partition:

```elixir
System.cmd("mount", ["-t", "ext4", "/dev/mmcblk0p4", "/mnt/log"])
```
