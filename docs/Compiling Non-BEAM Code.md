# Compiling Non-BEAM Code

It's almost guaranteed that you'll have some code in your project that won't be
written in Elixir, Erlang, or another BEAM language. Nerves provides multiple
ways of integrating this code and the one you choose depends on many things.

Here are rules of thumb:

1. Build large and complicated C and C++ projects using Buildroot by creating a
   [Custom system](https://hexdocs.pm/nerves/customizing-systems.html)
2. Build small C and C++ projects using
   [`elixir_make`](https://hex.pm/packages/elixir_make)
3. Look for libraries like [`zigler`](https://hex.pm/packages/zigler) for
   specific languages
4. When hope is lost, compile the programs outside of Nerves and include the
   binaries in a `priv` directory. Static linking is recommended.

In a perfect world, it would be easy to use whatever language you wanted and
adding a program would be as simple as adding a reference to it to your `mix
deps`. Sadly, that's not the case for embedded systems and sometimes an inferior
library may be preferable just because it carries fewer dependencies or is
easier to build.

Be aware of the following caveats with Nerves:

1. Nerves does not use the embedded Linux init systems like `systemd` or
   `BusyBox init`. Initialization is done in either an
   [Application.start callback](https://hexdocs.pm/elixir/Application.html#module-the-application-callback-module)
   or in a `GenServer` so that it can be supervised.
2. D-Bus is not normally enabled on Nerves. It may be enabled in a custom
   system.
3. X Windows is not used. Again, it may be enabled, but it is far more common to
   have UI applications be fullscreen and not use a window manager.
4. Only a few commands are available to shell scripts. You're encouraged to
   use Elixir instead, but if that's not feasible, it's possible to add missing
   commands by enabling them in Busybox in a custom system.

Before you even start, experience has shown that searching the [Erlang/OTP
docs](http://erlang.org/doc/index.html) three times and skimming the
[Erlang source](https://github.com/erlang/otp) lead to all kinds of amazing
discoveries that may not require you to port any code at all. If you do need to
port code, keep in mind that while Nerves uses the Linux kernel, it highly
favors Erlang/OTP ways of building systems and not embedded Linux ways. If you
find yourself continually fighting Nerves and missing embedded Linux, your use
case may be better met by installing Elixir on embedded Linux rather than trying
to make Nerves look more like embedded Linux. Many embedded Elixir libraries
work fine on both Nerves and embedded Linux.

## Compilation environment variables

When compiling non-BEAM code, Nerves sets environment variables to
guide compilation. These environment variables are available to `mix`, `rebar3`
and any code invoked from them. For example, these are frequently used in the
`Makefiles` invoked by [`elixir_make`](https://hex.pm/packages/elixir_make).

Name               | Where set          | Description
------------------ | ------------------ | -----------
AR_FOR_BUILD       | `nerves_system_br` | The host's `ar`
AS_FOR_BUILD       | `nerves_system_br` | The host's `as`
CC                 | `nerves_system_br` | The path to `gcc` for crosscompiling to the target
CC_FOR_BUILD       | `nerves_system_br` | The host's `cc`
CFLAGS             | `nerves_system_br` | Recommended C compilation flags
CFLAGS_FOR_BUILD   | `nerves_system_br` | Recommended C compiler flags for the host
CMAKE_TOOLCHAIN_FILE | `nerves_system_br` | To build CMake projects, configure CMake with `-DCMAKE_TOOLCHAIN_FILE="$(CMAKE_TOOLCHAIN_FILE)"`
CPPFLAGS           | `nerves_system_br` | Recommended C preprocessor flags
CPPFLAGS_FOR_BUILD | `nerves_system_br` | Recommended C preprocessor flags for the host
CROSSCOMPILE       | `nerves_system_br` | The path and prefix for the crosscompilers (e.g., "$CROSSCOMPILE-gcc" is the path to gcc)
CXX                | `nerves_system_br` | The path to `g++` for crosscompiling to the target
CXX_FOR_BUILD      | `nerves_system_br` | The host's `g++`
CXXFLAGS           | `nerves_system_br` | Recommended C++ compilation flags
CXXFLAGS_FOR_BUILD | `nerves_system_br` | Recommended C++ compiler flags for the host
ERL_CFLAGS         | `nerves_system_br` | Additional compilation flags for Erlang NIFs and ports
ERL_EI_INCLUDE_DIR | `nerves_system_br` | Rebar variable for finding erl interface include files
ERL_EI_LIBDIR      | `nerves_system_br` | Rebar variable for finding erl interface libraries
ERL_LDFLAGS        | `nerves_system_br` | Additional linker flags for Erlang NIFs and ports
ERTS_INCLUDE_DIR   | `nerves_system_br` | erlang.mk variable for finding erts include files
GCC_FOR_BUILD      | `nerves_system_br` | The host's `gcc`
LD_FOR_BUILD       | `nerves_system_br` | The host's `ld`
LDFLAGS            | `nerves_system_br` | Recommended linker flags
LDFLAGS_FOR_BUILD  | `nerves_system_br` | Recommended linker flags for the host
PKG_CONFIG_SYSROOT_DIR | `nerves_system_br` | Sysroot for using `pkg-config` to find libraries in the Nerves system
PKG_CONFIG_LIBDIR  | `nerves_system_br` | Metadata for `pkg-config` on the target
QMAKESPEC          | `nerves_system_br` | If Qt is available, this points to the spec file
REBAR_TARGET_ARCH  | `nerves_system_br` | Set to the binutils prefix (e.g., `arm-linux-gnueabi`) for [rebar2](https://github.com/rebar/rebar)
STRIP              | `nerves_system_br` | The path to `strip` for target binaries (Nerves strips binaries by default)
TARGET_ABI         | `nerves_system_*`  | The target ABI (e.g., `gnueabihf`, `musl`)
TARGET_ARCH        | `nerves_system_*`  | The target CPU architecture (e.g., `arm`, `aarch64`, `mipsel`, `x86_64`, `riscv64`)
TARGET_CPU         | `nerves_system_*`  | The target CPU (e.g., `cortex_a7`)
TARGET_OS          | `nerves_system_*`  | The target OS. Always `linux` for Nerves.

Also see the [`elixir_make`
documentation](https://hexdocs.pm/elixir_make/Mix.Tasks.Compile.ElixirMake.html#module-default-environment-variables)
for additional environment variables that may be useful.

### Target CPU, ARCH, OS, and ABI

The `TARGET_*` variables are optionally set by the Nerves system. All official
Nerves systems set them, but it is not mandatory for forks. These variables are
useful for guiding compilation of LLVM-based tools.

The current way of deriving their values is to use [`zig`](https://ziglang.org/)
and to select the combination that makes most sense for the target. To view the
options, install zig and run:

```sh
zig targets | less
```

These variables are defined as custom environment variables in the Nerves
system's `mix.exs`.  For example, the following is the definition for the
Raspberry Pi Zero:

```elixir
  defp nerves_package do
    [
      type: :system,
      ...
      env: [
        {"TARGET_ARCH", "arm"},
        {"TARGET_CPU", "arm1176jzf_s"},
        {"TARGET_OS", "linux"},
        {"TARGET_ABI", "gnueabihf"}
      ]
      ...
    ]
  end
```

## Library recommendations

In general, most Elixir and Erlang libraries that include
[NIFs](http://erlang.org/doc/tutorial/nif.html) and
[ports](http://erlang.org/doc/tutorial/c_port.html) can be made to work with
Nerves. Nerves is, however, less forgiving than normal compilation.

Three recommendations cannot be stressed enough:

First, always compile under `_build`. While it's much easier to compile in the
source directory, this always leads to errors where an executable compiled for
one architecture (the host) ends up being put on the target. Nerves will fail
with an error when this happens, but it causes a lot of confusion.

Second, do not have a `priv` directory in your source tree. While Elixir
provides a shortcut for copying files from a source `priv` directory to the
build output `priv` directory, experience has been that this feature causes
confusion when building native code. If you do have static assets that you want
in the output `priv` directory, add a line to your `Makefile` or `mix.exs` to
copy them.

Third, if you have the choice between using a NIF or a port to interface
external code with Erlang VM, ports offer the benefit of safety since they run
in an OS process. In other words, if the port crashes, Linux cleans up the mess.
If a NIF crashes on Nerves, the BEAM crashes and Nerves reboots the device.

The Internet has many examples of how to write
[NIFs](http://erlang.org/doc/tutorial/nif.html). For an example `Makefile` that
works well with Nerves and embedded Linux, see the [circuits_i2c
Makefile](https://github.com/elixir-circuits/circuits_i2c/blob/main/Makefile).
Also consider [zigler](https://github.com/ityonemo/zigler) for a safer
alternative to C and C++ that works with Nerves.
