calling_from_make:
	mix compile

all:
	$(MAKE) -C src all
	if [ -f test/fixtures/port/Makefile ]; then $(MAKE) -C test/fixtures/port; fi

clean:
	$(MAKE) -C src clean
	if [ -f test/fixtures/port/Makefile ]; then $(MAKE) -C test/fixtures/port clean; fi

.PHONY: all clean calling_from_make
