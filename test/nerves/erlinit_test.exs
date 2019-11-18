defmodule Nerves.ErlinitTest do
  use NervesTest.Case, async: false

  alias Nerves.Erlinit

  @example """
  # Additional configuration for erlinit

  # Turn on the debug prints
  #-v

  # Specify where erlinit should send the IEx prompt. Only one may be enabled at
  # a time.

  # Nowhere - let nbtty send it to the gadget USB serial port
  -c null

  # HDMI output
  # -c tty1

  # If more than one tty are available, always warn if the user is looking at the
  # wrong one.
  --warn-unused-tty

  # Use nbtty to improve terminal handling on serial ports.
  # Change this to ttyAMA0 to use the UART pins and remove for HDMI
  -s "/usr/bin/nbtty --tty /dev/ttyGS0 --wait-input"

  # Specify the user and group IDs for the Erlang VM
  #--uid 100
  #--gid 200

  # Uncomment to ensure that the system clock is set to at least the Nerves
  # System's build date/time. If you enable this, you'll still need to use NTP or
  # another mechanism to set the clock, but it won't be decades off.
  #--update-clock

  # Uncomment to hang the board rather than rebooting when Erlang exits
  # NOTE: Do not enable on production boards
  #--hang-on-exit

  # Change the graceful shutdown time. If 10 seconds isn't long enough between
  # calling "poweroff", "reboot", or "halt" and :init.stop/0 stopping all OTP
  # applications, enable this option with a new timeout in milliseconds.
  #--graceful-shutdown-timeout 15000

  # Optionally run a program if the Erlang VM exits
  #--run-on-exit /bin/sh

  # Enable UTF-8 filename handling in Erlang and custom inet configuration
  -e LANG=en_US.UTF-8;LANGUAGE=en;ERL_INETRC=/etc/erl_inetrc;ERL_CRASH_DUMP=/root/crash.dump

  # Mount the application partition (run "man fstab" for field names)
  # NOTE: This must match the location in the fwup.conf. If it doesn't the system
  #       will probably still work fine, but you won't get shell history since
  #       shoehorn/nerves_runtime can't mount the application filesystem before
  #       the history is loaded. If this mount fails due to corruption, etc.,
  #       nerves_runtime will auto-format it. Your applications will need to handle
  #       initializing any expected files and folders.
  -m /dev/mmcblk0p1:/boot:vfat:ro,nodev,noexec,nosuid:
  -m /dev/mmcblk0p3:/root:ext4:nodev:
  -m configfs:/sys/kernel/config:configfs:nodev,noexec,nosuid:
  -m pstore:/sys/fs/pstore:pstore:nodev,noexec,nosuid:
  -m tmpfs:/sys/fs/cgroup:tmpfs:nodev,noexec,nosuid:mode=755,size=1024k
  -m cpu:/sys/fs/cgroup/cpu:cgroup:nodev,noexec,nosuid:cpu
  -m memory:/sys/fs/cgroup/memory:cgroup:nodev,noexec,nosuid:memory

  # Erlang release search path
  -r /srv/erlang

  # Assign a hostname of the form "nerves-<serial_number>".
  # See /etc/boardid.config for locating the serial number.
  -d /usr/bin/boardid
  -n nerves-%s

  # If using shoehorn (https://github.com/nerves-project/shoehorn), start the
  # shoehorn OTP release up first. If shoehorn isn't around, erlinit fails back
  # to the main OTP release.
  --boot shoehorn
  """

  test "parse example file", context do
    in_tmp(context.test, fn ->
      erlinit_opts = Erlinit.decode_config(@example)
      assert erlinit_opts[:ctty] == "null"
      refute erlinit_opts[:verbose]
      assert erlinit_opts[:warn_unused_tty]
    end)
  end

  test "merge options", context do
    in_tmp(context.test, fn ->
      erlinit_opts = Erlinit.decode_config(@example)
      assert Erlinit.merge_opts(erlinit_opts, verbose: true)[:verbose] == true
    end)
  end

  test "remove option", context do
    in_tmp(context.test, fn ->
      erlinit_opts = Erlinit.decode_config(@example)
      merged_opts = Erlinit.merge_opts(erlinit_opts, alternate_exec: nil)
      refute Erlinit.encode_config(merged_opts) =~ "--alternate_exec"
    end)
  end

  test "merge keep options", context do
    in_tmp(context.test, fn ->
      erlinit_opts = Erlinit.decode_config(@example)
      merged_opts = Erlinit.merge_opts(erlinit_opts, mount: "1234")
      assert Erlinit.encode_config(merged_opts) =~ "--mount 1234"
    end)
  end

  test "override ctty", context do
    in_tmp(context.test, fn ->
      erlinit_opts = Erlinit.decode_config(@example)
      assert Erlinit.merge_opts(erlinit_opts, ctty: "1234")[:ctty] == "1234"
    end)
  end
end
