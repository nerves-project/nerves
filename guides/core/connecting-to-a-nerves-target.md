<!--
  SPDX-FileCopyrightText: 2022 Masatoshi Nishiguchi
  SPDX-FileCopyrightText: 2023 Josh Kalderimis
  SPDX-FileCopyrightText: 2025 Marc Lainez
  SPDX-License-Identifier: CC-BY-4.0
-->
# Connecting to a Nerves Target

There are multiple ways to connect to your Nerves target device and different
target may support different connection methods.

The default features are different depending on Nerves targets. For example,
some Nerves targets support a UART serial console by default; others,
HDMI and USB keyboard instead.

> #### What features does Nerves support for my device? {: .tip}
>
> Refer to the documentation of `nerves_system_<target>` projects for their
> supported features. As an example, when your target is `rpi0_2`,
> visit https://hexdocs.pm/nerves_system_rpi0_2.

## USB to TTL serial cable (UART)

A target device can be accessed via a serial connection with a USB to TTL serial
cable, which is connected between the host USB port and a couple of header pins
on the target.

This connection method allows you to interact with the console of the target
device using a terminal emulator program on your development host. It is useful
for debugging networking or the boot process and for advanced development
workflows.

First of all, locate the documentation of the Nerve system that corresponds to
your target device, and find out how your Nerves system supports the IEx
terminal feature.

As an example, as of this writing, the documentation of
[nerves_system_rpi0] (a Nerves system for [Raspberry Pi Zero]) says the system
supports one UART port named `ttyAMA0` available for IEx terminal.
It is `/dev/ttyAMA0` in the file system.

