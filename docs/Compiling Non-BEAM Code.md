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

> #### Tip {: .tip}
>
> If you require a long running process from a provided exectuable and need
> similar startup and supervision management of `systemd`, you can also use
> [`:muontrap`](https://hexdocs.pm/muontrap/readme.html) to start it in your
> application supervision. See [this talk](https://youtu.be/BtUmxoccZGE?t=1559)
> for more information

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

Refer to [Environment Variables](Environment Variables.md) for sources available
during compilation if needed.

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

<p align="center">
Is something wrong?
<a href="https://github.com/nerves-project/nerves/edit/main/docs/Compiling%20Non-BEAM%20Code.md">
Edit this page on GitHub
</a>
</p>
