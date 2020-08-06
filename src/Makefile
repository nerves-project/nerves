# Makefile for building the nerves port process
#
# Makefile targets:
#
# all/install   build and install
# clean         clean build products and intermediates
#
# Variables to override:
#
# MIX_APP_PATH  path to the build directory
# CC            C compiler. MUST be set if crosscompiling
# CFLAGS        compiler flags for compiling all C files
# LDFLAGS       linker flags for linking all binaries

PREFIX = $(MIX_APP_PATH)/priv
BUILD  = $(MIX_APP_PATH)/obj

PORT = $(PREFIX)/port

LDFLAGS +=
CFLAGS ?= -O2 -Wall -Wextra -Wno-unused-parameter
CFLAGS += -std=c99 -D_GNU_SOURCE

#CFLAGS += -DDEBUG

SRC = $(wildcard *.c)
OBJ = $(SRC:%.c=$(BUILD)/%.o)

calling_from_make:
	cd .. && mix compile

all: install

install: $(PREFIX) $(BUILD) $(PORT)

$(OBJ): Makefile

$(BUILD)/%.o: %.c
	$(CC) -c $(CFLAGS) -o $@ $<

$(PORT): $(OBJ)
	$(CC) $^ $(LDFLAGS) -o $@

$(PREFIX) $(BUILD):
	mkdir -p $@

clean:
	$(RM) $(PORT) $(BUILD)/*.o

.PHONY: all clean calling_from_make install
