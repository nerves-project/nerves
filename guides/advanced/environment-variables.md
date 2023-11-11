# Environment variables

Nerves uses environment variables to control the build process and pass
options to cross-compilers.

## Overridable variables

Set these variables if you would like to adjust how Nerves builds
device-specific code.

| Name                              | Description |
| --------------------------------- | ----------- |
| `XDG_DATA_HOME`                   | If set, uses `$XDG_DATA_HOME/nerves` as the data directory. Defaults to `~/.nerves` if unset |
| `NERVES_DL_DIR`                   | Path where compressed Nerves system and toolchain artifacts are downloaded during `mix deps.get`. Defaults to `$XDG_DATA_HOME/nerves/dl` |
| `NERVES_ARTIFACTS_DIR`            | Path where Nerves system and toolchain artifacts are decompressed (from `$NERVES_DL_DIR/<artifact-name>`) and cached for use with compilation. Defaults to `$XDG_DATA_HOME/nerves/artifacts` |
| `NERVES_ENV_DISABLED`             | Set to `1` to disable the nerves_package compiler |
| `NERVES_DEBUG`                    | Set to `1` to print out debug info during compilation |
| `NERVES_LOG_DISABLE_PROGRESS_BAR` | Set to `1` to disable progress bar output when fetching artifacts (typically for CI) |
| `SOURCE_DATE_EPOCH`               | Used for [reproducable builds](https://reproducible-builds.org). Can also be set via `config :nerves, source_date_epoch: val` |

## Nerves-provided environment variables

Nerves sets the environment variables in this section to control compilation.
Most variables affect the compilation of C and C++ code so that they use the
right crosscompiler, flags, and directories. These environment variables are
available to `mix`, `rebar3` and any code invoked from them. For example,
these are frequently used in the `Makefiles` invoked by
[`elixir_make`](https://hex.pm/packages/elixir_make).

| Name                     | Min `nerves_system_br` version | Description |
| ------------------------ | ------------------------------ | ----------- |
| `AR_FOR_BUILD`           | `v1.13.1`                      | The host's `ar` |
| `AS_FOR_BUILD`           | `v1.13.1`                      | The host's `as` |
| `CC`                     | All                            | The path to `gcc` for crosscompiling to the target |
| `CC_FOR_BUILD`           | `v1.13.1`                      | The host's `cc` |
| `CFLAGS`                 | All                            | Recommended C compilation flags |
| `CFLAGS_FOR_BUILD`       | `v1.13.1`                      | Recommended C compiler flags for the host |
| `CMAKE_TOOLCHAIN_FILE`   | `v1.18.3`                      | To build CMake projects, configure CMake with `-DCMAKE_TOOLCHAIN_FILE="$(CMAKE_TOOLCHAIN_FILE)"` |
| `CPPFLAGS`               | `v1.14.5`                      | Recommended C preprocessor flags |
| `CPPFLAGS_FOR_BUILD`     | `v1.13.1`                      | Recommended C preprocessor flags for the host |
| `CROSSCOMPILE`           | All                            | The path and prefix for the crosscompilers (e.g., "$CROSSCOMPILE-gcc" is the path to gcc) |
| `CXX`                    | All                            | The path to `g++` for crosscompiling to the target |
| `CXX_FOR_BUILD`          | `v1.13.1`                      | The host's `g++` |
| `CXXFLAGS`               | All                            | Recommended C++ compilation flags |
| `CXXFLAGS_FOR_BUILD`     | `v1.13.1`                      | Recommended C++ compiler flags for the host |
| `ERL_CFLAGS`             | All                            | Additional compilation flags for Erlang NIFs and ports |
| `ERL_EI_INCLUDE_DIR`     | All                            | Rebar variable for finding erl interface include files |
| `ERL_EI_LIBDIR`          | All                            | Rebar variable for finding erl interface libraries |
| `ERL_LDFLAGS`            | All                            | Additional linker flags for Erlang NIFs and ports |
| `ERTS_INCLUDE_DIR`       | All                            | erlang.mk variable for finding erts include files |
| `GCC_FOR_BUILD`          | `v1.13.1`                      | The host's `gcc` |
| `LD_FOR_BUILD`           | `v1.13.1`                      | The host's `ld` |
| `LDFLAGS`                | All                            | Recommended linker flags |
| `LDFLAGS_FOR_BUILD`      | `v1.13.1`                      | Recommended linker flags for the host |
| `PKG_CONFIG_SYSROOT_DIR` | `v1.8.5`                       | Sysroot for using `pkg-config` to find libraries in the Nerves system |
| `PKG_CONFIG_LIBDIR`      | `v1.8.5`                       | Metadata for `pkg-config` on the target |
| `QMAKESPEC`              | `v1.4.0`                       | If Qt is available, this points to the spec file |
| `REBAR_TARGET_ARCH`      | All                            | Set to the binutils prefix (e.g., `arm-linux-gnueabi`) for [rebar2](https://github.com/rebar/rebar) |
| `STRIP`                  | All                            | The path to `strip` for target binaries (Nerves strips binaries by default) |
| `NERVES_APP`             | All                            | Current Nerves project root path |
| `NERVES_SYSTEM`          | All                            | Path to target Nerves system to use (`$NERVES_ARTIFACTS_DIR/<system-name>`) |
| `NERVES_TOOLCHAIN`       | All                            | Path to target Nerves toolchain to use (`$NERVES_ARTIFACTS_DIR/<toolchain-name>`) |
| `NERVES_SDK_IMAGES`      | All                            | Path to Nerves system images directory (`$NERVES_SYSTEM/images`) |
| `NERVES_SDK_SYSROOT`     | All                            | Path to Nerves system sysroot directory (`$NERVES_SYSTEM/staging`) |
| `TARGET_ABI`             | See below                      | The target ABI (e.g., `gnueabihf`, `musl`) |
| `TARGET_ARCH`            | See below                      | The target CPU architecture (e.g., `arm`, `aarch64`, `mipsel`, `x86_64`, `riscv64`) |
| `TARGET_CPU`             | See below                      | The target CPU (e.g., `cortex_a7`) |
| `TARGET_GCC_FLAGS`       | See below                      | Additional options to be passed to `gcc`. For example, enable CPU-specific features or force ASLR or stack smash protections |
| `TARGET_OS`              | See below                      | The target OS. Always `linux` for Nerves. |

Also see the [`elixir_make`
documentation](https://hexdocs.pm/elixir_make/Mix.Tasks.Compile.ElixirMake.html#module-default-environment-variables)
for additional environment variables that may be useful.

## Target CPU, ARCH, OS, and ABI

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

While the `TARGET_*` environment variables are mostly geared for non-gcc
compilers, it's useful to add custom flags to gcc invocations as well. The
`TARGET_GCC_FLAGS` option supports this. The Nerves tooling will prepend the
contents of `TARGET_GCC_FLAGS` to the `CFLAGS` and `CXXFLAGS` used when
compiling NIFs and ports. This can be used to enable features like ARM NEON
support that would otherwise be off when using crosscompiler toolchain defaults.
Most users don't need to concern themselves with `TARGET_GCC_FLAGS`. If you are
creating a custom system, not setting `TARGET_GCC_FLAGS` is almost always fine,
but will result in NIFs and ports being built with generic compiler options.
