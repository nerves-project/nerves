# Installation

The following is a collection of tools and dependencies required for your system to run Nerves properly. Nerves is actively used on MacOS and various Linux distributions. For Windows users, some people have had success with Linux in VM and the Windows 10 Bash Shell. If you are experiencing issues with any of the tooling, it is important to reference this list to ensure that your system is fully configured to run the Nerves tooling.

## Elixir

The Nerves build tools and many libraries are written in Elixir and require version `>= 1.2.4`. If you need help installing Elixir, please reference the Elixir [Installation Page](http://elixir-lang.org/install.html).

In addition to Elixir, you will need to fetch dependencies and often compile some Erlang code. Once Elixir is installed you can issue the following commands to install the latest version of both Hex and Rebar

```
$ mix local.hex
$ mix local.rebar
```

## Erlang

Elixir runs on top of the Erlang VM on your host as well as on your target board. What makes Nerves special is that we replace typical Linux initialization mechanisms like systemd or udev with Erlang. This puts your application in a unique and powerful position of having control over the subsystem initialization as well as your application runtime.

If you followed the instructions from earlier to install Elixir using the instructions found on the Elixir [Installation Page](http://elixir-lang.org/install.html), you should already have Erlang installed.

If you need to install Erlang, it is often best to install using guides and repositories provided by [Erlang Solutions](https://www.erlang-solutions.com/resources/download.html)

## fwup

The fwup utility is a configurable firmware update program. It has two modes of operation. The first mode creates compressed archives containing root file system images, bootloaders, and other image material needed for your target hardware. These can be distributed via websites, email or update servers. The second mode applies these firmware images in a robust and repeatable way.

Nerves uses fwup to create, distribute, and install firmware bundles. You can install fwup using the instructions found on the [Installation Page](https://github.com/fhunleth/fwup#installing)

## Host Specific tools

When finalizing firmware and creating a root filesystem for your target, Nerves utilizes scripts and utilities which have dependencies on the following tools.

`gstat`
`squashfs-tools`

For MacOS, these tools can be installed using Homebrew. For more information on how to install homebrew, visit the homebrew [Installation Page](http://brew.sh/)

Once homebrew is installed, you can install these missing utilities by running the following
```
$ brew install coreutils squashfs
```

## Nerves Bootstrap

With Elixir, Erlang, and your host utilities installed, you can now add the `nerves_bootstrap` archive to your mix environment. This archive allows Nerves to bootstrap the Mix environment, ensuring that your code is properly compiled using the right cross-compiler for the target. The `nerves_bootstrap` archive also includes a new project generator, which you can use to create new Nerves projects. To install the `nerves_bootstrap` archive:

```
$ mix archive.install https://github.com/nerves-project/archives/raw/master/nerves_bootstrap.ez
```

If the archive fails to install properly using this command, you can download the archive directly and then do:

```
$ mix archive.install /path/to/nerves_bootstrap.ez
```
