<!--
  SPDX-FileCopyrightText: 2016 Frank Hunleth
  SPDX-FileCopyrightText: 2016 Justin Schneck
  SPDX-FileCopyrightText: 2017 Greg Mefford
  SPDX-FileCopyrightText: 2018 Nick Veys
  SPDX-FileCopyrightText: 2020 Connor Rigby
  SPDX-FileCopyrightText: 2020 J Allen
  SPDX-FileCopyrightText: 2020 Kian-Meng, Ang
  SPDX-FileCopyrightText: 2020 Petrus Janse van Rensburg
  SPDX-FileCopyrightText: 2020 aguirrem
  SPDX-FileCopyrightText: 2022 Jason Johnson
  SPDX-FileCopyrightText: 2022 Travis Graham
  SPDX-FileCopyrightText: 2023 Joel Shprentz
  SPDX-FileCopyrightText: 2023 Matteo Briani
  SPDX-FileCopyrightText: 2024 Emmanuel Ferdman
  SPDX-FileCopyrightText: 2024 Jon Carstens
  SPDX-License-Identifier: CC-BY-4.0
-->
# Installation

Nerves requires a number of programs on your system to work. These include
Erlang, Elixir, and a few tools for packaging firmware images. Nerves is
actively used on MacOS and various Linux distributions. For Windows users, some
people have had success running Linux in a virtual machine or using the Windows
Subsystem for Linux available in Windows 10. If you have issues after following
the steps below, please search or open a topic in the [Nerves category on the
Elixir Forum](https://elixirforum.com/c/nerves-forum/74).

Nerves requires specific Erlang and Elixir versions. We highly recommend using
[asdf](https://asdf-vm.com) or [mise-en-place](https://mise.jdx.dev/) rather
than your OS's package manager.

## MacOS

The easiest installation route on MacOS is to use [Homebrew](https://brew.sh).
Just run the following:

```bash
brew update
brew install fwup squashfs coreutils xz pkg-config
```

If you've already installed Erlang & Elixir using Homebrew, you'll need to
uninstall them to avoid clashes with the recommended `asdf` or `mise`
installation.

```bash
brew uninstall elixir
brew uninstall erlang
```

Optionally, if you want to build custom Nerves systems, you'll also need to
install [Docker for Mac](https://www.docker.com/docker-mac). After installing
Docker for Mac, you will likely want to adjust the resource limits imposed on
Docker, to allow it to successfully compile more complicated custom systems.
Click the Docker icon in the top menu bar, then click Preferences > Advanced and
allow Docker to use all of your CPUs and as much RAM as you think is reasonable
for your machine (at least 6 GB). The more resources it has access to, the
faster you can compile a custom Nerves system.

Now skip to the instructions for all platforms below.

## Windows

Nerves on Windows 10 requires version 18917 (or later) with Windows Subsystem
for Linux 2 (WSL2) installed. See the [WSL2 install
instructions](https://docs.microsoft.com/en-us/windows/wsl/wsl2-install) for
more information. Once you have WSL2 support enabled you will need to install an
instance of Linux. We recommend installing Ubuntu.

Next, follow the instructions for Linux inside your WSL2 Linux installation to
finish setting up the environment.

Finally, you'll need to install `fwup` using Chocolatey. See the [chocolatey
install guide](https://chocolatey.org/install) for help installing Chocolatey on
your system. With Chocolatey installed, run the following from a Powershell:

```powershell
choco install fwup /y
```

When running on WSL2, Nerves uses the Linux version of `fwup` for building the
firmware files and the Windows version of `fwup` for burning firmware to SD
cards. It is important that you install `fwup` in both environments.

## Linux

First, install a few packages.

<!-- tabs-open -->
### Ubuntu and Debian

```bash
sudo apt install build-essential automake autoconf git squashfs-tools pkg-config curl libmnl-dev libnl-genl-3-dev libssl-dev libncurses5-dev help2man libconfuse-dev libarchive-dev file unzip libgnutls28-dev
```

Then install [fwup](https://github.com/fwup-home/fwup) using `asdf` or `mise` or
manually from source. Nerves uses `fwup` in the build process to create firmware
images. Here are the `asdf` instructions:

```bash
asdf plugin add fwup https://github.com/fwup-home/asdf-fwup.git
asdf install fwup latest
asdf set -u fwup latest
```

### Fedora

```bash
sudo dnf install @development-tools automake autoconf git squashfs-tools pkgconf-pkg-config curl libmnl-devel openssl-devel ncurses-devel help2man libconfuse-devel libarchive-devel
```

Then install [fwup](https://github.com/fwup-home/fwup) using `asdf` or `mise` or
manually from source. Nerves uses `fwup` in the build process to create firmware
images. Here are the `asdf` instructions:

```bash
asdf plugin add fwup https://github.com/fwup-home/asdf-fwup.git
asdf install fwup latest
asdf set -u fwup latest
```

### Arch

```bash
yay -S base-devel ncurses5-compat-libs git squashfs-tools curl
```

### NixOS

Create a `shell.nix` file with the following contents:

```nix
{ pkgs ? import <nixpkgs> {} }:

with pkgs;

mkShell {
  name = "nervesShell";
  buildInputs = [
    autoconf
    automake
    curl
    erlangR28
    fwup
    git
    pkgs.beam.packages.erlangR28.elixir
    rebar3
    squashfsTools
    pkg-config
  ];
}
```

Use `nix-shell shell.nix` to start a shell with all the Nerves dependencies
needed for building firmware.

If instead, you'd like to install the dependencies on your host system, you can
include the same packages listed under `buildInputs` in the
`environment.systemPackages` section of your NixOS `configuration.nix` file.
<!-- tabs-close -->

If these instructions aren't accurate, please consider [sending us an improvement to this
page](https://github.com/nerves-project/nerves/blob/main/guides/introduction/installation.md).

## All platforms

Then install the required versions of Erlang/OTP and Elixir. We highly recommend
using [asdf](asdf-vm.com) or [mise-en-place](https://mise.jdx.dev/). Please
refer to those sites for installation directions.

After you've installed a `asdf` or `mise`, run the following to install
Erlang/OTP and Elixir:

> #### Debian/Ubuntu {: .tip}
>
> If on Debian or Ubuntu, you'll want to install `wx` before installing Erlang.
> Run the command based on your system:
>
> * Ubuntu < 20.04: `sudo apt install libwxgtk3.0-dev`
> * Ubuntu >= 20.04: `sudo apt install libwxgtk3.0-gtk3-dev`
> * Arch based systems: `yay -S wxgtk2 fop jdk-openjdk unzip`

> #### Different Erlang/Elixir versions {: .tip}
>
> It's possible to use different Erlang and Elixir versions with Nerves. The
> latest official Nerves systems are compatible with the versions below. In
> general, differences in patch releases are harmless. Nerves detects
> configurations that might not work at compile time.

<!-- tabs-open -->

### asdf

```sh
asdf plugin add erlang
asdf plugin add elixir

asdf install erlang 28.1.1
asdf install elixir 1.19.1-otp-28
asdf set -u erlang 28.1.1
asdf set -u elixir 1.19.1-otp-28
```

### mise

```sh
mise use -g erlang@28.1.1
mise use -g elixir@1.19.1-otp-28
```

> #### Auto plugin install {: .tip}
>
> `mise` automatically installs the needed plugin. If it does not work for
> some reason, you can also manually install with:
>
> ```sh
> mise plugin install erlang
> mise plugin install elixir
> ```

<!-- tabs-close -->

It is important to update the versions of `hex` and `rebar3` used by Elixir,
**even if you already had Elixir installed**.

```bash
mix local.hex
mix local.rebar
```

If you have your own version of `rebar3` in your path, be sure that it is
up-to-date.

You can now add the `nerves_bootstrap` archive to your Mix environment. This
archive allows Nerves to bootstrap the Mix environment, ensuring that your code
is properly compiled using the right cross-compiler for the target. The
`nerves_bootstrap` archive also includes a project generator, which you can use
to create new Nerves projects. To install the `nerves_bootstrap` archive:

```bash
mix archive.install hex nerves_bootstrap
```
