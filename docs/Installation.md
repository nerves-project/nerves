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

If you've already installed Erlang & Elixir using Homebrew, you'll need to
uninstall them to avoid clashes with the recommended ASDF installation.

```bash
brew uninstall elixir
brew uninstall erlang
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

First, install a few packages using your package manager:

### For Debian based systems
```bash
sudo apt install build-essential automake autoconf git squashfs-tools ssh-askpass pkg-config curl
```
### For Arch based systems

```bash
yay -S base-devel ncurses5-compat-libs openssh-askpass git squashfs-tools curl
```

If you're curious, `squashfs-tools` will be used by Nerves to create root
filesystems and `ssh-askpass` will be used to ask for passwords when writing to
MicroSD cards. Some Fedora and Manjaro users have reported that they had to create a symlink
from `/usr/bin/ssh-askpass` to `/usr/bin/qt4-ssh-askpass`.

Next, install the `fwup` utility. Nerves uses `fwup` to create, distribute, and
install firmware images. You can install `fwup` using the instructions found at
[Installation Page](https://github.com/fwup-home/fwup#installing). Installing the
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
> page](https://github.com/nerves-project/nerves/blob/main/docs/Installation.md)
> and let us know what worked for you!

Now continue to the instructions for all platforms below.

## All platforms

First, install the required versions of Erlang/OTP and Elixir. We highly
recommend using ASDF since the versions in use will be under your control. See
the [ASDF docs](https://asdf-vm.com/#/core-manage-asdf) for official
documentation.

IMPORTANT: Elixir 1.11.0 and 1.11.1 do not work with Nerves. Elixir 1.11.2 and
later are fine. Elixir 1.10.x also works.

Here's a summary of the install process:

```bash
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.8.0

# The following steps are for bash. If you’re using something else, do the
# equivalent for your shell.
echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.bashrc
echo -e '\n. $HOME/.asdf/completions/asdf.bash' >> ~/.bashrc # optional
source ~/.bashrc
# for zsh based systems run the following
echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.zshrc
echo -e '\n. $HOME/.asdf/completions/asdf.bash' >> ~/.zshrc
source ~/.zshrc

asdf plugin-add erlang
asdf plugin-add elixir

# Note #1:
# If on Debian or Ubuntu, you'll want to install wx before running the next line:
# For Ubuntu versions before 20.04 run the next line:
# sudo apt install libwxgtk3.0-dev
# For Ubuntu 20.04 and up run the next line:
# sudo apt install libwxgtk3.0-gtk3-dev
# for arch based systems run the next line:
# yay -S wxgtk2 fop jdk-openjdk unzip


# Note #2:
# It's possible to use different Erlang and Elixir versions with Nerves. The
# latest official Nerves systems are compatible with the versions below. In
# general, differences in patch releases are harmless. Nerves detects
# configurations that might not work at compile time.
asdf install erlang 24.1
asdf install elixir 1.12.3-otp-24
asdf global erlang 24.1
asdf global elixir 1.12.3-otp-24
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
