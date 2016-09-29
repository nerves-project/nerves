# Frequently-Asked Questions

This is a collection of questions that often come up as people are getting started with Nerves.
If you tried to go through the [Getting Started guide](https://hexdocs.pm/nerves/getting-started.html) or some of the [example projects](https://github.com/nerves-project/nerves-examples) and got stuck, hopefully one of the following answers will help.
If not, please let us know in the #nerves channel on [the Elixir-Lang Slack](https://elixir-slackin.herokuapp.com/), or [create an Issue or Pull Request to improve this documentation](https://github.com/nerves-project/nerves/tree/master/docs).

### How Do I Connect to the Target using a Serial Cable Instead of Using the HDMI Screen?

By default, the `iex` console is displayed on the screen attached to the HDMI port, which tends to be easier for new people because they can simply connect their target device to a monitor or TV.
For troubleshooting start-up issues and for more advanced development workflows, it's often desirable to connect from your development host to the target using a serial port, for example using the popular [FTDI Cable](https://www.sparkfun.com/products/9717).
This allows you to interact with the console of the target device using a terminal emulator (like `screen`) on your development host.

To override the default, you need to locate the `erlinit.config` for the system you're using and modify it to replace the `-c` option to control the console.
You can figure out what the correct value is by referring to the hardware description table in the README of your target's system repository.
For example, for the Raspberry Pi 3 target, you can find the [hardware description README here](https://github.com/nerves-project/nerves_system_rpi3/blob/master/README.md) and the [default `erlinit.config` here](https://github.com/nerves-project/nerves_system_rpi3/blob/master/rootfs-additions/etc/erlinit.config).

 1. Download the default `erlinit.config` file from the system repository for your target.
 2. Place it in your project folder under `rootfs-additions/etc/erlinit.config`.
 2. Modify the `-c` console setting to match the value shown in the `UART` row of the hardware description table (`rpi3` example shown):

    ```
    # Specify the UART port that the shell should use.
    #-c tty1
    -c ttyS0
    ```

 3. Configure your project to replace this file in your firmware.

    ```
    # config.exs
    use Mix.Config

    config :nerves, :firmware,
      rootfs_additions: "rootfs-additions"
    ```

 4. Connect your USB serial cable to the desired UART pins (per the I/O pin-out for your particular hardware).
 5. On your development host, connect to the serial console.

    * On Linux and Mac OS, use `screen /dev/tty<device>`.  You may need to specify the baud rate as well, for example: `screen /dev/tty<device> 115200`.
    * On Windows, use the `Serial` option to connect to `COM<device>`.

### How do I Configure the Target Hardware to Reboot Instead of Halt on Failure?

Similar to the previous question, we have chosen to have the device default to halting on certain kinds of failures that cause the Erlang VM to crash.
This allows you to more easily read the error and diagnose the problem during development.

For a production deployment, it's recommended that you change the behavior to restart on failure instead.
That way, in the unlikely event that your application crashes, the entire device will reload in a known-good state and continue to operate.

This setting is also configured using the `erlinit.config` file described above.
To have the device restart instead of hang on failure, make a copy of the `erlinit.config` file and make sure the `--hang-on-exit` option is commented out.

```
# Uncomment to hang the board rather than rebooting when Erlang exits
#--hang-on-exit
```

### How do I Use the Platform-Specific Hardware Features of My Target?

Some target hardware has particular features that can be used from your application, but they're not covered in the general Nerves documentation.
In general, platform-specific features will be documented in the target's system documentation.
You may also find what you need by looking at the [community-maintained lisf of libraries](http://nerves-project.org/libraries/) that work well with Nerves.

If you still don't see what you're looking for, please let us know in the #nerves channel on [the Elixir-Lang Slack](https://elixir-slackin.herokuapp.com/), or create an Issue or Pull Request to the [relevant `nerves_system-<target>` repository](https://github.com/nerves-project?query=nerves_system_).

### Is Hardware Platform X Supported by Nerves? If Not, How Do I Work on Adding Support?

The currently-supported target hardware platforms are listed here: https://hexdocs.pm/nerves/targets.html.

In order for Nerves to work, the target hardware needs to be capable of running a full Linux kernel along with the Erlang VM.
This requires around 32 MB of storage and RAM, ruling out most microcontroller-based platforms like Arduino.
Microcontrollers can, however, be used alongside a Nerves-based target as a way to achieve real-time control of I/O pins, which is required for some protocols.

If your intended target isn't in the supported targets list but it meets the basic requirements, here's how to get it working:

 1. If the target board is already supported by [the BuildRoot project](https://buildroot.org/), you're already most of the way there.
    If not, your first step is to figure out what packages and patches are needed to boot your board.
    Normally, this requires some interaction with the board vendor unless it's very similar to another supported board.
    The Free Electrons group has some [great learning materials](http://free-electrons.com/training/buildroot/) that we recommend if you want to get started with BuildRoot.
 2. Mention in the #nerves channel on [the Elixir-Lang Slack](https://elixir-slackin.herokuapp.com/) that you're planning to work on this.
    Someone else may have already started working on it, saving you some effort.
 3. Follow the steps in our documentation about [creating a Nerves System](https://github.com/nerves-project/nerves/blob/master/docs/Systems.md#creating-or-modifying-a-nerves-system-with-buildroot).

