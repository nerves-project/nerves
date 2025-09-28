# Using Nerves

## Common terms

In the following guides, support channels, and forums, you may hear the
following terms being used.

| Term            | Definition |
| --------------- | ---------- |
| host            | The computer on which you are editing source code, compiling, and assembling firmware |
| target          | The platform for which your firmware is built (for example, Raspberry Pi Zero W, Raspberry Pi 4, or Beaglebone Black) |
| toolchain       | The tools required to build code for the target, such as compilers, linkers, binutils, and C runtime |
| system          | A lean Buildroot-based Linux distribution that has been customized and cross-compiled for a particular target |
| firmware bundle | A single file that contains an assembled version of everything needed to burn firmware |
| firmware image  | Built from a firmware bundle and contains the partition table, partitions, bootloader, etc. |

## Create a bootable SD card

To create a bootable SD card, use the following command:

```bash
mix firmware.burn
```

or

```bash
MIX_TARGET=rpi0 mix firmware.burn
```

This command will attempt to automatically discover the SD card inserted in your
host.

> #### More than one SD cards or disk images? {: .tip}
>
> `mix firmware.burn` may fail to correctly detect your SD card if you have
> more than one SD card inserted or you have disk images mounted.
>
> If this happens, you can specify the intended device by passing the
> `-d <device>` argument to the command. For example
> `mix firmware.burn -d /dev/rdisk3`
>
> You can alse use `-d <filename>` to specify an output file that is a raw
> image of the SD card. This binary image can be burned to an SD card using
> [Raspberry Pi Imager](https://www.raspberrypi.com/software/), [Etcher](https://www.balena.io/etcher/), `dd`, `Win32DiskImager`, or other image copying utilities.

For more options, refer to the `mix firmware.burn` documentation.

Now that you have your SD card burned, you can insert it into your device and
boot it up.

## Deploying your firmware

Once you have installed your project dependencies you can build a Nerves
Firmware bundle. This bundle contains a minimal Linux platform and your
application packaged as an OTP release.

The first time you compile your application or it's dependencies Nerves will
fetch the System and Toolchain from one of our cache mirrors. These artifacts
are cached locally in `~/.nerves/artifacts` so they can be shared across
projects.

For remote deployment information, see "How do I push firmware updates
remotely?" in the [FAQ](faq.md#how-do-i-push-firmware-updates-remotely).

> #### Deleting cached artifacts {: .tip}
>
> Running `rm -fr ~/.nerves` is a safe operation as any archives
> that you're using will be re-downloaded when you next run `mix deps.get`.