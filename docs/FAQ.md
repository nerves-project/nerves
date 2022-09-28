# Frequently-Asked Questions

This is a collection of questions that often come up as people are getting started with Nerves.
If you tried to go through the [Getting Started guide](https://hexdocs.pm/nerves/getting-started.html) or some of the [example projects](https://github.com/nerves-project/nerves_examples) and got stuck, hopefully one of the following answers will help.
If not, please let us know in the #nerves channel on [the Elixir-Lang Slack](https://elixir-slackin.herokuapp.com/), or [create an Issue or Pull Request to improve this documentation](https://github.com/nerves-project/nerves/tree/main/docs).

## Where can persistent data be stored?

For most use cases, the `/data` partition is the right place to store data.  It
is initialized on first boot and is not overwritten when new firmware is pushed
to the device.

The `mix firmware.burn` task clears it out so that partition is guaranteed to be
empty when the device boots. This is useful to ensure that the device is known
state. There's a pattern for implementing a "Reset to factory defaults" feature
by erasing the partition and rebooting.

If you're updating firmware regularly by writing to a MicroSD card, try running
`mix firmware.burn --task upgrade`. This won't reset the application data
partition.

Some Elixir libraries write to their `priv` directory by default. This won't
work since all code and the `priv` directories are stored in a read-only file
partition. Usually there's a way to override this default choice and specify a
path to `/data` for that library to use.

Factory calibration and other provisioning data is either stored in a custom
file partition or in the U-Boot environment block. The latter is accessible via
`Nerves.Runtime.KV` functions.

## How can I apply a firmware update manually?

Assuming that you have already put a known good firmware inside "/data/known_good.fw" (perhaps with sftp) then you can run the following commands

```elixir
iex> cmd("fwup -i /data/known_good.fw --apply --task upgrade " <>
  "--no-unmount -d #{Nerves.Runtime.KV.get("nerves_fw_devpath")}")
iex> reboot
```

## How do I push firmware updates remotely?

SSH is a good default for local development and is enabled by default (via `mix nerves.new`) with https://github.com/nerves-project/nerves_ssh (note: previously https://github.com/nerves-project/nerves_firmware_ssh was enabled by default)

For production environments you might also want to look at https://www.nerves-hub.org/ (either hosted or self-hosted)

## Using a USB Serial Console

By default on some Raspberry Pi family of targets, the `IEx` console is displayed on the screen attached to the HDMI port, which tends to be easier for new people because they can simply connect their target device to a monitor or TV.
For troubleshooting start-up issues and for more advanced development workflows, it's often desirable to connect from your development host to the target using a serial port, for example using the popular [FTDI Cable](https://www.sparkfun.com/products/9717).
This allows you to interact with the console of the target device using a terminal emulator (like `screen`) on your development host.

To override the default, you need to locate the `erlinit.config` for the system you're using and modify it to replace the `-c` option to control the console.
You can figure out what the correct value is by referring to the hardware description table in the README of your target's system repository.
For example, for the Raspberry Pi 3 target, you can find the [hardware description README here](https://github.com/nerves-project/nerves_system_rpi3/blob/main/README.md) and the [default `erlinit.config` here](https://github.com/nerves-project/nerves_system_rpi3/blob/main/rootfs_overlay/etc/erlinit.config).

 1. Download the default `erlinit.config` file from the system repository for your target.
 2. Place it in your project folder under `rootfs_overlay/etc/erlinit.config`.
 3. Modify the `-c` console setting to match the value shown in the `UART` row of the hardware description table (`rpi3` example shown):

    ```bash
    # rootfs_overlay/etc/erlinit.config

    ...

    # Specify the UART port that the shell should use.
    #-c tty1
    -c ttyAMA0
    ```

 4. Configure your project to replace this file in your firmware.

    ```elixir
    # config/config.exs

    config :nerves, :firmware,
      rootfs_overlay: "rootfs_overlay"
    ```

 5. Connect your USB serial cable to the desired UART pins (per the I/O pin-out for your particular hardware).
 6. On your development host, connect to the serial console.

    * On Linux and Mac OS, use `screen /dev/tty<device>`.
      You may need to specify the baud rate as well, for example: `screen /dev/tty<device> 115200`.
    * On Windows, use the `Serial` option to connect to `COM<device>`.

## Change Behavior on BEAM Failure

Similar to the previous question, we have chosen to have the device default to halting on certain kinds of failures that cause the Erlang VM to crash.
This allows you to more easily read the error and diagnose the problem during development.

For a production deployment, it's recommended that you change the behavior to restart on failure instead.
That way, in the unlikely event that your application crashes, the entire device will reload in a known-good state and continue to operate.

This setting is also configured using the `erlinit.config` file described above.
To have the device restart instead of hang on failure, make a copy of the `erlinit.config` file and make sure the `--hang-on-exit` option is commented out.

```bash
# Uncomment to hang the board rather than rebooting when Erlang exits
#--hang-on-exit
```

You can also have the device drop into a shell when the Erlang VM crashes, allowing you to troubleshoot at the Linux OS level.

```bash
# Optionally run a program if the Erlang VM exits
#--run-on-exit /bin/sh
```

## Platform-Specific Hardware Support

Some target hardware has particular features that can be used from your
application, but they're not covered in the general Nerves documentation.  In
general, platform-specific features will be documented in the target's system
documentation.  You may also find what you need by searching
[hex.pm](https://hex.pm) for libraries that use that feature.

If you still don't see what you're looking for, please let us know in the #nerves channel on [the Elixir-Lang Slack](https://elixir-slackin.herokuapp.com/), or create an Issue or Pull Request to the [relevant `nerves_system-<target>` repository](https://github.com/nerves-project?query=nerves_system_).

<p align="center">
Is something wrong?
<a href="https://github.com/nerves-project/nerves/edit/main/docs/FAQ.md">
Edit this page on GitHub
</a>
</p>
