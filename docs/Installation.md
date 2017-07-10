# Installation

Nerves requires a number of programs on your system to work.
These include Erlang, Elixir, and a few tools for packaging firmware images.
Nerves is actively used on MacOS and various Linux distributions.
For Windows users, some people have had success running Linux in a virtual machine or using the Windows Subsystem for Linux available in Windows 10.
If you have issues with any of the tooling after following the steps below, we recommend you reach out to us in [the #nerves channel on the Elixir Slack](https://elixir-slackin.herokuapp.com/).

## MacOS

The easiest installation route on MacOS is to use [Homebrew](brew.sh).
Just run the following:

```bash
$ brew update
$ brew install erlang
$ brew install elixir
$ brew install fwup squashfs coreutils
```

Optionally, if you want to build custom Nerves Systems, you'll also need to install [Docker for Mac](https://www.docker.com/products/overview#/install_the_platform).

Now skip to the instructions for all platforms below.

## Linux

We've found quite a bit of variation between Linux distributions.
Nerves requires Erlang versions `19.x` and Elixir versions `>= 1.4.0`.
If you need to install Erlang, see the prebuilt versions and guides provided by [Erlang Solutions](https://www.erlang-solutions.com/resources/download.html).
For Elixir, please reference the Elixir [Installation Page](http://elixir-lang.org/install.html).

Next, install the `fwup` utility.
Nerves uses `fwup` to create, distribute, and install firmware images of your programs.
You can install `fwup` using the instructions found on the [Installation Page](https://github.com/fhunleth/fwup#installing).
Installing the pre-built `.deb` or `.rpm` files is recommended.

The `ssh-askpass` package is also required on Linux so that the `mix firmware.burn` step will be able to use `sudo` to gain the required permission to write directly to an SD card:

```bash
$ sudo apt-get install ssh-askpass
```

Finally, install `squashfs-tools` using your distribution's package manager.
For example:

```bash
$ sudo apt-get install squashfs-tools
```

Optionally, if you want to build custom Nerves Systems, you need a few more build tools.
Because Linux can build natively rather than inside a container, you need to have all of the dependencies installed on your host.
On Debian and Ubuntu, run the following:

```bash
sudo apt-get install git g++ libssl-dev libncurses5-dev bc m4 make unzip cmake
```

> For other host Linux distributions, you will need to install equivalent packages, but we don't have the exact list documented.
> If you'd like to help out, [send us an improvement to this page](https://github.com/nerves-project/nerves/blob/master/docs/Systems.md) and let us know what worked for you!

Now continue to the instructions for all platforms below.

## All platforms

It is important to update the versions of `hex` and `rebar` used by Elixir, **even if you already had Elixir installed**.

```bash
$ mix local.hex
$ mix local.rebar
```

If you have your own version of `rebar` in your path, be sure that it is up-to-date.

You can now add the `nerves_bootstrap` archive to your Mix environment.
This archive allows Nerves to bootstrap the Mix environment, ensuring that your code is properly compiled using the right cross-compiler for the target.
The `nerves_bootstrap` archive also includes a project generator, which you can use to create new Nerves projects.
To install the `nerves_bootstrap` archive:

```bash
$ mix archive.install https://github.com/nerves-project/archives/raw/master/nerves_bootstrap.ez
```

If the archive fails to install properly using this command, or you need to perform an offline installation, you can download the `.ez` file and install it like this:

```bash
$ mix archive.install /path/to/nerves_bootstrap.ez
```

Once installed, you can later upgrade `nerves_bootstrap` by doing:

```bash
mix local.nerves
```
