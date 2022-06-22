# Targets

Nerves supports a variety of hardware. These are called targets and are
identified by short tag names. Examples of tag names are `rpi0`, `bbb`, etc.

When building a Nerves project, set the `MIX_TARGET` environment variable to the
tag name. This controls which dependencies and configuration settings are used
when building your project. See the [Mix
Targets](https://hexdocs.pm/mix/Mix.html#module-targets) documentation for
further information on this concept.

In Nerves, the term _system_ refers to the library (usually posted to hex.pm) that
provides the bootloader, Linux kernel, C libraries, and more for a device.
Systems have names like `nerves_system_rpi0`. Since it's possible to create
firmware for more than one hardware device, Nerves uses the Mix target feature
to select the desired system in your project's `mix.exs`.

The naming of target tags is arbitrary. You can choose tags however makes the
most sense for your project. Nerves uses the convention of naming the target tag
after the system that it uses. For example, when using the Nerves new project
generator, it will set up the `mix.exs` to use the tag `rpi0` to select the
`nerves_system_rpi0` library for building for a Raspberry Pi Zero.

## Supported Targets and Systems

The following table summarize officially supported hardware, the associated
system and the `$MIX_TARGET` tag to use.

Target | System | Tag
------ | ------ | ---
Raspberry Pi A+, B, B+ | [nerves_system_rpi](https://github.com/nerves-project/nerves_system_rpi) | `rpi`
Raspberry Pi Zero and Zero W | [nerves_system_rpi0](https://github.com/nerves-project/nerves_system_rpi0) | `rpi0`
Raspberry Pi 2 | [nerves_system_rpi2](https://github.com/nerves-project/nerves_system_rpi2) | `rpi2`
Raspberry Pi 3A and Zero 2 W | [nerves_system_rpi3a](https://github.com/nerves-project/nerves_system_rpi3a) | `rpi3a`
Raspberry Pi 3 B, B+ | [nerves_system_rpi3](https://github.com/nerves-project/nerves_system_rpi3) | `rpi3`
Raspberry Pi 4 | [nerves_system_rpi4](https://github.com/nerves-project/nerves_system_rpi4) | `rpi4`
BeagleBone Black, BeagleBone Green, BeagleBone Green Wireless, and PocketBeagle. | [nerves_system_bbb](https://github.com/nerves-project/nerves_system_bbb) | `bbb`
Generic x86_64 | [nerves_system_x86_64](https://github.com/nerves-project/nerves_system_x86_64) | `x86_64`
OSD32MP1 | [nerves_system_osd32mp1](https://github.com/nerves-project/nerves_system_osd32mp1) | `osd32mp1`
GRiSP 2 | [nerves_system_grisp2](https://github.com/nerves-project/nerves_system_grisp2) | `grisp2`

While the Nerves core team only officially supports the above hardware, the
community has added support for other boards. See [Nerves Systems on
hex.pm](https://hex.pm/packages?search=depends:nerves_system_br)

## Supporting New Target Hardware

If you're trying to support a new Target, there may be quite a bit more work
involved, depending on how mature the support for that hardware is in the
Buildroot community.  If you're not familiar with
[Buildroot](https://buildroot.org/), you should learn about that first, using
the excellent training materials on their website.

If you can find an existing Buildroot configuration for your intended hardware
and you want to get it working with Nerves, you will need to make a custom
System as follows:

1. Follow their procedure and confirm your target boots (independent of Nerves).

2. Figure out how to get everything working with the version of Buildroot Nerves uses.
    See the [`NERVES_BR_VERSION` variable in `create-build.sh`](https://github.com/nerves-project/nerves_system_br/blob/main/create-build.sh).

  * Look for packages and board configs can need to be copied into your System.
  * Look for patches to existing packages that are needed.

3. Create a defconfig that mimics the one from step 1, and get `nerves_system_br` to build it.
   See the section in the [System](systems.html) documentation about customizing Nerves Systems.

> NOTE: You probably want to disable any userland packages that may be included
> by default to avoid distraction.

<p align="center">
Is something wrong?
<a href="https://github.com/nerves-project/nerves/edit/main/docs/Targets.md">
Edit this page on GitHub
</a>
</p>
