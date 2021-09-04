# Using the CLI

Nerves greets you with Elixir's IEx prompt. This prompt is your main entry point
to interacting with Elixir, your program and hardware. This chapter focuses on
Nerves-specific use of the IEx prompt.

## Viewing log messages

### Attaching to the logger

The [`Elixir console
logger`](https://hexdocs.pm/logger/master/Logger.Backends.Console.html) is
normally disabled so log messages don't print to the terminal. Instead, run
`log_attach` to see log messages:

```elixir
iex> log_attach
{:ok, #PID<0.30684.4>}
iex> Logger.info("hello")

02:23:34.863 [info]  hello
:ok
```

To stop log messages from being printed, run `log_detach`.

### RingLogger

You'll frequently want to see log messages that occurred in the past. The Nerves
new project generator creates projects with
[`RingLogger`](https://hex.pm/packages/ring_logger) to support this.
`RingLogger` is an [Elixir logger
backend](https://hexdocs.pm/logger/master/Logger.html#module-backends) that
stores logs completely in memory. This is nice for embedded systems where you
don't want to wear out Flash storage by writing to it. The drawbacks are
RingLogger discards old messages and doesn't save them across reboots.

To view log messages, run `RingLogger.next` at the IEx prompt. Repeated calls
print newly received log messages. `RingLogger.reset` lets you start at the
oldest message again.

See the `RingLogger` docs for more information on tuning log levels, filtering
by module, and grep'ing for keywords.

### Dmesg

Nerves routes Linux kernel log messages and
[syslog](https://linux.die.net/man/8/syslogd) messages to the Elixir Logger.
This means Elixir logger backends have a complete picture of the log messages
sent by the kernel, C, and BEAM  programs. Sometimes, though, it's useful to
focus on the kernel messages in isolation. The `dmesg` helper lets you do this:

```elixir
iex> dmesg
[    0.000000] Booting Linux on physical CPU 0x0
[    0.000000] Linux version 5.10.41 (buildroot@buildroot) (armv7-nerves-linux-gnueabihf-gcc (crosstool-NG 1.24.0.299_6729a76) 10.2.0, GNU ld (crosstool-NG 1.24.0.299_6729a76) 2.36.1) #1 PREEMPT Fri Aug 20 01:26:27 UTC 2021
[    0.000000] CPU: ARMv7 Processor [413fc082] revision 2 (ARMv7), cr=10c5387d
[    0.000000] CPU: PIPT / VIPT nonaliasing data cache, VIPT aliasing instruction cache
```

### RamoopsLogger

The [`RamoopsLogger`](https://hex.pm/packages/ramoops_logger) is an Elixir
logger backend that records messages to a special memory region using Linux's
`pstore` driver. This memory region survives reboots so it's useful for
capturing log messages that happen just before an unexpected reboot. Even if you've configured a file-backed logger backend, the `RamoopsLogger` can sometimes capture messages that would have been lost to disk caching.

This driver is enabled in most official Nerves systems. However,
`:ramoops_logger` is not added to Nerves projects by default. See the
[documentation](https://hexdocs.pm/ramoops_logger) for registering it with the
Elixir Logger.

## Other loggers

Pretty much any logger backend in Elixir can be used with Nerves. The caveat is
that Nerves does not guarantee the following:

1. Networking always works
2. The application data partition (`/data`) is mounted

If you're using a network-based logger, check that it handles network outages
gracefully.

The application data partition is almost always available. However, on the
first boot and if severely corrupted, it will be reformatted. Since the Elixir
Logger starts very early in the boot process, it's possible for log messages to
be received before `/data` is ready. This is a temporary situation, but it is
important that the Logger backend not give up.

## Networking

Most Nerves projects use the [`VintageNet`](https://hex.pm/packages/vintage_net)
library for configuring the network. To get a quick overview of network
configuration and status, run:

```elixir
iex> VintageNet.info
All interfaces:       ["eth0", "lo", "wlan0", "wwan0"]
Available interfaces: ["wlan0", "wwan0"]

Interface eth0
  Type: VintageNetEthernet
  Present: true
  State: :configured (1 days, 14:59:09)
  Connection: :disconnected (1 days, 14:59:09)
  Configuration:
    %{type: VintageNetEthernet, ipv4: %{method: :dhcp}}

Interface wlan0
  Type: VintageNetWiFi
  Present: true
  State: :configured (1 days, 14:59:05)
  Connection: :internet (5:02:35)
  Addresses: 192.168.99.81/24, fe80::9a48:27ff:fedd:a10e/64
  Configuration:
    %{
      type: VintageNetWiFi,
      ipv4: %{method: :dhcp},
      vintage_net_wifi: ...
    }

Interface wwan0
  Type: VintageNetQMI
  Power: On (watchdog timeout in 59969 ms)
  Present: true
  State: :configured (14:44:50)
  Connection: :internet (14:43:51)
  Addresses: 100.101.32.76/29, fe80::8eb:885f:3fce:d37d/64
  Configuration:
    %{ ...
    }
```

If your muscle memory types `ifconfig`, that works too:

```elixir
iex(2)> ifconfig
lo: flags=[:up, :loopback, :running]
    inet 127.0.0.1  netmask 255.0.0.0
    inet ::1  netmask ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff
    hwaddr 00:00:00:00:00:00

eth0: flags=[:up, :broadcast, :running, :multicast]
    hwaddr 60:64:05:4e:fb:ef

wlan0: flags=[:up, :broadcast, :running, :multicast]
    inet 192.168.99.81  netmask 255.255.255.0  broadcast 192.168.99.255
    inet fe80::9a48:27ff:fedd:a10e  netmask ffff:ffff:ffff:ffff::
    hwaddr 98:48:27:dd:a1:0e

wwan0: flags=[:up, :pointtopoint, :running, :multicast]
    inet 100.101.32.76  netmask 255.255.255.248
    inet fe80::8eb:885f:3fce:d37d  netmask ffff:ffff:ffff:ffff::
```

Another option is to run [`ip(8)`](https://linux.die.net/man/8/ip).
Nerves provides a trimmed down Busybox version of `ip`. For example:

```elixir
iex> cmd("ip route")
default via 192.168.99.1 dev wlan0  metric 20
default via 100.101.32.77 dev wwan0  metric 30
100.101.32.72/29 dev wwan0 scope link  src 100.101.32.76  metric 30
192.168.99.0/24 dev wlan0 scope link  src 192.168.99.81  metric 20
```

See the [`VintageNet` documentation](https://hexdocs.pm/vintage_net/readme.html)
for more tips on debugging and adjusting network configurations.

## Toolshed

[`Toolshed`](https://hex.pm/packages/toolshed) is a library of [IEx
helpers](https://hexdocs.pm/iex/IEx.Helpers.html) that augments the ones that
Elixir provides. It's included by the Nerves new project generator.

The helpers should be available by default, but if not, run:

```elixir
iex> use Toolshed
Toolshed imported. Run h(Toolshed) for more info.
:ok
```

If you're used to the Linux commandline, many Toolshed helpers will seem
familiar except with an Elixir twist. One difference is that you need to add
double quotes around filenames and IP addresses. The names are similar, though,
like `uname`, `ping`, `uptime`, `date`, `lsof` and more.

Toolshed also simplifies running shell commands. Keeping in mind that Nerves
provides a limited Linux userland, you can still run simple shell scripts and
commandline applications using `cmd`. For example,

```elixir
iex> cmd("ls -las /")
     0 drwxr-xr-x    3 root     root            97 Mar 12  2020 var
     0 drwxr-xr-x    7 root     root            88 Mar 12  2020 usr
     0 drwxrwxrwt    3 root     root           180 Sep  2 21:05 tmp
     0 dr-xr-xr-x   12 root     root             0 Jan  1  1970 sys
...
```

Another useful command for checking Internet-connectivity is `weather`. This
sends an HTTP request to Igor Chubin's super useful [wttr.in
service](https://github.com/chubin/wttr.in).

## Linux shell commands

*Note:* Erlang contains an amazing amount of functionality, so before reaching
for Linux utilities, we highly recommend checking the [Erlang
documentation](https://erlang.org/doc/search/).

Nerves includes a minimal version of [`busybox`](https://www.busybox.net/) to
support running simple shell scripts and access network configuration utilities
that do not have analogs in Erlang/OTP.

To see what's available, run `busybox` without arguments:

```elixir
iex> cmd("busybox")
BusyBox v1.33.1 () multi-call binary.
BusyBox is copyrighted by many authors between 1998-2015.
Licensed under GPLv2. See source distribution for detailed
copyright notices.

Usage: busybox [function [arguments]...]
   or: busybox --list
   or: busybox --show SCRIPT
   or: function [arguments]...

	BusyBox is a multi-call binary that combines many common Unix
	utilities into a single executable.  Most people will create a
	link to busybox for each function they wish to use and BusyBox
	will act like whatever it was invoked as.

Currently defined functions:
	[, [[, ash, base32, basename, brctl, cat, cp, cut, date, dd, devmem,
	df, dirname, dmesg, dnsd, expr, find, free, grep, halt, id, ifconfig,
	install, ip, ipaddr, iplink, ipneigh, iproute, iprule, iptunnel, kill,
	killall, ls, lsmod, mim, mkdir, mknod, mktemp, modinfo, modprobe,
	mount, mv, ntpd, pidof, ping, ping6, poweroff, ps, pwd, reboot, rm,
	rmdir, rmmod, sed, sh, sha256sum, sleep, sysctl, tail, touch, udhcpc,
	udhcpd, uevent, umount, unzip
```

## Customizing the IEx session

The Nerves new project generator creates a default `iex.exs` for setting up the
prompt. You can find it in `rootfs_overlay/etc/iex.exs`.

The default `iex.exs` shows some text and loads the `Toolshed` helpers. See the
[IEx .iex.exs docs](https://hexdocs.pm/iex/IEx.html#module-the-iex-exs-file) for
more information on what can be done.

Keep the following in mind:

1. Elixir evaluates the `iex.exs` file for the console very early in the boot
   process. It's likely that networking and your OTP applications have not
   started, so you may get runtime exceptions
2. A common sign that a typo broke the `iex.exs` is that the Toolshed helpers
   are not available. You can still run `use Toolshed` at the prompt.
3. The `iex.exs` is stored in a read-only location so you can't update it on the
   device. You can create `/root/.iex.exs` and customize it. Use `sftp` to
   update or erase it if you mess it up.

## Changing and disabling the console

Depending on the platform, Nerves sends the startup console to an attached
display or UART. If you find yourself taking pictures of the display to capture
error log messages, you probably want to start using the UART. That requires a
USB-to-UART cable (often called an FTDI cable) and you'll need a serial
communications program on your computer. When you ship a Nerves device, you may
want to disable the console completely.

[`erlinit`](https://github.com/nerves-project/erlinit) sets up the console
before starting Erlang. The `/etc/erlinit.config` files in the official Nerves
systems have comments about where the console output goes. Here's an example:

```text
 Specify where erlinit should send the IEx prompt. Only one may be enabled at
# a time.
-c ttyAMA0     # UART pins on the GPIO connector
# -c tty1      # HDMI output
```

The easiest way of changing the console location is in your `config.exs`. For example,
specify the following to use `tty1`:

```elixir
config :nerves, :erlinit,
  ctty: "tty1"
```

To disable the console completely, set the `ctty` to `null`:

```elixir
config :nerves, :erlinit,
  ctty: "null",
  alternate_exec: "/usr/bin/run_erl /tmp/ /tmp exec"
```

The `:alternate_exec` key is optional here. It calls
[`run_erl`](https://erlang.org/doc/man/run_erl.html) to log console output to a
file in `/tmp`. This is useful if code calls `IO.puts` rather than `Logger`.

## Remote console access

Accessing the IEx prompt remotely requires additional configuration if `ssh` is
not available. The option that currently requires the least amount of code is to
use [NervesHub](https://github.com/nerves-hub/). The way this works is that the
device connects to a NervesHub server and then you can log into the server, pick
a device and open a command prompt. If NervesHub is not an option, the
[`extty`](https://hex.pm/packages/extty) library may be useful for connecting an
IEx prompt to the transport of your choice.

## Erlang and LFE prompts

While Nerves definitely has a lot of Elixir in it now, it has always been the
intention to support other BEAM languages.

The boot console is configured using your project's `vm.args`. The console
supplied over SSH connections is set though the application environment for
`:nerves_ssh`:

```elixir
config :nerves_ssh,
  shell: :lfe
```

See the [Nerves Examples](https://github.com/nerves-project/nerves-examples) for
small Erlang and LFE programs.

## CLI FAQ

### How do I exit an ssh session

If you're using `Toolshed`, type `exit` at the IEx prompt. Otherwise, use
`ssh`'s magic exit sequence: `<enter>~.`.

### Why does history not work on the first boot?

Commandline history is stored on the application data partition. On the first
boot, the application data partition is unformatted and needs to be initialized.
Unfortunately, the commandline history code is one of the few pieces of code
that gets started before this happens.

### Where's Bash?

Everyone asks this and it's come up since almost day one. It is probably the
most visible distinction of what it means that Nerves uses the Linux kernel but
very little of the standard Linux userland.

Since Nerves provides only a few Linux utilities, the shell prompt is not as
useful as you would expect. The projects that once provided a shell prompt have
been abandoned due to this.

Our recommendation is to spend some time working at the `iex>` prompt and if
you're missing a utility, check if Elixir or Erlang/OTP provide it. If they do
and it just needs an IEx helper to make it ergonomic, then please consider
contributing a new helper to `Toolshed`.

If having a proper Unix shell and Linux userland is critical to your
application, it may be better to not use Nerves.
[Buildroot](https://buildroot.org/), [Yocto](https://www.yoctoproject.org/),
[Raspberry Pi OS](https://www.raspberrypi.org/), and other embedded Linux
projects run Erlang and Elixir too. Many Nerves-related libraries work well
outside of Nerves.
