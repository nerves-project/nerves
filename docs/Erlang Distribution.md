# Erlang Distribution

## Static Configuration

The simplest way to configure Erlang distribution is to statically (i.e., at
compile time) set the node name and cookie. This is done by editing the
`rel/vm.args` file, which contains the command-line arguments used to launch
the Erlang/OTP virtual machine.

You would simply add `-name` and `-setcookie` parameters, as follows:

```diff
 ## Start the Elixir shell
+-name iex@nerves.local
+-setcookie nerves
 -noshell
 -user Elixir.IEx.CLI
 -extra --no-halt
```

The values you give these parameters are up to you. Note that at minimum you
will need to replace `nerves.local` in the example above with the actual
hostname or IPv4 address that your Nerves device is configured to use or
gets from your local DHCP server.

This method of configuring distribution is therefore best suited to
development use with a static network configuration; if you know neither the
hostname nor IPv4 address your device will get from the local DHCP server,
continue reading below for an alternative way to configure Erlang
distribution.

## Dynamic Configuration

It is also possible to start Erlang distribution dynamically (i.e., at
runtime) in your Nerves application, though it is a little more involved.

The benefit of dynamic configuration is that there is no more need to
hardcode the node name and cookie in `rel/vm.args` in your firmware images;
rather, you can start distribution and bring up the Erlang node after DHCP
autoconfiguration and app initialization is complete, using `Node.start` and
`Node.set_cookie`. This means that you can easily run the same firmware
image on multiple devices on the same network and have them each configure
distribution as appropriate.

Here's an outline of how:

### 1. Configure a rootfs overlay

In your app config, add a rootfs overlay per instructions provided in [Advanced
Configuration](advanced-configuration.html).

### 2. Override the `erlinit.config` file

Copy the default `/etc/erlinit.config` file for your target into your rootfs
overlay and customize it as per the following steps.

### 3. Configure the $HOME environment variable

In your `erlinit.config`, set the `$HOME` environment variable to `/tmp` (a
writable tmpfs partition) instead of the default `/root` (the FAT32 app data
partition on SD card).

```diff
--e LANG=en_US.UTF-8;LANGUAGE=en;ERL_INETRC=/etc/erl_inetrc
+-e LANG=en_US.UTF-8;LANGUAGE=en;ERL_INETRC=/etc/erl_inetrc;HOME=/tmp
```

This step is necessary at present in order that Erlang doesn't quit on you
with `Cookie file /root/.erlang.cookie must be accessible by owner only` in
attempting to autogenerate a cookie file when you call `Node.start`.

The error arises because FAT32 doesn't support file modes and ownership
metadata. We plan to address this problem in Nerves going forward by
converting the app data partition to use another filesystem than FAT32.

### 4. Start EPMD when booting

In your `erlinit.config`, add a line `--alternate-exec /bin/erlwrap.sh`.
Create the `/bin/erlwrap.sh` script in your rootfs overlay, with contents:

```bash
#!/bin/sh
echo "Starting EPMD..."
/usr/lib/erlang/bin/epmd -daemon
echo "Starting Erlang/OTP..."
exec $*
```

This step is necessary since Erlang doesn't automatically start the EPMD
daemon (needed for distribution) if you don't give it a `-name` or `-sname`
parameter in the VM arguments, so you must do this yourself lest `Node.start`
abort with error `Protocol 'inet_tcp': register/listen error: econnrefused`.
