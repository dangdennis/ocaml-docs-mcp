.PHONY: all build clean test install fmt

all: build

watch:
	dune build --watch

build:
	dune build

test:
	dune runtest

clean:
	dune clean

install:
	opam install . --deps-only

fmt:
	dune build @fmt --auto-promote

lock:
	dune pkg lock

.DEFAULT_GOAL := all
