# Targets

Nerves provides support for a set of common targets. Each target is referenced with a unique tag name. These tags are used when instructing Nerves which target you would like to compile for. It is important to note that a single tag name may offer support for more than one target board.

## Supported Targets and Systems

Target | System | Tag
--- | --- | ---
Raspberry Pi A+, B, B+ and Zero | [nerves_system_rpi](https://github.com/nerves-project/nerves_system_rpi) | rpi
Raspberry Pi 2 | [nerves_system_rpi2](https://github.com/nerves-project/nerves_system_rpi2) | rpi2
Raspberry Pi 3 | [nerves_system_rpi3](https://github.com/nerves-project/nerves_system_rpi3) | rpi3
BeagleBone Black | [nerves_system_bbb](https://github.com/nerves-project/nerves_system_bbb) | bbb
Alix | [nerves_system_alix](https://github.com/nerves-project/nerves_system_alix) | alix
AG150 | [nerves_system_ag150](https://github.com/nerves-project/nerves_system_ag150) | ag150
Intel Galileo 2 | [nerves_system_galileo](https://github.com/nerves-project/nerves_system_galileo) | galileo
Lego EV3 | [nerves_system_ev3](https://github.com/nerves-project/nerves_system_ev3) | ev3
QEmu Arm | [nerves_system_qemu_arm](https://github.com/nerves-project/nerves_system_qemu_arm) | qemu_arm

## Changing Targets

Nerves projects are configured to allow you to switch between targets by changing the value for the environment variable `NERVES_TARGET`. We configure our project to include the correct system for the target you choose by interpolating it into a string atom for the system reference.

```
def system(target) do
  [{:"nerves_system_#{target}", ">= 0.0.0"}]
end
```

Targets can be set and persisted several ways.

**Global Level** You can `export NERVES_TARGET=rpi3` This is useful if you only own a certain board and want to checkout and play with a variety of published nerves projects.

**Project Level** At the top of the mix file for a Nerves project the project level can specify a default target tag. `@target System.get_env("NERVES_TARGET") || "rpi3"`

**Run Level** You can switch targets at the issue of every mix command by passing `NERVES_TARGET=rpi3 mix compile`

The order of precedence is Run Level, Project Level, Global Level

## Target Dependencies

It is important to note that since Nerves supports the ability of supporting and changing targets in a single application code space, only one nerves_system is included at any time. Because of this, we recommend taking the following approach for including the system dependency separate from your application dependencies.

First, we tell the project config to concatenate the global app deps from the system deps

```
def project do
  [app: :hello_nerves,
   version: "0.0.1",
   target: @target,
   archives: [nerves_bootstrap: "0.1.2"],
   deps_path: "deps/#{@target}",
   build_path: "_build/#{@target}",
   build_embedded: Mix.env == :prod,
   start_permanent: Mix.env == :prod,
   aliases: aliases,
   deps: deps ++ system(@target)]
end
```

This allows us to keep the nerves_system separate form the rest of our dependencies.

```
def deps do
  [{:nerves, "~> 0.3.0"}]
end

def system(target) do
  [{:"nerves_system_#{target}", ">= 0.0.0"}]
end
```
