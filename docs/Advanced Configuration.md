# Advanced Configuration

## Target-Specific Configuration

Different target boards have different layouts for GPIO, LEDs, and more. Often,
this requires that configurations be specified per-target. In this example, we
will be looking at how to configure the LEDs for two different targets. First,
let's start by modifying our `config.exs` to include configs for each target.

```elixir
# config/config.exs

use Mix.Config

import_config "#{Mix.Project.config[:target]}.exs"
```

This will load a different Mix config for each target. Let's say we plan to
support targets `rpi3` and `bbb`. These target devices have different numbers of
user-controlled LEDs and we want each to blink all of its LEDs. The
configuration files would look like this:

```elixir
# config/rpi3.exs

config :blinky, led_list: [ :green ]
config :nerves_leds, names: [ green: "led0" ]
```

```elixir
# config/bbb.exs

config :blinky, led_list: [ :led0, :led1, :led2, :led3 ]

config :nerves_leds, names: [
  led0: "beaglebone:green:usr0",
  led1: "beaglebone:green:usr1",
  led2: "beaglebone:green:usr2",
  led3: "beaglebone:green:usr3"
]
```

## Root Filesystem Overlays

Sometimes, you want to ship additional files and configurations with your
firmware. This is done by telling the firmware assembler where to find a
directory to use as an overlay on the root mount point:

```elixir
# config/config.exs

config :nerves, :firmware,
  rootfs_overlay: "rootfs_overlay"
```

This declares that the contents of the folder at `rootfs_overlay` in your
project root directory will be merged into the root filesystem when `mix
firmware` is called. You can also specify a different `rootfs_overlay` for each
target, as shown in the previous section.

### Overwriting Files in the Root Filesystem

Any files in the `rootfs_overlay` directory will overwrite those present in the
underlying filesystem. This can be useful if you want to change the contents of
included files in the underlying Nerves system. Let's say, for example, that you
want to change the behavior of `erlinit`. You can include your own
`erlinit.config`:

```bash
# rootfs_overlay/etc/erlinit.config

# Uncomment to hang the board rather than rebooting when Erlang exits
#--hang-on-exit

# Enable UTF-8 filename handling in Erlang and custom inet configuration
-e LANG=en_US.UTF-8;LANGUAGE=en;ERL_INETRC=/etc/erl_inetrc;ERL_CRASH_DUMP=/root/crash.dump

# Mount the application partition
-m /dev/mmcblk0p3:/root:ext4::

# Erlang release search path
-r /srv/erlang

# Hostname
-d "/usr/bin/boardid -b bbb -n 4"
-n nerves-%.4s
```

It is important to note that the entire file is replaced when you apply an
overlay, rather than merging the contents. Therefore, you should first obtain
and modify the original file. A trick for doing this is to expand the
`rootfs.squashfs`. You can do this using `unsquashfs`:

```bash
unsquashfs ~/.nerves/artifacts/<cached_system_name>/images/rootfs.squashfs
```

It will be expanded into the current directory under `squashfs-root`

### Overwriting Files in the Boot Partition

Different targets have different boot partition contents. To overwrite files in
the boot partition, you will need to use your own `fwup.conf` file:

```elixir
# config/config.exs

config :nerves, :firmware,
  fwup_conf: "config/fwup.conf"
```

In your included `fwup.conf` file, you can use absolute paths or environment
variables to point to the location of included files.

Let's say you have a Raspberry Pi and you want to change the contents of the
`cmdline.txt` file. You can do this by editing the `fwup.conf` as follows:

```bash
# fwup.conf

file-resource cmdline.txt {
    host-path = "${NERVES_APP}/config/cmdline.txt"
}
```

You can use the `NERVES_APP` environment variable to point to the root of your
Elixir app. This variable is automatically managed for you by
`nerves_bootstrap`.

## Partitions

