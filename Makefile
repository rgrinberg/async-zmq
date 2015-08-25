default: all

configure:
	obuild configure

configure-all:
	obuild configure --enable-tests

configure-no-tests: configure

build:
	obuild build

all: build

test:
	obuild test

clean:
	obuild clean

install:
	obuild install

uninstall:
	ocamlfind remove async_zmq

.PHONY: build all build default install uninstall configure-all configure