![](https://user-images.githubusercontent.com/7563926/181918220-00733048-8706-4b40-957d-b621d308fc2f.png)

It is configured [here](https://github.com/nerves-project/nerves_system_rpi0/blob/ddb128989cf9bb28dd78f4467992d00b89828f02/rootfs_overlay/etc/erlinit.config#L12)
in the `nerves_system_rpi0` source code.

On the Raspberry Pi Zero, the UART that is known as `UART0` in the hardware
descriptions is routed to pins 8 and 10.

On Linux on the Raspberry Pi Zero, `UART0` is exposed as the device file
 `/dev/ttyAMA0`.

> #### Enabling USB serial console {: .info}
>
> Depending on your target's default settings, you may need to modify your
> Nerves configuration as described in the
> [Using a USB Serial Console](faq.html#using-a-usb-serial-console)
> FAQ topic.

[raspberry pi zero]: https://www.raspberrypi.com/products/raspberry-pi-zero-w
[raspberry pi zero w]: https://www.raspberrypi.com/products/raspberry-pi-zero-w
[nerves_system_rpi0]: https://hexdocs.pm/nerves_system_rpi0

### Get a USB-to-TTL serial cable

We've had good luck with [this cable](https://www.adafruit.com/product/954) if
you haven't already found one.

You may need to install to your host machine the driver software for the cable.
If you use the above-mentioned cable, Adafruits provides [this guide][usb-to-ttl serial cable - software installation].

[usb-to-ttl serial cable - software installation]: https://learn.adafruit.com/adafruits-raspberry-pi-lesson-5-using-a-console-cable/software-installation-mac

### Connect the leads

| Raspberry Pi             | USB-to-TTL Serial Cable |
| ------------------------ | ----------------------- |
| `TX0` (pin 8 / GPIO 14)  | `RX`                    |
| `RX0` (pin 10 / GPIO 15) | `TX`                    |
| `GND`                    | `GND`                   |

![](https://user-images.githubusercontent.com/7563926/181919087-03649fb1-b7c5-4601-bbb4-994fb07ea39e.png)

Image credit: https://pinout.xyz

> #### Tips {: .tip}
>
> Most likely you don't need the power line since your purpose here is the
> serial data communication.
>
> `TX` (transmit) and `RX` (receive) are relative terms. What is `TX` for one
> is `RX` for the other.

For visual learners, [Adafruit's Raspberry Pi Lesson](https://learn.adafruit.com/adafruits-raspberry-pi-lesson-5-using-a-console-cable/connect-the-lead)
has some helpful images.

### Run a terminal emulation program

The USB-to-TTL serial cable converts the text into a standard serial USB port.
There are multiple open source terminal emulator programs out there that
support the serial console.

- [picocom](https://github.com/npat-efault/picocom)
- [bootterm](https://github.com/wtarreau/bootterm)
- [screen](https://en.wikipedia.org/wiki/GNU_Screen)
- [tio](https://github.com/tio/tio)

As an example,  on a macOS host machine, you can open a terminal and try these
commands.

#### List TTY devices available

```bash
ls /dev/tty*
```

#### Start communication with the Raspberry Pi using `picocom`

```bash
picocom -b 115200 /dev/ttyUSB0
```

Replace `ttyUSB0` with the TTY device that has the USB-to-TTL serial cable. They
usually have the letters "USB" somewhere in the name.

You should be at an `iex(1)>` prompt. If not, try pressing `Enter` a few times.

### Troubleshooting

#### First boot shows error messages

First boot shows error messages due to the file system not being formatted.
Seems like something is wrong even though it isn't. This is visible if you
attach to the UART and watch the messages the very first time that you boot off
a MicroSD card.

#### Toolshed's `exit` not working in the serial console

It works, but Erlang doesn't automatically restart the shell. You should be
able to type CTRL-G to get the Erlang job menu.

#### **"could not find a PTY" Error when running `screen` command**

Unplug the USB connector and re-plug it.

## HDMI cable

On some Raspberry Pi family of targets such as `rpi3` and `rpi4`, the `IEx`
console is displayed on the screen attached to the HDMI port by default. You
can simply connect your target device to a monitor or TV.

For troubleshooting start-up issues and for more advanced development
workflows, it's desirable to connect from your development host to the
target using a UART serial cable.

Here is how to override the default, for `rpi3` as an example:

1. Look in the README of your target's system's documentation for a UART port name. For example, [`nerves_system_rpi3`](https://hexdocs.pm/nerves_system_rpi3/readme.html)
1. Locate your project's `erlinit` configuration which is normally in your project's `config/target.exs` file
1. Add a `ctty` option with the UART port name as a value

```diff
 config :nerves,
   erlinit: [
+    ctty: "ttyAMA0",
     hostname_pattern: "nerves-%s"
   ]
```

## USB data cable

Some Nerves targets can operate in Linux USB gadget mode, which means a network
connection can be made with a USB cable between your host and target. The USB
cable provides both power and network connectivity. This can be a convenient way
to work with your target device.

> #### Use correct USB port {: .warning}
>
> Make sure to plug the USB cable into the USB OTG port. For example, the
> Raspberry Pi Zero has two USB ports. The OTG one is the "middle" one. The
> other one is power-only.

> #### Use correct USB cable {: .warning}
>
> Make sure your USB cable supports data transfer. Generally there are two types
> of USB cables:
> - charging only
> - charging and data transfer

### Test the connection

Once the target is powered up, test the connection from your host:

```bash
ping nerves.local
```

### Make the network connection

To make a connection via the Linux USB gadget mode virtual Ethernet interface:

```bash
ssh nerves.local
```

You should find yourself at the `iex(hello_nerves@nerves.local)1>` prompt.

To end your ssh connection type `exit`, or you can use the `ssh` command
`<enter>~.`

> #### _nerves.local_ is an mDNS address {: .info}
>
> Most examples in this page are done with a macOS host, which has mDNS enabled
> by default. Linux and Windows hosts may have to enable mDNS networking.

### Gadget-mode virtual serial connection

USB gadget mode also supplies a virtual serial connection. Use it with any
terminal emulator like `screen` or `picocom`:

```bash
picocom -b 115200 /dev/ttyUSB0
```

> #### Windows _Device Manager / Network adapters_ has no _USB Ethernet/RNDIS Gadget_ device? {: .info}
>
> It might be caused by
> [this](https://www.ghacks.net/2020/09/28/should-you-install-windows-10s-optional-driver-updates),
> so install the optional `USB Ethernet/RNDIS Gadget` driver to fix it.

## Wireless and wired Ethernet connections

The `config/config.exs` generated in a new Nerves project will set up
connections for USB and Ethernet by default.

The [`nerves_pack`] dependency simplifies the network setup and configuration
process. At runtime, `nerves_pack` will detect all available interfaces that
have not been configured and apply defaults for `usb*` and `eth*` interfaces.

- For `eth*` interfaces, the device attempts to connect to the network
with DHCP using `ipv4` addressing.
- For `usb*` interfaces, it uses [`vintage_net_direct`] to run a simple DHCP
server on the device and assign the host an IP address over a USB cable.

If you want to use some other network configuration, such as wired or wireless
Ethernet, refer to the [`nerves_pack`] documentation and the underlying
[`vintage_net`] documentation as needed.

[`nerves_pack`]: https://hexdocs.pm/nerves_pack
[`vintage_net_wifi`]: https://hexdocs.pm/vintage_net_wifi
[`vintage_net_direct`]: https://hexdocs.pm/vintage_net_direct
[`nerves_pack`]: https://hexdocs.pm/nerves_pack
[`vintage_net`]: https://hexdocs.pm/vintage_net