Nerves firmware uses Master Boot Record (MBR) partition layout, which only
supports 4 primary partitions. By default, the root filesystem partition is
mounted in read-only mode. This prevents corruption of the root filesystem due
to "improper shutdowns". With embedded systems, it is assumed that power can be
removed from the device at any time. This could be problematic if you are
performing a write operation on the filesystem. Because the root filesystem is
read-only, we also add a read/write partition by default, called `app_data` and
mounted at `/root` (the `root` user's home directory). These settings are
defined in `etc/erlinit.config`.

```plain
 +----------------------------+
 | MBR                        |
 +----------------------------+
 | Firmware configuration data|
 | (formatted as uboot env)   |
 +----------------------------+
 | p0*: Boot A        (FAT32) |
 | zImage, bootcode.bin,      |
 | config.txt, etc.           |
 +----------------------------+
 | p0*: Boot B        (FAT32) |
 +----------------------------+
 | p1*: Rootfs A   (squashfs) |
 +----------------------------+
 | p1*: Rootfs B   (squashfs) |
 +----------------------------+
 | p2: Application     (EXT4) |
 +----------------------------+
```

More information about how the App Data partition is initialized and mounted can
be found in the documentation for `nerves_runtime` [Filesystem
Initialization](https://hexdocs.pm/nerves_runtime/readme.html#filesystem-initialization)

### Adding a Partition

You can enable and mount an additional read/write partition by modifying the
`fwup.conf` file. This strategy is typically used to define two locations where
data can be written. Let's say you want to persist some infrequently-written
configuration data and some frequently-written log data. These use-cases could
be segmented into separate partitions so that the important,
infrequently-written configuration data is not corrupted due to a loss of power
while writing the more-frequent, but less-critical, log data.

First, define a new space on the disk for the partition:

```bash
# fwup.conf

# (Sizes are in 512 byte blocks)
define(UBOOT_ENV_OFFSET, 16)
define(UBOOT_ENV_COUNT, 16)  # 8 KB

define(BOOT_A_PART_OFFSET, 63)
define(BOOT_A_PART_COUNT, 38630)
define-eval(BOOT_B_PART_OFFSET, "${BOOT_A_PART_OFFSET} + ${BOOT_A_PART_COUNT}")
define(BOOT_B_PART_COUNT, ${BOOT_A_PART_COUNT})

# Let the rootfs have room to grow up to 128 MiB and align it to the nearest 1
# MB boundary
define(ROOTFS_A_PART_OFFSET, 77324)
define(ROOTFS_A_PART_COUNT, 289044)
define-eval(ROOTFS_B_PART_OFFSET, "${ROOTFS_A_PART_OFFSET} + ${ROOTFS_A_PART_COUNT}")
define(ROOTFS_B_PART_COUNT, ${ROOTFS_A_PART_COUNT})

# Configuration partition
define-eval(CONFIG_PART_OFFSET, "${ROOTFS_B_PART_OFFSET} + ${ROOTFS_B_PART_COUNT}")
define(CONFIG_PART_COUNT, 1048576)

# Log partition
define-eval(LOG_PART_OFFSET, "${CONFIG_PART_OFFSET} + ${CONFIG_PART_COUNT}")
define(CONFIG_PART_COUNT, 1048576)

# ...
```

In this example, we are changing the default `APP_PART` data partition to
`CONFIG_PART` and adding `LOG_PART`.

Next, we change the mapping to include these two new partitions:

```bash
# fwup.conf

# ...

mbr mbr-a {
    partition 0 {
        block-offset = ${BOOT_A_PART_OFFSET}
        block-count = ${BOOT_A_PART_COUNT}
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
        type = 0x83 # Linux
    }
    partition 3 {
        block-offset = ${LOG_PART_OFFSET}
        block-count = ${LOG_PART_COUNT}
        type = 0x83 # Linux
    }
}

mbr mbr-b {
    partition 0 {
        block-offset = ${BOOT_B_PART_OFFSET}
        block-count = ${BOOT_B_PART_COUNT}
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
        type = 0x83 # Linux
    }
    partition 3 {
        block-offset = ${LOG_PART_OFFSET}
        block-count = ${LOG_PART_COUNT}
        type = 0x83 # Linux
    }
}

# ...
```

This layout defines our system as follows:

```plain
+----------------------------+
| MBR                        |
+----------------------------+
| Firmware configuration data|
| (formatted as uboot env)   |
+----------------------------+
| p0*: Boot A        (FAT32) |
| zImage, bootcode.bin,      |
| config.txt, etc.           |
+----------------------------+
| p0*: Boot B        (FAT32) |
+----------------------------+
| p1*: Rootfs A   (squashfs) |
+----------------------------+
| p1*: Rootfs B   (squashfs) |
+----------------------------+
| p2: Config          (EXT4) |
+----------------------------+
| p3: Log             (EXT4) |
+----------------------------+
```

### Mounting the Partition

Mounting your new partition can either be handled by `erlinit` or by your Elixir
application. To have `erlinit` mount the partition for you, you will need to
supply your own `erlinit.config` file to set the required `-m` option:

```bash
# Mount the configdata and logdata partitions
-m /dev/mmcblk0p3:/root:ext4::;/dev/mmcblk0p4:/mnt/log:ext4::
```

The other option is to handle it in your Elixir code. This can be useful if you
want to scan the disk for corruption and reformat or seed it. `erlinit` can only
attempt to mount the partition. You may want to see [how `nerves_runtime` does
this for the default application data
partition](https://github.com/nerves-project/nerves_runtime/blob/master/lib/nerves_runtime/init.ex),
extending it to meet your specific needs.
