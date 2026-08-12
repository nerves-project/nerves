# Changelog

This project does NOT follow semantic versioning. The version increases as
follows:

1. Major version updates are breaking updates to the build infrastructure.
   These should be very rare.
2. Minor version updates are made for every major Buildroot release. This
   may also include Erlang/OTP and Linux kernel updates. These are made four
   times a year shortly after the Buildroot releases.
3. Patch version updates are made for Buildroot minor releases, Erlang/OTP
   releases, and Linux kernel updates. They're also made to fix bugs and add
   features to the build infrastructure.

## v2.1.1

This is a security and bug fix release.

* Changes
  * Include rootfs.tar for use with Nerves 2.0 development builds (ignored by Nerves 1.x)

* Package updates
  * [nerves_system_br 1.34.1](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.34.1)

## v2.1.0

This is a major update with security and feature updates throughout.

* Changes
  * Support delta firmware updates for files in the boot partition
  * Drop pigpio due to Buildroot removing it and it doesn't compile with GCC 15.3

* Updated dependencies
  * [nerves_system_br v1.34.0 release notes](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.34.0)
  * GCC 15.3.0
  * [Erlang/OTP 29.0.2](https://erlang.org/download/OTP-29.0.2.README.md)
  * linux 6.18.33 (Raspberry Pi 1.20260521 tag)
  * [Buildroot 2026.05](https://lore.kernel.org/buildroot/87fr2wpxhj.fsf@dell.be.48ers.dk/T/)

## v2.0.4

This is a security and bug fix release.

* Package updates
  * [nerves_system_br 1.33.9](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.33.9)
    * [Erlang/OTP 28.5.0.1](https://erlang.org/download/OTP-28.5.0.1.README.md)

## v2.0.3

This is a security and bug fix release.

* Changes
  * Use https for the backup site

* Package updates
  * [nerves_system_br 1.33.7](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.33.7)
    * [Erlang/OTP 28.5](https://erlang.org/download/OTP-28.5.README.md)
    * [fwup 1.16.0](https://github.com/fwup-home/fwup/releases/tag/v1.16.0)
## v2.0.2

This is a security update.

* Package updates
  * [nerves_system_br 1.33.5](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.33.5)
    * [Erlang/OTP 28.4.2](https://erlang.org/download/OTP-28.4.2.README.md)
    * [Buildroot 2025.11.3](https://lore.kernel.org/buildroot/124c21a6-5810-495e-8b85-f3db41afa1a9@rnout.be/T/)

## v2.0.1

This is a security update.

* Package updates
  * [nerves_system_br 1.33.4](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.33.4)
    * [Erlang/OTP 28.4.1](https://erlang.org/download/OTP-28.4.1.README.md)
    * [Buildroot 2025.11.2](https://lore.kernel.org/buildroot/de9c890a-760a-4e6d-86b8-f8e5000a07ff@rnout.be/T/)

## v2.0.0

This is a major update of `nerves_system_rpi0` that changes the MicroSD/eMMC
layout in order to support automatic rollback of non-working firmware updates.

**IMPORTANT** This is a one way upgrade. Going back to the old partitioning
requires manually reflashing of the RPi's storage.

Previous releases assumed that firmware updates worked. This one requires that
firmware images mark themselves as good using
`Nerves.Runtime.validate_firmware/0`. See `Nerves.Runtime` for more information
on this. Firmware not marked as good reverts back to the previous version.

* Changes
  * Fix camera support by enabling the unicam-legacy Linux device driver
  * Enabled multipath TCP support in the Linux kernel
  * Deleted all use of `nerves_fw_active` since it was sometimes incorrect and
    caused confusion
  * Add gpio-poweroff overlay to support Soleil

* Package updates
  * [nerves_system_br 1.33.2](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.33.2)
    * [Erlang/OTP 28.3.1](https://erlang.org/download/OTP-28.3.1.README.md)
    * [Buildroot 2025.11.1](https://lore.kernel.org/buildroot/f6496994-b279-46f4-b554-7dbe2df92782@rnout.be/T/)

## v1.33.0

This is a major Buildroot and Linux update. It should be seamless for most
1.32.0 users.

* Changes
  * Refresh `ramoops-overlay.dts`. This actually changes the default pstore
    settings to reserve less DRAM based on experience of not needing nearly as
    much. Settings can be overridden now via the `config.txt`.
  * Use EEx to generate the `fwup.conf`. This removes a lot of repetition. If
    you've made a custom `fwup.conf`, please review git commit log for details.

* Updated dependencies
  * Linux 6.12.47
  * [nerves_system_br 1.33.0](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.33.0)
    * [Buildroot 2025.11](https://lore.kernel.org/buildroot/87bjk439tj.fsf@dell.be.48ers.dk/T/)
    * [Erlang/OTP 28.3](https://erlang.org/download/OTP-28.3.README.md)
    * [fwup 1.15.0](https://github.com/fwup-home/fwup/releases/tag/v1.15.0)
    * [erlinit 1.15.1](https://github.com/nerves-project/erlinit/releases/tag/v1.15.1)
    * [nerves_heart 2.5.0](https://github.com/nerves-project/nerves_heart/releases/tag/v2.5.0)
    * [boardid 1.15.0](https://github.com/nerves-project/boardid/releases/tag/v1.15.0)

## v1.32.0

This is a major Erlang and Buildroot update. This updates from Erlang/OTP 27 to
Erlang/OTP 28.

* Changes
  * Remove unneeded call to `rngd` and the `rng-tools` package. This was
    formerly needed to provide entropy to Linux during initialization.

* Package updates
  * [nerves_system_br v1.32.3 release notes](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.32.3)

* Updated dependencies
  * [Erlang/OTP 28.1.1](https://erlang.org/download/OTP-28.1.1.README.md)
  * [Buildroot 2025.05.2](https://lore.kernel.org/buildroot/7bed9b2e-a9d3-476b-84d6-61134e2f726f@rnout.be/T/)

## v1.31.4

* Changes
  * Synchronize and fix Raspberry Pi camera settings

## v1.31.3

This is an important security/bug fix that addresses Erlang CVEs for the ssh
module (see Erlang release notes).

* Package updates
  * [nerves_system_br v1.31.7](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.31.7). Also
    see [nerves_system_br v1.31.6](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.31.6)

* Important derived package updates
  * [Erlang/OTP 27.3.4.3](https://erlang.org/download/OTP-27.3.4.3.README.md)
  * [Buildroot 2025.02.6](https://lore.kernel.org/buildroot/b051d400-debc-4269-975a-b2992eed8d61@rnout.be/T/)

## v1.31.2

This is a security/bug fix release.

* Package updates
  * [nerves_system_br v1.31.5](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.31.5)

* Important derived package updates
  * [Erlang/OTP 27.3.4.2](https://erlang.org/download/OTP-27.3.4.2.README.md)
  * [fwup 1.13.2](https://github.com/fwup-home/fwup/releases/tag/v1.13.2)

## v1.31.1

This is a security/bug fix release.

* Changes
  * Disabled `PREEMPT_RT` due to reports of instability on 32-bit Raspberry Pis.

* Package updates
  * [Erlang/OTP 27.3.4.1](https://erlang.org/download/OTP-27.3.4.1.README.md)
  * [Buildroot 2025.02.3 (fixed 2025.02.2)](https://lore.kernel.org/buildroot/49d039c0-8121-4a91-8a69-889376f85c71@rnout.be/T/)
  * Raspberry Pi WiFi firmware 1:20240709-2~bpo12+1+rpt3
  * [rpi-libcamera v0.5.0+rpt20250429](https://github.com/raspberrypi/libcamera/releases/tag/v0.5.0%2Brpt20250429)
  * rpicam-apps 1.7.0
  * [erlinit 1.14.3](https://github.com/nerves-project/erlinit/releases/tag/v1.14.3)
  * [fwup 1.13.0](https://github.com/fwup-home/fwup/releases/tag/v1.13.0)

## v1.31.0

This is a major Buildroot update.

Please see the [nerves_system_br v1.31.0 release notes](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.31.0)
for additional information if you've forked this system.

* Updated dependencies
  * [Buildroot 2025.02.1](https://lore.kernel.org/buildroot/60b8483c-b717-41ce-a406-bceb71c3a089@rnout.be/T/)

## v1.30.1

This is a security/bug fix update.

* Updated dependencies
  * [Erlang/OTP 27.3.3](https://erlang.org/download/OTP-27.3.3.README)
  * [nerves_system_br v1.30.1](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.30.1)

## v1.30.0

This is a major Buildroot update.

Please see the [nerves_system_br v1.30.0 release notes](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.30.0)
for upgrade instructions if you've forked this system.

* Changes
  * Add REUSE compliance to help improve OSS copyright and licensing accuracy
  * Update Raspberry Pi libraries and firmware to latest releases

* Updated dependencies
  * [Erlang/OTP 27.3](https://erlang.org/download/OTP-27.3.README.md)
  * [Buildroot 2024.11.2](https://lore.kernel.org/buildroot/87v7t3nyls.fsf@dell.be.48ers.dk/T/)
  * Linux 6.6.74 (Raspberry Pi 1.20250127 release)
  * rpicam-apps 1.5.3
  * rpi-libcamera v0.3.2+rpt20241119
  * rpi-distro-firmware-nonfree 1:20230625-2+rpt3

## v1.29.1

This is a security/bug fix update.

* Updated dependencies
  * [nerves_system_br v1.29.3](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.29.3)
  * [Buildroot 2024.08.3](https://lore.kernel.org/buildroot/874j3e17ek.fsf@dell.be.48ers.dk/T/)
  * [Erlang/OTP 27.2](https://erlang.org/download/OTP-27.2.README)
  * Linux 6.6.64 with the Raspberry Pi and PREEMPT_RT patches
  * [fwup v1.12.0](https://github.com/fwup-home/fwup/releases/tag/v1.12.0)

## v1.29.0

This is a major Erlang and Buildroot update.

Please see the [nerves_system_br v1.29.0 release notes](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.29.0)
for upgrade instructions if you've forked this system.

* Changes
  * Applied and enabled the Real-Time Linux patch set, PREEMPT_RT. Please see
    write-ups on the web for benefits and how to use. The impact of this patch
    shouldn't be noticeable to most Nerves users.
  * Switch CPU frequency governor from conservative to the more modern
    schedutil. See [LWN article](https://lwn.net/Articles/682391/) for details.

* Updated dependencies
  * [nerves_system_br v1.29.1](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.29.1)
  * [Buildroot 2024.08.2](https://lore.kernel.org/buildroot/871pzex7gn.fsf@dell.be.48ers.dk/T/)
  * Linux 6.6.51 (Raspberry Pi stable_20241008 release)

## v1.28.1

This is a security/bug fix update.

* Fixes
  * Device tree overlays are now included for all official Raspberry Pi cameras
    and should load automatically

* Updated dependencies
  * [nerves_system_br v1.28.3](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.28.3)
  * [Buildroot 2024.05.2](https://lore.kernel.org/buildroot/87zfpfh147.fsf@dell.be.48ers.dk/T/)
  * [Erlang/OTP 27.0.1](https://erlang.org/download/OTP-27.0.1.README)

## v1.28.0

This is a major Erlang, Buildroot, Linux and Raspberry Pi display and camera
update. Please read below and expect to spend some time on the update.

Please see the [nerves_system_br v1.28.0 release notes](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.28.0)
for upgrade instructions if you've forked this system.

* Changes
  * Elixir 1.17 and Erlang/OTP 27 support
  * Switch from the Raspberry Pi's deprecated MMAL media support to DRM and
    libcamera. This is a big change if you use the display or camera that has
    been a long time coming. Please plan some time to make the upgrade.
  * Upgrade from Linux 6.1 to Linux 6.6
  * Reduce copy/pasted definitions in the `fwup.conf` by extracting them to
    `fwup_include/fwup-common.conf`. (No functional changes)

* Fixes
  * The serial numbers returned by `Nerves.Runtime.serial_number/0` now contain
    the whole serial number. If you forked this system, check the
    `boardid.config` and `erlinit.config` for the changes and to keep the
    hostname the same.

* Updated dependencies
  * Linux 6.6.31 (Raspberry Pi stable_20240529 release)
  * [nerves_system_br v1.28.1](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.28.1)
  * [Buildroot 2024.05](https://lore.kernel.org/buildroot/87bk46tjk2.fsf@dell.be.48ers.dk/T/)
  * [Erlang/OTP 27.0](https://erlang.org/download/OTP-27.0.README)

## v1.27.1

This is a security/bug fix update.

* Package updates
  * [Erlang/OTP 26.2.5](https://erlang.org/download/OTP-26.2.5.README)
  * [Buildroot 2024.02.1](https://lore.kernel.org/buildroot/87jzlp9u5e.fsf@48ers.dk/T/)

## v1.27.0

This is a major Buildroot update.

Please see the [nerves_system_br v1.27.0 release notes](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.27.0)
for upgrade instructions if you've forked this system.

* Changes
  * The `libcamera` and `rpicam_apps` packages have been replaced with the
    Raspberry Pi-forked versions for better compatibility. Please see
    `nerves_system_br` release notes.
  * Add back `CONFIG_RASPBERRYPI_GPIOMEM` to support the `dht` library.

* Updated dependencies
  * Linux 6.1.73 (Raspberry Pi 20240124 release)
  * [nerves_system_br v1.27.0](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.27.0)
  * [Buildroot 2024.02](https://lore.kernel.org/buildroot/87msrczp4z.fsf@48ers.dk/)
  * [Erlang/OTP 26.2.3](https://erlang.org/download/OTP-26.2.3.README)

## v1.26.0

This is a major Buildroot update.

Please see the [nerves_system_br v1.26.0 release notes](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.26.0)
for upgrade instructions if you've forked this system.

* Updated dependencies
  * [Erlang/OTP 26.2.2](https://erlang.org/download/OTP-26.2.2.README)
  * [nerves_system_br v1.26.1](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.26.1)
  * [Buildroot 2023.11.1](https://lore.kernel.org/buildroot/87cyu2k2gu.fsf@48ers.dk/T/)

## v1.25.1

This is a security/bug fix update.

 Package updates
  * [Erlang/OTP 26.2.1](https://erlang.org/download/OTP-26.2.1.README)
  * [nerves_heart 2.3.0](https://github.com/nerves-project/nerves_heart/releases/tag/v2.3.0)

## v1.25.0

This is a major Buildroot, toolchain, and Linux kernel update that also adds
support for using Scenic without customizing the system.

Please see [nerves_system_br v1.25.0 release notes](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.25.0)
for upgrade instructions if you've forked this system.

* New features
  * Add libcairo for [Scenic](https://github.com/ScenicFramework/scenic) support

* Updated dependencies
  * Linux 6.1.63 (Raspberry Pi stable_20231123 release)
  * [nerves_system_br v1.25.2](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.25.2)
  * [Buildroot 2023.08.4](https://lore.kernel.org/buildroot/87o7f6t7fs.fsf@48ers.dk/T/)
  * [Erlang/OTP 26.1.2](https://erlang.org/download/OTP-26.1.2.README)

## v1.24.1

This is a security/bug fix update.

* Package updates
  * [nerves_system_br v1.24.1](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.24.1)
  * [Erlang/OTP 26.1.1](https://erlang.org/download/OTP-26.1.1.README)
  * [Buildroot 2023.05.3](https://lore.kernel.org/buildroot/87h6ngup34.fsf@48ers.dk/T/)

## v1.24.0

This is a Buildroot version update that appears to mostly contain bug and
security fixes. It should be a low risk upgrade from v1.23.2.

* New features
  * Support factory reset, preventing firmware reverts. See [Nerves.Runtime.FwupOps](https://nerves-runtime.hexdocs.pm/Nerves.Runtime.FwupOps.html)

* Updated dependencies
  * [nerves_system_br v1.24.0](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.24.0)
  * [Buildroot 2023.05.2](https://lore.kernel.org/buildroot/87ledrkrpp.fsf@48ers.dk/T/), [2023.05.1](https://lore.kernel.org/buildroot/87351m8qm4.fsf@48ers.dk/T/), [2023.05](https://lore.kernel.org/buildroot/87r0qn2c77.fsf@48ers.dk/T/)
  * [Erlang/OTP 26.1](https://erlang.org/download/OTP-26.1.README)

## v1.23.2

* Updated dependencies
  * [nerves_system_br v1.23.3](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.23.3)

## v1.23.1

This is a bug and security fix update. It should be a low risk upgrade.

* Fixes
  * Fix CTRL+R over ssh

* Updated dependencies
  * [nerves_system_br v1.23.2](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.23.2)
  * [Buildroot 2023.02.2](https://lore.kernel.org/buildroot/87y1je6wva.fsf@48ers.dk/T/)

## v1.23.0

This is a major update that brings in Erlang/OTP 26, Buildroot 2023.02.2, Linux
5.15.84, and Raspberry Pi firmware updates.

* New features
  * CA certificates are included for OTP 26.

* Updated dependencies
  * [nerves_system_br v1.23.1](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.23.1)
  * [Buildroot 2023.02.2](https://lore.kernel.org/buildroot/87wn03ifbl.fsf@48ers.dk/T/)
  * [Erlang/OTP 26.0.2](https://erlang.org/download/OTP-26.0.2.README)
  * Linux 5.15.84 (Raspberry Pi Linux tag 1.20230106)

## v1.22.2

This is a bug and security fix update. It should be a low risk upgrade from
v1.22.1.

* Updated dependencies
  * [nerves_system_br v1.22.5](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.22.5)
  * [Buildroot 2022.11.3](https://lore.kernel.org/buildroot/878rfuxbxx.fsf@dell.be.48ers.dk/T/)

## v1.22.1

This is a bug fix and Erlang version bump from 25.2 to 25.2.3. It should be a
low risk upgrade from v1.22.0.

* Fixes
  * Set Erlang crash dump timer to 5 seconds, so if an Erlang crash dump does
    happen, it will run for at most 5 seconds. See erlinit.conf.

* Updated dependencies
  * [nerves_system_br v1.22.3](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.22.3)
  * [Buildroot 2022.11.1](https://lore.kernel.org/buildroot/87ilh4dvax.fsf@dell.be.48ers.dk/T/#u)

## v1.22.0

This is a Buildroot version update that appears to mostly contain bug and
security fixes. It should be a low risk upgrade from v1.21.2.

* Updated dependencies
  * [nerves_system_br v1.22.1](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.22.1)
  * [Buildroot 2022.11](http://lists.busybox.net/pipermail/buildroot/2022-December/656980.html)
  * GCC 12.2

## v1.21.2

* Changes
  * Two Buildroot patch updates and an Erlang minor version update
  * Nerves Heart v2.0 is now included. Nerves Heart connects the Erlang runtime
    to a hardware watchdog. v2.0 has numerous updates to improve information
    that you can get and also has more safeguards to avoid conditions that could
    cause a device to hang forever.

* Updated dependencies
  * linux 5.15.78 (RPi 1.20221104)
  * [nerves_system_br v1.21.6](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.21.6)
  * [Erlang/OTP 25.2](https://erlang.org/download/OTP-25.2.README)
  * [Buildroot 2022.08.3](https://lore.kernel.org/buildroot/87r0x7z5cw.fsf@dell.be.48ers.dk/T/#u)
  * [nerves_heart v2.0.2](https://github.com/nerves-project/nerves_heart/releases/tag/v2.0.2)

## v1.21.1

* Changes
  * Fix regression when building on x86_64 Linux where wrong toolchain was used.
  * Reduce first-time Linux kernel download by using tarball source

* Updated dependencies
  * [nerves_system_br v1.21.2](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.21.2)
  * [Erlang/OTP 25.1.2](https://erlang.org/download/OTP-25.1.2.README)

## v1.21.0

* Changes
  * Support aarch64 Linux builds
  * Add libdtc to support runtime loading of device tree overlays

* Updated dependencies
  * [nerves_system_br v1.21.1](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.21.1)
    and also see [nerves_system_br v1.21.0](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.21.0)
  * [Buildroot 2022.08.1](http://lists.busybox.net/pipermail/buildroot/2022-October/652816.html)
  * [Erlang/OTP 25.1.1](https://erlang.org/download/OTP-25.1.1.README)

## v1.20.2

* Updated dependencies
  * [nerves_system_br v1.20.6](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.20.6)
  * [Erlang/OTP 25.0.4](https://erlang.org/download/OTP-25.0.4.README)
  * [Buildroot 2022.05.2](http://lists.busybox.net/pipermail/buildroot/2022-August/650546.html)
  * Also see [Buildroot 2022.05.1 changes](http://lists.busybox.net/pipermail/buildroot/2022-July/647814.html)

## v1.20.1

* Updated dependencies
  * [nerves_system_br v1.20.4](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.20.4)
  * [Erlang/OTP 25.0.3](https://erlang.org/download/OTP-25.0.3.README)

## v1.20.0

This release updates to Buildroot 2022.05, Linux 5.15.32 (from Linux 5.10) and
uses GCC 11.3 (from GCC 10.3). The Linux kernel upgrade could introduce a
regression, so please verify hardware-specific functionality in your firmware.

If you have cloned this repository for a custom system, please make sure that
you have `CONFIG_NOP_USB_XCEIV=y` in your Linux kernel configuration.

* Updated dependencies
  * [nerves_system_br v1.20.3](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.20.3)
  * [Buildroot 2022.05](http://lists.busybox.net/pipermail/buildroot/2022-June/644349.html)
  * [Erlang/OTP 25.0.2](https://erlang.org/download/OTP-25.0.2.README)

## v1.19.0

This release updates to Buildroot 2022.02.1 and OTP 25.0. While this should be
an easy update for most projects, many programs have been updated. Please review
the changes in the updated dependencies for details.

* Updated dependencies
  * [nerves_system_br v1.19.0](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.19.0)
  * [Buildroot 2022.02.1](http://lists.busybox.net/pipermail/buildroot/2022-April/640712.html). Also see [Buildroot 2022.02](http://lists.busybox.net/pipermail/buildroot/2022-March/638160.html)
  * [Erlang/OTP 25.0](https://erlang.org/download/OTP-25.0.README)

## v1.18.4

This release bumps Erlang to 24.3.2 and should be a low risk upgrade from the
previous release.

* Changes
  * Pull in upstream Linux SquashFS patch to improve file system performance

* Updated dependencies
  * [nerves_system_br v1.18.6](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.18.6)

## v1.18.3

This is a Buildroot and Erlang bug and security fix release. It should be a low
risk upgrade from the previous release.

* Updated dependencies
  * [nerves_system_br v1.18.5](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.18.5)

## v1.18.2

This is a Buildroot and Erlang bug fix release. It should be a low risk upgrade
from the previous release.

* Updated dependencies
  * [nerves_system_br v1.18.4](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.18.4)

* Changes
  * Specify CPU-specific flags when compiling NIFs and ports. This fixes an
    issue where some optimizations could not be enabled in NIFs even though it
    should be possible to have them. E.g., ARM NEON support for CPUs that have
    it.
  * Build the Wireguard kernel driver. This is a small device driver that
    enables a number of VPN-based use cases.

## v1.18.1

* Updated dependencies
  * [nerves_system_br v1.18.3](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.18.3)

* Changes
  * The `cpufreq` directories are available again. This was a regression that
    would break code that manually adjusted the CPU frequency.
  * Programs that use OpenMP will run now. The OpenMP shared library
    (`libgomp.so`) was supplied by the toolchain, but not copied.

## v1.18.0

This release updates to Buildroot 2021.11 and OTP 24.2. If you have made a
custom system, please review the `nerves_system_br` [release
notes](https://github.com/nerves-project/nerves_system_br/blob/v1.18.2/CHANGELOG.md#v1180)
since Buildroot 2021.11 changed some Raspberry Pi firmware options.

* Updated dependencies
  * [nerves_system_br v1.18.2](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.18.2)
  * [Buildroot 2021.11](http://lists.busybox.net/pipermail/buildroot/2021-December/629911.html)
  * [Erlang/OTP 24.2](https://erlang.org/download/OTP-24.2.README)
  * [Raspberry Pi WiFi firmware](https://github.com/RPi-Distro/firmware-nonfree/blob/bullseye/debian/changelog)
  * Linux 5.10.88 with Raspberry Pi patches
  * GCC 10.3

* Improvements
  * Support for the `dl.nerves-project.org` backup site. Due to a GitHub outage
    in November, there was a 2 day period of failing builds since some packages
    could not be downloaded. We implemented the backup site to prevent this in
    the future. This update is in the `nerves_defconfig`.
  * Use new build ORB on CircleCI. This ORB will shorten build times to fit in
    CircleCI's new free tier limits. Please update if building your own systems.

## v1.17.3

* Updated dependencies
  * [nerves_system_br v1.17.4](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.17.4)
  * [Buildroot 2021.08.2](http://lists.busybox.net/pipermail/buildroot/2021-November/628323.html)
  * [Erlang/OTP 24.1.7](https://erlang.org/download/OTP-24.1.7.README).

## v1.17.2

This release updates the Linux kernel from 5.4 to 5.10 to follow the Raspberry
Pi OS.

If you have a Raspberry Pi Zero 2 W, support is now available for it in
`nerves_system_rpi3a`.

* Updated dependencies
  * [nerves_system_br v1.17.3](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.17.3)
  * [Erlang/OTP 24.1.4](https://erlang.org/download/OTP-24.1.4.README).
  * Linux 5.10.63 with Raspberry Pi patches

## v1.17.1

This is a security/bug fix patch release. It should be safe to update for
everyone.

* Updated dependencies
  * [nerves_system_br v1.17.1](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.17.1)
  * [Buildroot 2021.08.1](http://lists.busybox.net/pipermail/buildroot/2021-October/625642.html)
  * [Erlang/OTP 24.1.2](https://erlang.org/download/OTP-24.1.2.README)

* Improvements
  * Include software versioning and licensing info (see legal-info directory in
    artifact)

## v1.17.0

This release updates to Buildroot 2021.08 and OTP 24.1. If you have made a
custom system off this one, please review the `nerves_system_br v1.17.0` release
notes.

* Updated dependencies
  * [nerves_system_br v1.17.0](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.17.0)
  * [Buildroot 2021.08](http://lists.busybox.net/pipermail/buildroot/2021-September/622072.html)
  * [Erlang/OTP 24.1](https://erlang.org/download/OTP-24.1.README)

## v1.16.2

This release updates Erlang/OTP from 24.0.3 to 24.0.5 and Buildroot from 2021.05
to 2021.05.1. Both of these are security/bug fix updates. This is expected to be
a safe upgrade from v1.16.1 for all users.

* Updated dependencies
  * [nerves_system_br v1.16.4](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.16.1)
  * [Erlang/OTP 24.0.5](https://erlang.org/download/OTP-24.0.5.README)

* Improvements
  * Support for the Adafruit Speaker Bonnet (See PR #214 for details)
  * Beta support for using a `runtime.exs` script for runtime configuration.
  * Added a `provision` task to the `fwup.config` to enable re-provisioning a
    MicroSD card without changing its contents.
  * Adds a default `/etc/sysctl.conf` that enables use of ICMP in Erlang. This
    requires `nerves_runtime v0.11.5` or later to automatically load the sysctl
    variables. With it using `:gen_udp` to send/receive ICMP will "just work".
    It also makes it easier to add other sysctl variables if needed.

## v1.16.1

This release updates Nerves Toolchains to v1.4.3 and OTP 24.0.3. It should be
safe for everyone to apply.

* Updated dependencies
  * [nerves_system_br v1.16.1](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.16.1)
  * [Erlang/OTP 24.0.3](https://erlang.org/download/OTP-24.0.3.README)
  * [nerves toolchains v1.4.3](https://github.com/nerves-project/toolchains/releases/tag/v1.4.3)

## v1.16.0

This release updates to Buildroot 2021.05 and OTP 24.0.2. If you have made a
custom system off this one, please review the `nerves_system_br v1.16.0` release
notes.

* Updated dependencies
  * [nerves_system_br v1.16.0](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.16.0)
  * [Buildroot 2021.05](http://lists.busybox.net/pipermail/buildroot/2021-June/311946.html)
  * [Erlang/OTP 24.0.2](https://erlang.org/download/OTP-24.0.2.README)

* Improvements
  * This release now contains debug symbols and includes the Build-ID in the
    ELF headers. This makes it easier to get stack traces from C programs. As
    before, the Nerves tooling strips all symbols from firmware images, so this
    won't make programs bigger.
  * Enable compile-time `wpa_supplicant` options to support WPA3, mesh
    networking, WPS and autoscan.
  * Add `core_freq=250` to the default `config.txt` so that Bluetooth can work
    out of the box. See [Raspberry Pi UART
    Config](https://www.raspberrypi.org/documentation/configuration/uart.md)

## v1.15.1

This is a security/bug fix release that updates to Buildroot 2021.02.1 and OTP
23.3.1. It should be safe for everyone to apply.

* Improvements
  * espeak has been removed from the default install to trim 13 MB off the root
    filesystem

* Updated dependencies
  * [nerves_system_br v1.15.1](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.15.1)
  * [Buildroot 2021.02](http://lists.busybox.net/pipermail/buildroot/2021-April/307970.html)
  * [Erlang/OTP 23.3.1](https://erlang.org/download/OTP-23.3.1.README)

## v1.15.0

This release updates to Buildroot 2021.02 and OTP 23.2.7. If you have made a
custom system off this one, please review the `nerves_system_br v1.15.0` release
notes.

The Nerves toolchain has also been updated to v1.4.2. This brings in Linux 4.14
headers to enable use of cdev and eBPF. This won't affect most users.

* Updated dependencies
  * [nerves_system_br v1.15.0](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.15.0)
  * [Buildroot 2021.02](http://lists.busybox.net/pipermail/buildroot/2021-March/305168.html)
  * [Erlang/OTP 23.2.7](https://erlang.org/download/OTP-23.2.7.README)
  * [nerves toolchains v1.4.2](https://github.com/nerves-project/toolchains/releases/tag/v1.4.2)

## v1.14.1

This is a patch release for v1.14.0 which fixes the ABI spec passed for zigler.

* Improvements
  * A few unused directories in `/etc` have been removed. These primarily were
    network initialization script directories that aren't used on Nerves, but
    were provided by default by Buildroot.

## v1.14.0

This release updates to Buildroot 2020.11.2, GCC 10.2 and OTP 23.2.4.

When migrating custom systems based on this one, please be aware of the
following important changes:

* There's a new `getrandom` syscall that is made early in BEAM startup. This
  blocks the BEAM before `rngd` can be started to provide entropy. The
  workaround is to start `rngd` from `erlinit`. See `erlinit.config`.
* Hardware float is enabled (`eabihf`). If you have pre-built binaries, you will
  need to compile them since previous `eabi` was used.
* The GCC 10.2.0 toolchain has a different name that calls out "nerves" as the
  vendor and the naming is now more consistent with other toolchain providers.
* Experimental support for tooling that requires more information about the
  target has been added. The initial support focuses on zigler.

* Updated dependencies
  * [nerves_system_br: bump to v1.14.4](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.14.4)
  * [Buildroot 2020.11.2](http://lists.busybox.net/pipermail/buildroot/2021-January/302574.html)
  * [Erlang/OTP 23.2.4](https://erlang.org/download/OTP-23.2.4.README)
  * [Nerves toolchains 1.4.1](https://github.com/nerves-project/toolchains/releases/tag/v1.4.1)

## v1.13.3

This is a bug fix release and contains no major changes.

* Updated dependencies
  * [nerves_system_br: bump to v1.13.7](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.13.7)
  * [Erlang/OTP 23.1.5](https://erlang.org/download/OTP-23.1.5.README)

## v1.13.2

This release includes a patch release update to
[Buildroot 2020.08.2](http://lists.busybox.net/pipermail/buildroot/2020-November/296830.html).

* Updated dependencies
  * [nerves_system_br: bump to v1.13.5](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.13.5)
  * [erlinit 1.9.0](https://github.com/nerves-project/erlinit/releases/tag/v1.9.0)

* Improvements
  * Switched source for built-in WiFi module firmware. This pulls in newer
    firmware versions that were found to fix issues on the Raspberry Pi 4. It
    may improve built-in WiFi on other Raspberry Pis.

## v1.13.1

The main change in this release is to bump the Linux kernel to 5.4. This follows
the kernel update in the Raspberry Pi OS.

If you have based a custom system off of this one, please inspect the
`nerves_defconfig` for WiFi firmware changes. WiFi firmware is no longer being
pulled from the `rpi-wifi-firmware` since that package is out of date.

* Updated dependencies
  * [nerves_system_br: bump to v1.13.4](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.13.4)
  * [Erlang/OTP 23.1.4](https://erlang.org/download/OTP-23.1.4.README)
  * [boardid 1.10.0](https://github.com/nerves-project/boardid/releases/tag/v1.10.0)

* Improvements
  * Enabled reproducible builds in Buildroot to remove some timestamp and build
    path differences in firmware images. This helps delta firmware updates.
  * The memory cgroup controller is no longer enabled by default. This was an
    upstream change. As a result, the memory cgroup directory is no longer
    mounted.

## v1.13.0

This release updates to [Buildroot
2020.08](http://lists.busybox.net/pipermail/buildroot/2020-September/290797.html) and OTP 23.1.1.

* Updated dependencies
  * [nerves_system_br: bump to v1.13.2](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.13.2)
  * [Erlang/OTP 23.1.1](https://erlang.org/download/OTP-23.1.1.README)
  * [erlinit 1.8.0](https://github.com/nerves-project/erlinit/releases/tag/v1.8.0)
  * [nerves 1.7.0](https://github.com/nerves-project/nerves/releases/tag/v1.7.0)

* New features
  * Added support for updating the root filesystem using firmware patches.
    See the [firmware patch docs](https://nerves.hexdocs.pm/experimental-features.html#content) for more information.

## v1.12.2

This release updates to [Buildroot
2020.05.1](http://lists.busybox.net/pipermail/buildroot/2020-July/287824.html)
and OTP 23.0.3 which are both bug fix releases.

* Updated dependencies
  * [nerves_system_br: bump to v1.12.4](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.12.4)
  * [Erlang/OTP 23.0.3](https://erlang.org/download/OTP-23.0.3.README)
  * [nerves_heart v0.3.0](https://github.com/nerves-project/nerves_heart/releases/tag/v0.3.0)

* New features
  * The `/data` directory now exists for storing application-specific data. It
    is currently a symlink to `/root`. Using `/data` will eventually be
    encouraged over `/root` even though currently there is no advantage. This
    change makes it possible to start migrating paths in applications and
    libraries.

* Fixes
  * Fixed old references to the `-Os` compiler flag. All C/C++ code will default
    to using `-O2` now.

## v1.12.1

* Fixes
  * Remove `nerves_system_linter` from hex package. This fixes mix dependency
    errors in projects that reference systems with different
    `nerves_system_linter` dependency specs.

## v1.12.0

This release updates the system to use Buildroot 2020.05 and Erlang/OTP 23.
Please see the respective release notes for updates and deprecations in both
projects for changes that may affect your application.

* Updated dependencies
  * [nerves_system_br v1.12.0](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.12.0)
  * [Erlang/OTP 23.0.2](https://erlang.org/download/OTP-23.0.2.README)
  * [Linux 4.19.118 (Raspberry Pi 1.2020601 tag)](https://github.com/raspberrypi/linux/tree/raspberrypi-kernel_1.20200601-1)
  * [Raspberry Pi firmware 1.2020601](https://github.com/raspberrypi/firmware/tree/1.20200601)

## v1.11.2

* Updated dependencies
  * [nerves_system_br v1.11.4](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.11.4)
  * Erlang 22.3.4.1
  * fwup 1.7.0

## v1.11.1

* Updated dependencies
  * [nerves_system_br v1.11.2](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.11.2)
  * Erlang 22.3.1
  * erlinit 1.7.0 - tty initialization support
  * fwup 1.6.0 - xdelta3/VCDIFF patch support
  * Enable unixodbc so that Erlang's odbc application can be used in projects

## v1.11.0

This release updates Buildroot to 2020.02 and upgrades gcc from 8.3 to 9.2.
While this is a minor version bump due to the Buildroot release update, barring
advanced usage of Nerves, this is a straightforward update from v1.10.2.

* Updated dependencies
  * [nerves_system_br v1.11.0](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.11.0)
  * linux 4.19.97 (raspberrypi-kernel_1.20200212-1 tag)
  * Erlang 22.2.8

## v1.10.2

* Fixes
  * This fixes a regression on OSX where the USB gadget Ethernet would
    incorrectly try to go into RNDIS mode and not work. Gadget Ethernet works
    with this fix on Linux and OSX. It also works on Windows with a driver
    installed. See the README.md for details.

* Updated dependencies
  * [nerves_system_br v1.10.2](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.10.2)
  * Erlang 22.2.4

## v1.10.1

This release changes the behavior of the gadget port as well as the UART pins
on the GPIO header. The gadget driver has been changed to use g_ether. This
provides a more stable network connection at the expense of the virtual serial
port. Console access has been output to the UART. If you were using the UART
to connect to peripherals, you will need to disable the console.
See: https://nerves.hexdocs.pm/advanced-configuration.html#overwriting-files-in-the-boot-partition
for more information.

* Enhancements
  * Set `expand=true` on the application data partition. This will only take
    effect for users running the complete task, fwup will not expand application
    data partitions that exist during upgrade tasks.
  * linux: swap the cdc composite gadget for g_ether

* Updated dependencies
  * [nerves_system_br v1.10.1](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.10.1)
  * Erlang 22.2.3

## v1.10.0

This release updates Buildroot to 2019.11 with security and bug fix updates
across Linux packages. Enables dnsd, udhcpd and ifconfig in the default
Busybox configuration to support `vintage_net` and `vintage_net_wizard`.
See the `nerves_system_br` notes for details.

* Updated dependencies
  * [nerves_system_br v1.10.0](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.10.0)
  * Erlang 22.1.8

## v1.9.2

This release updates Buildroot to 2019.08.2 with security and bug fix updates
across Linux packages. See the `nerves_system_br` notes for details.
Erlang/OTP is now at 22.1.7.

* Updated dependencies
  * [nerves_system_br v1.9.5](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.9.5)

## v1.9.1

This release pulls in security and bug fix updates from `nerves_system_br`.
Erlang/OTP is now at 22.1.1.

* Updated dependencies
  * [nerves_system_br v1.9.4](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.9.4)
  * linux - update to the raspberrypi-kernel_1.20190925-1 tag

## v1.9.0

This release updates Buildroot to 2019.08 with security and bug fix updates
across Linux packages. See the `nerves_system_br` notes for details.

* Updated dependencies
  * [nerves_system_br v1.9.2](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.9.2)

## v1.8.2

This release fixes an issue that broke display output on small LCD screens.
Updating the Raspberry Pi firmware to the latest from the Raspberry Pi
Foundation fixed the issue. See
https://github.com/fhunleth/rpi_fb_capture/issues/2 for details.

* Updated dependencies
  * [nerves_system_br v1.8.5](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.8.5)

## v1.8.1

* Updated dependencies
  * [nerves_system_br v1.8.4](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.8.4)
  * Linux 4.19.58 with patches from the Raspberry Pi Foundation

## v1.8.0

This release

This release updates Erlang to OTP 22 and gcc from version 7.3.0 to 8.3.0.
See the nerves_system_br and toolchain release notes for more information.

* Enhancements
  * Enable source-based routing in the Linux kernel to support [vintage_net](https://github.com/nerves-networking/vintage_net)

* Updated dependencies
  * Erlang 22.0.4
  * [nerves_system_br v1.8.2](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.8.2)
  * [nerves_toolchain_arm_unknown_linux_gnueabihf v1.2.0](https://github.com/nerves-project/toolchains/releases/tag/v1.2.0)

## v1.7.2

* Bux fixes
  * Add TAR option `--no-same-owner` to fix errors when untarring artifacts as
    the root user.
* Updated dependencies
  * [nerves_system_br v1.7.2](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.7.2)

## v1.7.1

This release fixes a major issue with the gadget USB port where it would hang on
boot. If you have made a custom system or are overriding the `erlinit.config`
file in your project, please make sure that your `erlinit.config` has:

```text
-c null
-s "/usr/bin/nbtty --tty /dev/ttyGS0 --wait-input"
```

* Bug fixes
  * Fix regression with virtual serial port where it could cause the whole USB
    interface to hang.

* Improvements
  * Bump C compiler options to `-O2` from `-Os`. This provides a small, but
    measurable performance improvement (500ms at boot in a trivial project).

* Updated dependencies
  * [nerves_system_br v1.7.1](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.7.1)

## v1.7.0

This release bumps the Linux kernel to 4.19.25. This change had an impact on how
the WiFi regulatory database gets loaded into the kernel. Instead of building it
into the kernel as previously done, the kernel loads it on demand. This requires
that all WiFi drivers be built as kernel modules so that the database isn't
loaded before the root filesystem is mounted. If you made a custom system and
see boot errors about not being able to load the regulatory database, this is
the problem.

A known bug with the Raspberry Pi Zero USB gadget interface is that it sometimes
doesn't load on Linux systems. Moving the gadget drivers to kernel modules seems
to work around this but it takes longer to load the gadget interface.

* Updated dependencies
  * [nerves_system_br v1.7.0](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.7.0)
  * Linux 4.19.25 with patches from the Raspberry Pi Foundation

## v1.6.3

* Updated dependencies
  * [nerves_system_br v1.6.8](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.6.8)
  * Erlang 21.2.6

## v1.6.2

* Updated dependencies
  * [nerves_system_br v1.6.6](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.6.6)
  * Erlang 21.2.4
  * boardid 1.5.3

## v1.6.1

* Updated dependencies
  * [nerves_system_br v1.6.5](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.6.5)
  * Erlang 21.2.2
  * boardid 1.5.2
  * erlinit 1.4.9
  * OpenSSL 1.1.1a
  * Linux 4.14.89 with patches from the Raspberry Pi Foundation

* Enhancements
  * Moved boardid config from inside erlinit.config to /etc/boardid.config
  * Compile gpiomem into the Linux kernel
  * Enable pstore, an in-memory buffer that can capture logs, kernel
    oops and other information when unexpected reboots. The buffer can be
    recovered on the next boot where it can be inspected.

## v1.6.0

This pulls in a pending patch in Buildroot to update the version of
OpenSSL from 1.0.2 to 1.1.0h. This fixes what appears to be issues with
Erlang using OpenSSL engines. It also enables Erlang crypto algorithms
such as ed25519 that have been added in recent Erlang releases.

* Updated dependencies
  * [nerves_system_br v1.6.1](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.6.1)
  * Erlang 21.2
* Added dependencies
  * wpa_passphrase
  * libp11 0.4.9

## v1.5.1

* Updated dependencies
  * [nerves_system_br v1.5.3](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.5.3)

## v1.5.0

This release updates the Linux kernel from 4.4 to 4.14.71.

* Enhancements
  * Added Alsa utils `aplay` and `amixer` for audio support.
  * Added `espeak` a speech synthesizer for text to audio.
  * Automatically reboot if the Linux kernel panics (defaults to a 10 second
    delay before the reboot)

* Updated dependencies
  * [nerves_system_br v1.5.2](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.5.2)
  * Linux 4.14.71 with patches from the Raspberry Pi Foundation
  * Erlang 21.0.9

## v1.4.0

This release contains various updates to provisioning variables and data.

**Host requirements**

Building firmware using this system requires `fwup` to be updated on your
host computer to at least `v1.2.5`. The target minimum version requirement
has not changed from `0.15.0`.

**Serial numbers**

Device serial numbers are now set using `NERVES_SERIAL_NUMBER` instead of
`SERIAL_NUMBER`. This is to reduce ambiguity on the source of the serial
by name spacing it along side other Nerves variables. The U-Boot environment
key has also changed from `serial_number` to `nerves_serial_number`. The
erlinit.config has been updated to provide backwards compatibility for setting
the hostname from the serial number by checking for `nerves_serial_number`
and falling back to `serial_number`.

**Custom provisioning**

Provisioning data is applied at the time of calling the `fwup` task `complete`.
The `complete` task is executed when writing the firmware to the target disk.
During this time, `fwup` will include the contents of a provisioning file
located at `${NERVES_SYSTEM}/images/fwup_include/provisioning.conf`. By default,
this file only sets `nerves_serial_number`. You can add additional provisioning
data by overriding the location of this file to include your own by setting
the environment variable `NERVES_PROVISIONING`. If you override this variable
you will be responsible for also setting `nerves_serial_number`.

* Updated dependencies
  * [nerves_system_br v1.4.5](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.4.5)

## v1.3.0

This release upgrades gcc from version 6.3.0 to 7.3.0. See the toolchain release
notes for more information.

* Updated dependencies
  * [nerves_system_br v1.4.1](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.4.1)
  * [nerves_toolchain_armv6_rpi_linux_gnueabi v1.1.0](https://github.com/nerves-project/toolchains/releases/tag/v1.1.0)

## v1.2.1

* Updated dependencies
  * [nerves_system_br v1.3.2](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.3.2)

## v1.2.0

This release updates Erlang to OTP 21.0

* Updated dependencies
  * [nerves_system_br v1.3.0](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.3.0)

## v1.1.1

This release fixes some issues and adds firmware UUID support. This support can
be used to unambiguously know what's running on a device.

* Updated dependencies
  * [nerves_system_br v1.2.2](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.2.2)

* Bug fixes
  * Empty serial numbers stored in the U-Boot environment would be used instead
    of reverting to devices IDs built into the CPU or board.
  * It wasn't possible to enable QtWebEngine (needed for kiosk apps)

## v1.1.0

This release adds official support for provisioning serial numbers to devices.
Other information can be provisioned in a similar manner. See the README.md for
details.

Buildroot was also updated to 2018.05. Be sure to review the `nerves_system_br`
link for the changes in the embedded Linux components.

* Updated dependencies
  * [nerves_system_br v1.2.0](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.2.0)

* New features
  * More `wpa-supplicant` features were enabled to support more WiFi use-cases

## v1.0.0

This release is nearly identical to rc.1 except for pulling the official 1.0
versions of Nerves dependencies and minor documentation updates.

* Updated dependencies
  * [nerves_system_br v1.0.0](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.0.0)
  * [nerves_toolchain v1.0.0](https://github.com/nerves-project/toolchains/releases/tag/v1.0.0)
  * [nerves v1.0.0](https://github.com/nerves-project/nerves/releases/tag/1.0.0)

## v1.0.0-rc.1

This release contains updates to Erlang and heart from `nerves_system_br` and
mostly cosmetic changes to this project. The trivial `.fw` files are no longer
created by CI scripts. If you've forked this project and are building systems
using CI, make sure to update your publish scripts.

* Updated dependencies
  * [nerves_system_br v1.0.0-rc.2](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.0.0-rc.2)

## v1.0.0-rc.0

* Updated dependencies
  * [nerves_system_br v1.0.0-rc.0](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.0.0-rc.0)
  * [nerves_toolchain v1.0.0-rc.0](https://github.com/nerves-project/toolchains/releases/tag/v1.0.0-rc.0)
  * [nerves v1.0.0-rc.0](https://github.com/nerves-project/nerves/releases/tag/1.0.0-rc.0)

## v0.21.0

* Updated dependencies
  * [nerves_system_br v0.17.0](https://github.com/nerves-project/nerves_system_br/releases/tag/v0.17.0)
  * [nerves_toolchain v0.13.0](https://github.com/nerves-project/toolchains/releases/tag/v0.13.0)
  * [nerves v0.9.0](https://github.com/nerves-project/nerves/releases/tag/v0.9.0)

## v0.20.1

* Updated dependencies
  * [nerves_system_br v0.16.3](https://github.com/nerves-project/nerves_system_br/releases/tag/v0.16.3)
  This fixes the call to otp_build so that it always uses Buildroot's version
  the autoconf tools.

## v0.20.0

Important: This image removes kernel log messages from the HDMI and UART ports.
They are now only available via `dmesg`. If you're debugging a boot hang, you
can re-enable prints by updating the cmdline.txt. See README.md.

* Updated dependencies
  * [nerves_system_br v0.16.1-2017-11](https://github.com/nerves-project/nerves_system_br/releases/tag/v0.16.1-2017-11)

* Bug fixes
  * Removed kernel logging from UART and HDMI to avoid interfering with other
    uses. They are rarely used on those ports.

* Enhancements
  * Reboot automatically if Erlang VM exits - This is consistent with other
    Nerves systems. See rootfs_overlay/etc/erlinit.config if undesired.
  * Start running nerves_system_linter to check for configuration errors.
  * Disable console blanking for HDMI to make it easier to capture error messages.
  * Automount the boot partition readonly at `/boot`
  * Support for reverting firmware.

    See [Reverting Firmware](https://nerves-runtime.hexdocs.pm/readme.html#reverting-firmware) for more info on reverting firmware.

    See [fwup-revert.conf](https://github.com/nerves-project/nerves_system_rpi/blob/master/fwup-revert.conf) for more information on how fwup handles reverting.

## v0.19.2

* Bug fixes
  * Updated toolchains to 0.12.1 which fixes issues with missing app files.

## v0.19.1

* Bug fixes
  * Rollback release due to errors with toolchains not defining erlang app files

## v0.19.0

* Updated dependencies
  * [nerves_system_br v0.15.1](https://github.com/nerves-project/nerves_system_br/releases/tag/v0.15.1)
  * [nerves v0.8.3](https://github.com/nerves-project/nerves/releases/tag/v0.8.3)
  * [nerves_toolchain_armv6_rpi_linux_gnueabi v0.12.0](https://github.com/nerves-project/toolchains/releases/tag/v0.12.0)
* Enhancements
  * Support for nerves 0.8.x Moved nerves.exs to mix.exs

## v0.18.2

* Updated dependencies
  * [nerves_system_br v0.14.1](https://github.com/nerves-project/nerves_system_br/releases/tag/v0.14.1)

## v0.18.1

* Bug fixes
  * Build `nbtty`

## v0.18.0

* Updated dependencies
  * [nerves_system_br v0.14.0](https://github.com/nerves-project/nerves_system_br/releases/tag/v0.14.0)
  * [Buildroot 2017.08](https://git.busybox.net/buildroot/plain/CHANGES?id=2017.08)
  * [fwup 0.17.0](https://github.com/fhunleth/fwup/releases/tag/v0.17.0)
  * [erlinit 1.2.0](https://github.com/nerves-project/erlinit/releases/tag/v1.2.0)
  * [nbtty 0.3.0](https://github.com/fhunleth/nbtty/releases/tag/v0.3.0)

* Enhancements
  * Add global patch directory

  This is required to pull in the e2fsprogs patch that's needed now that
  util-linux's uuid_generate function calls getrandom and can block
  indefinitely for the urandom pool to initialize

* Bug fixes
  * Use `nbtty` by default to fix tty hang issue

## v0.17.1

* Updated dependencies
  * nerves_system_br v0.13.7

## v0.17.0

This release contains an updated toolchain with Linux 4.1 Headers.
You will have to clean and compile any c/c++ code in your project and
dependencies. Failure to do so will result in an error when producing firmware.

* nerves_system_br v0.13.5
  * fwup 0.15.4

* Nerves toolchain v0.11.0

* New Features
  * Fix warnings for Elixir 1.5
  * Remove unused options from OTP 20 update
  * Per Buildroot convention, the rootfs-additions directory is being renamed
    to rootfs_overlay. A symlink is put in its place to avoid breaking any
    systems.
  * Enabled IPv6 Support in Linux kernel

## v0.16.0

* nerves_system_br v0.13.2
  * OTP 20
  * erlinit 1.1.3
  * fwup 0.15.3

* New features
  * Firmware updates verify that they're updating the right target. If the target
    doesn't say that it's an `rpi0` through the firmware metadata, the update
    will fail.
  * Added meta-misc and meta-vcs-identifier to the `fwup.conf` metadata for use
    by users and for the regression test framework

* Bug fixes
  * The `erlinit` update fixes a hang issue that occurs on reboots if nothing
    is connected to the USB virtual serial console.

## v0.15.0

* nerves_system_br v0.12.1
  * erlinit 1.1.1
  * fwup 0.15.0

* New features
  * The application data partition is now `ext4`. This greatly improves its
    robustness to corruption. Nerves.Runtime contains code to initialize it on
    first boot.
  * Firmware images now contain metadata that can be queried at runtime (see
    Nerves.Runtime.KV
  * Increased GPU memory to support Pi Camera V2

## v0.14.0

* nerves_system_br v0.12.0
  * Buildroot 2017.05
  * erlinit 1.1.0

* New features
  * pigpio is now available by default (enables near real-time use of gpios)

* Bug fixes
  * USB host/gadget mode selection doesn't seem to work on some non-Apple
    hardware. Host support has been disabled as a workaround. See
    [Issue 10](https://github.com/nerves-project/nerves_system_rpi0/issues/10) for details.

* Other changes
  * pi3-miniuart-bt overlay is enabled by default to give full speed UART access on GPIO pins

## v0.13.1

* nerves_system_br v0.11.1
  * erlinit 1.0.1 - contains fix for Erlang VM exit detection issue

## v0.13.0

The brcmfmac wireless driver is now built as a module, so you will need to load it. See [hello_wifi](https://github.com/nerves-project/nerves-examples/tree/master/hello_wifi) for an example of WiFi module loading on application startup.

* nerves_system_br v0.11.0
  * erlinit 1.0
  * fwup 0.14.2
  * rpi-userland and rpi-firmware version bumps to correspond with Raspbian Linux 4.4 updates

## v0.12.0

This is the first official Raspberry Pi Zero system release. It was forked
off `nerves_system_rpi` so previous versions are from that project. Those
also work on the Zero, but without USB gadget mode or RPi Zero W WiFi
support.

* nerves_system_br v0.10.0
  * Buildroot 2017.02
  * Erlang/OTP 19.3

* New features
  * Upgraded the Linux kernel from 4.4.43 -> 4.4.50. Due to the coupling
    between the Linux kernel and rpi-firmware and possibly rpi-userland, if
    you have a custom system based off this, you should update your Linux
    kernel as well. (see `nerves_defconfig` changes)

## v0.11.0

* New features
  * Enabled USB_SERIAL and FTDI_SIO support. Needed for connecting with Arduino to the USB ports
  * Support for Nerves 0.5.0

## v0.10.0

* New features
  * Upgraded the Linux kernel to 4.4.43. This also removes the
    call to mkknlimg which is no longer needed.
  * Bump toolchain to use gcc 5.3 (previously using gcc 4.9.3)

## v0.9.1

* Bug Fixes
  * Loosen mistaken nerves dep on `0.4.0` to `~> 0.4.0`

## v0.9.0

This version switches to using the `nerves_package` compiler. This will
consolidate overall deps and compilers.

* Nerves.System.BR v0.8.1
  * Support for distillery
  * Support for nerves_package compiler

## v0.7.0

When upgrading to this version, be sure to review the updates to
nerves_defconfig if you have customized this system.

* nerves_system_br v0.7.0
  * Package updates
    * Buildroot 2016.08
    * Linux 4.4

## v0.6.1

* Package versions
  * Nerves.System.BR v0.6.1

* New features
  * All Raspberry Pi-specific configuration is now in this repository
  * Enabled SMP Erlang - even though the RPi Zero and Model B+ are
    single core systems, some NIFs require SMP Erlang.

## v0.6.0

* Nerves.System.BR v0.6.0
  * Package updates
    * Erlang OTP 19
    * Elixir 1.3.1
    * fwup 0.8.0
    * erlinit 0.7.3
    * bborg-overlays (pull in I2C typo fix from upstream)
  * Bug fixes
    * Synchronize file system kernel configs across all platforms

## v0.5.2

* Enhancements
  * Enabled USB Printer kernel mod. Needs to be loaded with `modprobe` to use
* Bug Fixes(raspberry pi)
  * Enabled multicast in linux config for rpi/rpi2/rpi3/ev3

## v0.5.1

* Nerves.System.BR v0.5.1
  * Bug Fixes(nerves-env)
    * Added include paths to CFLAGS and CXXFLAGS
    * Pass sysroot to LDFLAGS

## v0.5.0

* Nerves.System.BR v0.5.0
  * New features
    * WiFi drivers enabled by default on RPi2 and RPi3
    * Include wireless regulatory database in Linux kernel by default
      on WiFi-enabled platforms. Since kernel/rootfs are read-only and
      coupled together for firmware updates, the normal CRDA/udev approach
      isn't necessary.
    * Upgraded the default BeagleBone Black kernel from 3.8 to 4.4.9. The
      standard BBB device tree overlays are included by default even though the
      upstream kernel patches no longer include them.
    * Change all fwup configurations from two step upgrades to one step
      upgrades. If you used the base fwup.conf files to upgrade, you no
      longer need to finalize the upgrade. If not, there's no change.
