# Installation

Nerves requires a number of programs on your system to work. These include
Erlang, Elixir, and a few tools for packaging firmware images. Nerves is
actively used on MacOS and various Linux distributions. For Windows users, some
people have had success running Linux in a virtual machine or using the Windows
Subsystem for Linux available in Windows 10. If you have issues with any of the
tooling after following the steps below, we recommend you reach out to us in
[the #nerves channel on the Elixir
Slack](https://elixir-slackin.herokuapp.com/).

Nerves requires that the Erlang version running on your development host be
compatible with the Erlang version on the embedded target and also depends on
features added in recent versions of Elixir (`>= 1.7.0`). Because it can be hard
to manage these tool versions with sufficient granularity using operating system
packages, it is recommended that you use [ASDF](https://github.com/asdf-vm/asdf)
to manage Erlang and Elixir installations. This tool works the same on its
supported platforms, so you'll find more details in the All Platforms section
below.

## MacOS

The easiest installation route on MacOS is to use [Homebrew](brew.sh).
Just run the following:

```bash
brew update
brew install fwup squashfs coreutils xz pkg-config
```

Optionally, if you want to build custom Nerves Systems, you'll also need to
install [Docker for Mac](https://www.docker.com/docker-mac). After installing
Docker for Mac, you will likely want to adjust the resource limits imposed on
Docker, to allow it to successfully compile more complicated custom systems.
Click the Docker icon in the top menu bar, then click Preferences > Advanced and
allow Docker to use all of your CPUs and as much RAM as you think is reasonable
for your machine (at least 6 GB). The more resources it has access to, the
faster you can compile a custom Nerves system.

Now skip to the instructions for all platforms below.

## Windows

Use Windows 10 version 2004 (or later) with WSL2.  Follow all Linux/Ubuntu
instructions (assuming you're using an Ubuntu WSL2 distribution) to build and
compile the code. Run the following commands in your WSL2 prompt (this assumes
you're building for a Raspberry Pi 3).

```bash
export MIX_TARGET=rpi3
mix deps.get
mix firmware
```

If you can get all of those to run properly take the generated firmware file and
from a _Windows_ *admin* prompt (e.g. PowerShell) you'll burn that firmware
image to your SD card. First you'll need to install fwup
([chocolatey](https://chocolatey.org/) is the recommended package manager for
Windows).

```powershell
choco install fwup /y
```
Then you can run:

```powershell
fwup c:\path\to\firmware\file
```

That *should* automatically locate your SD card, format it and burn the image.

In summary, for Windows you basically follow all the Linux instructions in WSL2
except for burning the firmware. You build the firmware in WSL2, and then use
fwup from Windows to burn the firmware to your SD card.

## Linux

First, install a few packages using your package manager:

```bash
sudo apt install build-essential automake autoconf git squashfs-tools ssh-askpass pkg-config curl
```

If you're curious, `squashfs-tools` will be used by Nerves to create root
filesystems and `ssh-askpass` will be used to ask for passwords when writing to
MicroSD cards. Some Fedora users have reported that they had to create a symlink
from `/usr/bin/ssh-askpass` to `/usr/bin/qt4-ssh-askpass`.

Next, install the `fwup` utility. Nerves uses `fwup` to create, distribute, and
install firmware images. You can install `fwup` using the instructions found at
[Installation Page](https://github.com/fhunleth/fwup#installing). Installing the
pre-built `.deb` or `.rpm` files is recommended.

If you want to build custom Nerves Systems, you need a few more build tools. If
you skip this step, you'll get an error message with instructions if you ever
need to build a custom system. On Debian and Ubuntu, run the following:

```bash
sudo apt install libssl-dev libncurses5-dev bc m4 unzip cmake python
```

> For other host Linux distributions, you will need to install equivalent
> packages, but we don't have the exact list documented. If you'd like to help
> out, [send us an improvement to this
> page](https://github.com/nerves-project/nerves/blob/master/docs/Installation.md)
> and let us know what worked for you!

Now continue to the instructions for all platforms below.

## All platforms

First, install the required versions of Erlang/OTP and Elixir. We highly
recommend using ASDF since the versions in use will be under your control. See
the [ASDF docs](https://asdf-vm.com/#/core-manage-asdf-vm) for official
documentation. Here's a summary of the install process:

```bash
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.7.1

# The following steps are for bash. If you’re using something else, do the
# equivalent for your shell.
echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.bashrc
echo -e '\n. $HOME/.asdf/completions/asdf.bash' >> ~/.bashrc # optional
source ~/.bashrc

asdf plugin-add erlang
asdf plugin-add elixir

# Note #1:
# If on Debian or Ubuntu, you'll want to install wx before running the next
# line: sudo apt install libwxgtk3.0-dev

# Note #2:
# It's possible to use different Erlang and Elixir versions with Nerves. The
# latest official Nerves systems are compatible with the versions below. In
# general, differences in patch releases are harmless. Nerves detects
# configurations that might not work at compile time.
asdf install erlang 22.2.8
asdf install elixir 1.10.2-otp-22
asdf global erlang 22.2.8
asdf global elixir 1.10.2-otp-22
```

It is important to update the versions of `hex` and `rebar` used by Elixir,
**even if you already had Elixir installed**.

```bash
mix local.hex
mix local.rebar
```

If you have your own version of `rebar` in your path, be sure that it is
up-to-date.

You can now add the `nerves_bootstrap` archive to your Mix environment. This
archive allows Nerves to bootstrap the Mix environment, ensuring that your code
is properly compiled using the right cross-compiler for the target. The
`nerves_bootstrap` archive also includes a project generator, which you can use
to create new Nerves projects. To install the `nerves_bootstrap` archive:

```bash
mix archive.install hex nerves_bootstrap
```
