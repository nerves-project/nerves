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
cards. It is important that you install `fwup ` in both environments.

## Linux

### Package manager installs

First, install a few packages using your package manager.

#### On Debian-based systems

```bash
sudo apt install build-essential automake autoconf git squashfs-tools ssh-askpass pkg-config curl libmnl-dev
```

#### On Arch-based systems

```bash
yay -S base-devel ncurses5-compat-libs openssh-askpass git squashfs-tools curl
```

If you're curious, `squashfs-tools` will be used by Nerves to create root
filesystems and `ssh-askpass` will be used to ask for passwords when writing to
MicroSD cards. Some Fedora and Manjaro users have reported that they had to
create a symlink from `/usr/bin/ssh-askpass` to `/usr/bin/qt4-ssh-askpass`.

#### On NixOS or with Nix package manager

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
    erlangR25
    fwup
    git
    pkgs.beam.packages.erlangR25.elixir
    rebar3
    squashfsTools
    x11_ssh_askpass
    pkg-config
  ];
  shellHook = ''
    SUDO_ASKPASS=${pkgs.x11_ssh_askpass}/libexec/x11-ssh-askpass
  '';
}
```

Use `nix-shell shell.nix` to start a shell with all the Nerves dependencies
needed for building firmware.

If instead, you'd like to install the dependencies on your host system, you can
include the same packages listed under `buildInputs` in the
`environment.systemPackages` section of your NixOS `configuration.nix` file.

Please note that you may need to adjust the `SUDO_ASKPASS` environment
variable to include the correct path to the askpass program of your choice. A
known, working alternative to `x11_ssh_askpass` is `lxqt.lxqt-openssh-askpass`.
To use this instead change the package name and change the definition of
`SUDO_ASKPASS` to:

```nix
SUDO_ASKPASS=${pkgs.lxqt.lxqt-openssh-askpass}/bin/lxqt-openssh-askpass
```

### fwup

Next, install the `fwup` utility. Nerves uses `fwup` to create, distribute, and
install firmware images. You can install `fwup` using the instructions found at
[Installation Page](https://github.com/fwup-home/fwup#installing). Installing the
pre-built `.deb` or `.rpm` files is recommended.

### Packages for building custom Nerves systems

If you want to build custom Nerves systems, you need a few more build tools. If
you skip this step, you'll get an error message with instructions if you ever
need to build a custom system. On Debian and Ubuntu, run the following:

```bash
sudo apt install libssl-dev libncurses5-dev bc m4 unzip cmake python3
```

### Other Linux distributions

For other distributions, try adapting one of the sections above.

When you have it working, please consider [sending us an improvement to this
page](https://github.com/nerves-project/nerves/blob/main/docs/Installation.md).

## All platforms

First, install the required versions of Erlang/OTP and Elixir. We highly
recommend using [asdf](asdf-vm.com) or [mise-en-place](https://mise.jdx.dev/).
Please refer to those sites for installation directions.

After you've installed a `asdf` or `mise`, run the following to install
Erlang/OTP and Elixir:

> #### Debian/Ubuntu {: .tip}
>
> If on Debian or Ubuntu, you'll want to install `wx` before installing Erlang. Run
> the command based on your system:
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
asdf plugin-add erlang
asdf plugin-add elixir

asdf install erlang 27.0.1
asdf install elixir 1.17.2-otp-27
asdf global erlang 27.0.1
asdf global elixir 1.17.2-otp-27
```

### mise

```sh
mise use -g erlang@27.0.1
mise use -g elixir@1.17.2-otp-27
```

> #### Auto plugin install {: .tip}
>
> `mise` automatically installs the needed plugin. If it does not work for
> some reason, you can also manually install with:
> ```sh
> mise plugin install erlang
> mise plugin install elixir
> ```

<!-- tabs-close -->

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
