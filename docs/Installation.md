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
features added in recent versions of Elixir (`>= 1.4.0`). Because it can be hard
to manage these tool versions with sufficient granularity using operating system
packages, it is recommended that you use [ASDF](https://github.com/asdf-vm/asdf)
to manage Erlang and Elixir installations. This tool works the same on its
supported platforms, so you'll find more details in the All Platforms section
below.

## MacOS

The easiest installation route on MacOS is to use [Homebrew](brew.sh).
Just run the following:

```bash
$ brew update
$ brew install fwup squashfs coreutils
```

Optionally, if you want to build custom Nerves Systems, you'll also need to
install [Docker for Mac](https://www.docker.com/docker-mac). After installing
Docker for Mac, you will likely want to adjust the resource limits imposed on
Docker, to allow it so successfully compile more complicated custom systems.
Click the Docker icon in the top menu bar, then click Preferences > Advanced and
allow Docker to use all of your CPUs and as much RAM as you think is reasonable
for your machine (at least 6 GB). The more resources it has access to, the
faster you can compile a custom Nerves system.

Now skip to the instructions for all platforms below.

## Linux

First, install the `fwup` utility. Nerves uses `fwup` to create, distribute, and
install firmware images of your programs. You can install `fwup` using the
instructions found on the [Installation
Page](https://github.com/fhunleth/fwup#installing). Installing the pre-built
`.deb` or `.rpm` files is recommended.

The `ssh-askpass` package is also required on Linux so that the `mix
firmware.burn` step will be able to use `sudo` to gain the required permission
to write directly to an SD card:

```bash
$ sudo apt-get install ssh-askpass
```

Finally, install `squashfs-tools` using your distribution's package manager.
For example:

```bash
$ sudo apt-get install squashfs-tools
```

Optionally, if you want to build custom Nerves Systems, you need a few more
build tools. Because Linux can build natively rather than inside a container,
you need to have all of the dependencies installed on your host. On Debian and
Ubuntu, run the following:

```bash
$ sudo apt-get install git g++ libssl-dev libncurses5-dev bc m4 make unzip cmake python
```

> For other host Linux distributions, you will need to install equivalent
> packages, but we don't have the exact list documented. If you'd like to help
> out, [send us an improvement to this
> page](https://github.com/nerves-project/nerves/blob/master/docs/Installation.md)
> and let us know what worked for you!

Now continue to the instructions for all platforms below.

## All platforms

First, install the required versions of Erlang/OTP and Elixir using ADSF (more
details at https://github.com/asdf-vm/asdf/blob/master/README.md#setup).

```bash
$ git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.3.0
# The following steps are for BASH. If you’re using something else, do the
# equivalent for your shell.
$ echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.bash_profile
$ echo -e '\n. $HOME/.asdf/completions/asdf.bash' >> ~/.bash_profile # optional
$ source ~/.bash_profile
$ asdf plugin-add erlang https://github.com/asdf-vm/asdf-erlang.git
$ asdf plugin-add elixir https://github.com/asdf-vm/asdf-elixir.git
$ asdf install erlang 20.1 # This takes a while
$ asdf install elixir 1.5.2
$ asdf global erlang 20.1
$ asdf global elixir 1.5.2
```

It is important to update the versions of `hex` and `rebar` used by Elixir,
**even if you already had Elixir installed**.

```bash
$ mix local.hex
$ mix local.rebar
```

If you have your own version of `rebar` in your path, be sure that it is
up-to-date.

You can now add the `nerves_bootstrap` archive to your Mix environment. This
archive allows Nerves to bootstrap the Mix environment, ensuring that your code
is properly compiled using the right cross-compiler for the target. The
`nerves_bootstrap` archive also includes a project generator, which you can use
to create new Nerves projects. To install the `nerves_bootstrap` archive:

```bash
$ mix archive.install hex nerves_bootstrap
```

If the archive fails to install properly using this command, or you need to
perform an offline installation, you can download the `.ez` file and install it
like this:

```bash
$ mix archive.install /path/to/nerves_bootstrap.ez
```

Once installed, you can later upgrade `nerves_bootstrap` by doing:

```bash
$ mix local.nerves
```
