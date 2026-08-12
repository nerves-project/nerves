# Nerves Toolchain: aarch64_nerves_linux_gnu

[![Hex version](https://img.shields.io/hexpm/v/nerves_toolchain_aarch64_nerves_linux_gnu.svg "Hex version")](https://hex.pm/packages/nerves_toolchain_aarch64_nerves_linux_gnu)

This is a Nerves toolchain package.

If you're just trying to use Nerves (i.e., not adding support for a new
hardware device), you don't need to use this directly. In fact, even if you're
developing for a new board, we may already have a cross-compiler available.

This project's purpose is to contain the information for hex.pm so that Nerves
cross-compilers can be referenced in `mix`. See
[nerves-project/toolchains](https://github.com/nerves-project/toolchains) for
the scripts used to generate the actual cross-compiler.

## Using this toolchain in a Nerves system

Add this toolchain to your Nerves system project's `deps` in `mix.exs`:

```elixir
{:nerves_toolchain_aarch64_nerves_linux_gnu, "~> <toolchain version>", runtime: false}
```

Then update `nerves_defconfig` to use the release artifact for this toolchain.
The easiest way is to copy the external toolchain settings from this package's
`defconfig`. In addition to pointing `BR2_TOOLCHAIN_EXTERNAL_URL` at the
release archive for your host and setting the custom prefix, make sure the
kernel headers, libc, and language/runtime options match:

```make
BR2_TOOLCHAIN_EXTERNAL=y
BR2_TOOLCHAIN_EXTERNAL_CUSTOM=y
BR2_TOOLCHAIN_EXTERNAL_DOWNLOAD=y
BR2_TOOLCHAIN_EXTERNAL_URL="https://github.com/nerves-project/toolchains/releases/download/<tag>/<artifact>"
BR2_TOOLCHAIN_EXTERNAL_CUSTOM_PREFIX="aarch64-nerves-linux-gnu"
BR2_TOOLCHAIN_EXTERNAL_HEADERS_6_0=y
BR2_TOOLCHAIN_EXTERNAL_CUSTOM_GLIBC=y
# BR2_TOOLCHAIN_EXTERNAL_INET_RPC is not set
BR2_TOOLCHAIN_EXTERNAL_CXX=y
BR2_TOOLCHAIN_EXTERNAL_FORTRAN=y
BR2_TOOLCHAIN_EXTERNAL_OPENMP=y
```


## Included tool versions and licenses

These versions come from the resolved crosstool-NG configuration for this
toolchain. License values are upstream SPDX license identifiers for the
included components.

| Component | Version | License |
| --- | --- | --- |
| GCC | 15.3.0 | `GPL-3.0-or-later` |
| binutils | 2.46.1 | `GPL-3.0-or-later` |
| Linux headers | 6.0.12 | `GPL-2.0-only WITH Linux-syscall-note` |
| glibc | 2.43 | `LGPL-2.1-or-later` |
| GDB | 17.2 | `GPL-3.0-or-later` |
| expat | 2.7.1 | `MIT` |
| gettext | 0.26 | `GPL-3.0-or-later` |
| GMP | 6.3.0 | `LGPL-3.0-or-later OR GPL-2.0-or-later` |
| ISL | 0.27 | `MIT` |
| libiconv | 1.18 | `LGPL-2.1-or-later` |
| MPC | 1.3.1 | `LGPL-3.0-or-later` |
| MPFR | 4.2.2 | `LGPL-3.0-or-later` |
| ncurses | 6.5 | `MIT` |
| zlib | 1.3.1 | `Zlib` |
| bison | 3.8.2 | `GPL-3.0-or-later` |
| m4 | 1.4.20 | `GPL-3.0-or-later` |


