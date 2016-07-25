# Installation

Nerves requires a number of programs on your system to work. These include Erlang, Elixir, and a few other tools for packaging your programs into firmware images. Nerves is actively used on MacOS and various Linux distributions. For Windows users, some people have had success with Linux in VM and the Windows 10 Bash Shell. If you are experiencing issues with any of the tooling, it is important to reference this list to ensure that your system is fully configured to run the Nerves tooling.

## MacOS

The easiest installation route on MacOS is to use [Homebrew](brew.sh). Just run the following:

```
$ brew update
$ brew install erlang
$ brew install elixir
$ brew install fwup squashfs coreutils
```

Now skip to the instructions for all platforms below.

## Linux

We've found quite a bit of variation between Linux distributions. Nerves requires Erlang versions `>= 19.0` and Elixir versions `>= 1.2.4`.
If you need to install Erlang, see the prebuilt versions and guides provided by [Erlang Solutions](https://www.erlang-solutions.com/resources/download.html)
For Elixir, please reference the Elixir [Installation Page](http://elixir-lang.org/install.html).

Next install the `fwup` utility. Nerves uses `fwup` to create, distribute, and install firmware images of your programs. You can install fwup using the instructions found on the [Installation Page](https://github.com/fhunleth/fwup#installing). Installing the prebuilt `.deb` or `.rpm` files is recommended.

Finally, install `squashfs-tools` using your distribution's package manager. For
example:
```
$ sudo apt-get install squashfs-tools
```

Now continue to the instructions for all platforms below.

## All platforms

It is important to update the versions of `hex` and `rebar` used by Elixir. This is critical even if you didn't need to install Elixir:

```
$ mix local.hex
$ mix local.rebar
```
If you have your own version of `rebar` in the path, be sure that it is
uptodate.

You can now add the `nerves_bootstrap` archive to your mix environment. This archive allows Nerves to bootstrap the Mix environment, ensuring that your code is properly compiled using the right cross-compiler for the target. The `nerves_bootstrap` archive also includes a new project generator, which you can use to create new Nerves projects. To install the `nerves_bootstrap` archive:

```
$ mix archive.install https://github.com/nerves-project/archives/raw/master/nerves_bootstrap.ez
```

If the archive fails to install properly using this command, you can download the archive directly and then do:

```
$ mix archive.install /path/to/nerves_bootstrap.ez
```
