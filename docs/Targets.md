# Targets

Nerves provides support for a set of common Targets.
Each Target is referenced with a unique tag name.
These tags are used when choosing which System and Toolchain to compile with.
It is important to note that a single tag may offer support for more than one board.

## Supported Targets and Systems

Target | System | Tag
--- | --- | ---
Raspberry Pi A+, B, B+ | [nerves_system_rpi](https://github.com/nerves-project/nerves_system_rpi) | `rpi`
Raspberry Pi Zero and Zero W | [nerves_system_rpi0](https://github.com/nerves-project/nerves_system_rpi0) | `rpi0`
Raspberry Pi 2 | [nerves_system_rpi2](https://github.com/nerves-project/nerves_system_rpi2) | `rpi2`
Raspberry Pi 3 B, B+ | [nerves_system_rpi3](https://github.com/nerves-project/nerves_system_rpi3) | `rpi3`
Raspberry Pi 4 | [nerves_system_rpi4](https://github.com/nerves-project/nerves_system_rpi4) | `rpi4`
BeagleBone Black, BeagleBone Green, BeagleBone Green Wireless, and PocketBeagle. | [nerves_system_bbb](https://github.com/nerves-project/nerves_system_bbb) | `bbb`
Generic x86_64 | [nerves_system_x86_64](https://github.com/nerves-project/nerves_system_x86_64) | `x86_64`

While we only officially support commonly available hardware, the community has
added support for other boards. See
[Nerves Systems on hex.pm](https://hex.pm/packages?search=depends:nerves_system_br)

## Supporting New Target Hardware

If you're trying to support a new Target, there may be quite a bit more work involved, depending on how mature the support for that hardware is in the Buildroot community.
If you're not familiar with [Buildroot](https://buildroot.org/), you should learn about that first, using the excellent training materials on their website.

If you can find an existing Buildroot configuration for your intended hardware and you want to get it working with Nerves, you will need to make a custom System as follows:

1. Follow their procedure and confirm your target boots (independent of Nerves).

2. Figure out how to get everything working with the version of Buildroot Nerves uses.
    See the [`NERVES_BR_VERSION` variable in `create-build.sh`](https://github.com/nerves-project/nerves_system_br/blob/main/create-build.sh).

  * Look for packages and board configs can need to be copied into your System.
  * Look for patches to existing packages that are needed.

3. Create a defconfig that mimics the one from step 1, and get `nerves_system_br` to build it.
   See the section in the [System](systems.html) documentation about customizing Nerves Systems.

> NOTE: You probably want to disable any userland packages that may be included by default to avoid distraction.
