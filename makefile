UNAME := $(shell uname -s)

EXTRA_LINKER_FLAGS =

ifeq ($(UNAME), Darwin)
	EXTRA_LINKER_FLAGS += -rpath /usr/local/lib -rpath /opt/homebrew/lib
endif

all: run

run:
	odin run src -extra-linker-flags='$(EXTRA_LINKER_FLAGS)'

build:
	odin build src -debug -extra-linker-flags='$(EXTRA_LINKER_FLAGS)'
