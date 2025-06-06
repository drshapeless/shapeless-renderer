UNAME := $(shell uname -s)

FLAGS =

ifeq ($(UNAME), Darwin)
	FLAGS += -extra-linker-flags='-rpath /usr/local/lib -rpath /opt/homebrew/lib'
endif

all: run

run:
	odin run src $(FLAGS)

build:
	odin build src -debug $(FLAGS)
