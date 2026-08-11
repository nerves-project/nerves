# SPDX-FileCopyrightText: None
#
# SPDX-License-Identifier: CC0-1.0
#

# This is a hack to mask a transient error when upgrading from Nerves 1.x. When
# running `mix deps.update nerves`, the Makefile is still called since the old
# Nerves' mix.exs is in memory. This makes it a no-op.
all:
	@true
