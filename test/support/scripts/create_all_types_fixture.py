#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
# Generates test/fixtures/all_types.tar
#
# The archive exercises every typeflag understood by Nerves.Tar.Reader:
#   0 / \0  regular file
#   1       hard link
#   2       symlink (short name, short link)
#   3       character device
#   4       block device
#   5       directory
#   L       GNU long name  (GNUTYPE_LONGNAME)  -- name > 100 chars
#   K       GNU long link  (GNUTYPE_LONGLINK)  -- link target > 100 chars
#   K+L     both in sequence (entry with long name AND long link target)
#
# Run from the repo root:
#   python3 test/support/scripts/create_all_types_fixture.py

import io
import os
import tarfile

out_path = os.path.join(
    os.path.dirname(__file__), "..", "fixtures", "all_types.tar"
)
os.makedirs(os.path.dirname(out_path), exist_ok=True)

# -----------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------
def dir_entry(name, mode=0o755):
    ti = tarfile.TarInfo(name=name)
    ti.type = tarfile.DIRTYPE
    ti.mode = mode
    return ti


def regular_entry(name, content: bytes, mode=0o644):
    ti = tarfile.TarInfo(name=name)
    ti.type = tarfile.REGTYPE
    ti.mode = mode
    ti.size = len(content)
    return ti, io.BytesIO(content)


def symlink_entry(name, linkname, mode=0o777):
    ti = tarfile.TarInfo(name=name)
    ti.type = tarfile.SYMTYPE
    ti.mode = mode
    ti.linkname = linkname
    return ti


def hard_link_entry(name, linkname, mode=0o644):
    ti = tarfile.TarInfo(name=name)
    ti.type = tarfile.LNKTYPE
    ti.mode = mode
    ti.linkname = linkname
    return ti


def char_device_entry(name, major, minor, mode=0o660):
    ti = tarfile.TarInfo(name=name)
    ti.type = tarfile.CHRTYPE
    ti.mode = mode
    ti.devmajor = major
    ti.devminor = minor
    return ti


def block_device_entry(name, major, minor, mode=0o660):
    ti = tarfile.TarInfo(name=name)
    ti.type = tarfile.BLKTYPE
    ti.mode = mode
    ti.devmajor = major
    ti.devminor = minor
    return ti


# -----------------------------------------------------------------------
# Build the archive
# -----------------------------------------------------------------------

# These names are intentionally long enough to force GNU L / K extensions:
#   name > 100 chars → "L" extension entry written before the real header
#   linkname > 100 chars → "K" extension entry written before the real header
#
# Exact lengths used:
#   "long_name_dir/" (14) + "a"*90 + ".txt" (4)  = 108 chars  → triggers L
#   "long_name_dir/" (14) + "c"*90 + "_sym" (4)  = 108 chars  → triggers both L and K
#   "../" (3) + "b"*96 + "/target" (7)            = 106 chars  → triggers K
#   "../" (3) + "d"*96 + "/target" (7)            = 106 chars  → triggers K

LONG_NAME_FILE = "long_name_dir/" + "a" * 90 + ".txt"          # 108 chars
LONG_LINK_SYM_NAME = "short_dir/long_link_sym"                  #  23 chars (short)
LONG_LINK_TARGET = "../" + "b" * 96 + "/target"                 # 106 chars

BOTH_LONG_NAME = "long_name_dir/" + "c" * 90 + "_sym"           # 108 chars
BOTH_LONG_TARGET = "../" + "d" * 96 + "/target"                 # 106 chars

REGULAR_CONTENT = b"hello from regular file\n"   # 24 bytes
LONG_NAME_CONTENT = b"file with long name\n"     # 20 bytes

assert len(LONG_NAME_FILE) > 100
assert len(LONG_LINK_TARGET) > 100
assert len(BOTH_LONG_NAME) > 100
assert len(BOTH_LONG_TARGET) > 100

with tarfile.open(out_path, "w:", format=tarfile.GNU_FORMAT) as tar:
    # typeflag '5' - directories
    tar.addfile(dir_entry("short_dir/"))
    tar.addfile(dir_entry("dev/"))
    tar.addfile(dir_entry("long_name_dir/"))

    # typeflag '0' - regular file
    ti, data = regular_entry("short_dir/regular.txt", REGULAR_CONTENT)
    tar.addfile(ti, data)

    # typeflag '2' - symlink (short name, short link)
    tar.addfile(symlink_entry("short_dir/link", "short_target"))

    # typeflag '1' - hard link
    tar.addfile(hard_link_entry("short_dir/hardlink", "short_dir/regular.txt"))

    # typeflag '3' - character device
    tar.addfile(char_device_entry("dev/ttyS0", major=4, minor=64))

    # typeflag '4' - block device
    tar.addfile(block_device_entry("dev/sda", major=8, minor=0))

    # typeflags 'L' + '0' - regular file with a long name
    ti, data = regular_entry(LONG_NAME_FILE, LONG_NAME_CONTENT)
    tar.addfile(ti, data)

    # typeflags 'K' + '2' - symlink with a long link target
    tar.addfile(symlink_entry(LONG_LINK_SYM_NAME, LONG_LINK_TARGET))

    # typeflags 'L' + 'K' + '2' - symlink with both a long name and long link target
    tar.addfile(symlink_entry(BOTH_LONG_NAME, BOTH_LONG_TARGET))

print(f"Written: {os.path.abspath(out_path)}")

# Print a summary of what was written for verification
with tarfile.open(out_path, "r:") as tar:
    for member in tar.getmembers():
        type_char = {
            tarfile.REGTYPE: "0", tarfile.LNKTYPE: "1", tarfile.SYMTYPE: "2",
            tarfile.CHRTYPE: "3", tarfile.BLKTYPE: "4", tarfile.DIRTYPE: "5",
            tarfile.GNUTYPE_LONGNAME: "L", tarfile.GNUTYPE_LONGLINK: "K",
        }.get(member.type, "?")
        link = f" -> {member.linkname}" if member.linkname else ""
        print(f"  [{type_char}] {member.name}{link}")
