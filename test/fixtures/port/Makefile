# Variables to override
#
# CC            C compiler
# CROSSCOMPILE	crosscompiler prefix, if any
# CFLAGS	compiler flags for compiling all C files
# LDFLAGS	linker flags for linking all binaries

LDFLAGS +=
CFLAGS ?= -O2 -Wall -Wextra -Wno-unused-parameter
CFLAGS += -std=c99 -D_GNU_SOURCE

SRC=$(wildcard *.c)
BIN=$(SRC:.c=.test)

.PHONY: all clean

all: $(BIN)

%.test: %.c
	$(CC) $(LDFLAGS) $(CFLAGS) -o $@ $<

clean:
	rm -f *.test
