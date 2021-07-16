# Makefile for building the Nerves port monitor process
#
# This code is always run on the host as opposed to nearly everything else with
# Nerves. As such, it explicitly references the host compiler
# (non-crosscompiler)
#
# Makefile targets:
#
# all/install   build and install
# clean         clean build products and intermediates
#
# Variables to override:
#
# MIX_APP_PATH       Path to the build directory
# CC_FOR_BUILD       C compiler. MUST be set if crosscompiling
# CFLAGS_FOR_BUILD   Optional compiler flags
# LDFLAGS_FOR_BUILD  Optional linker flags

PREFIX = $(MIX_APP_PATH)/priv
BUILD  = $(MIX_APP_PATH)/obj

PORT = $(PREFIX)/port

CC_FOR_BUILD ?= $(CC)

LDFLAGS_FOR_BUILD +=
CFLAGS_FOR_BUILD ?= -O2 -Wall -Wextra -Wno-unused-parameter
CFLAGS_FOR_BUILD += -std=c99 -D_GNU_SOURCE

#CFLAGS += -DDEBUG

SRC = $(wildcard src/*.c)
OBJ = $(SRC:src/%.c=$(BUILD)/%.o)

calling_from_make:
	mix compile

all: install
	@if [ -f test/fixtures/port/Makefile ]; then $(MAKE) -C test/fixtures/port; fi

install: $(PREFIX) $(BUILD) $(PORT)

$(OBJ): Makefile

$(BUILD)/%.o: src/%.c
	@echo "HOST_CC $(notdir $@)"
	$(CC_FOR_BUILD) -c $(CFLAGS_FOR_BUILD) -o $@ $<

$(PORT): $(OBJ)
	@echo "HOST_LD $(notdir $@)"
	$(CC_FOR_BUILD) $^ $(LDFLAGS_FOR_BUILD) -o $@

$(PREFIX) $(BUILD):
	@mkdir -p $@

clean:
	$(RM) $(PORT) $(BUILD)/*.o
	if [ -f test/fixtures/port/Makefile ]; then $(MAKE) -C test/fixtures/port clean; fi

.PHONY: all clean calling_from_make install

# Don't echo commands unless the caller exports "V=1"
${V}.SILENT:
