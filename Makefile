# Makefile for building, testing, and running examples of the Doe language.
# Targets:
#   make            - Build CLI tools in ReleaseSafe mode (default).
#   make debug      - Build CLI tools in Debug mode.
#   make fast       - Build CLI tools in ReleaseFast mode.
#   make build      - Alias for the default build.
#   make clean      - Remove build outputs.
#   make rebuild    - Clean and rebuild.
#   make test       - Run all tests (behavior, lib, cli, trace).
#   make behavior-test - Run behavior tests only.
#   make lib-test   - Run library tests only.
#   make cli-test   - Run CLI tests only.
#   make trace-test - Run trace tests only.
#   make examples   - Run all .do example scripts.
#   make hello      - Run the hello example.
#   make fizzbuzz   - Run the fizzbuzz example.
#   make fib        - Run the fibonacci example.
#   make account    - Run the account example.
#   make ffi        - Build libfoo and run the ffi example.
#   make version    - Print the Doe version.
#   make run        - Run an example: make run SCRIPT=examples/hello.do
#
# CLI Tools:
#   doer            - VM backend runner and REPL (default for running scripts)
#   doec            - JIT compiler (experimental)
#
# Environment variables:
#   ZIG            - Zig binary (default: zig)
#   OPTIMIZE       - Zig optimize mode (default: ReleaseSafe)
#   DOER           - doer binary path (default: ./zig-out/bin/doer)
#   DOEC           - doec binary path (default: ./zig-out/bin/doec)
#   EXAMPLES_DIR   - Examples directory (default: examples)

ZIG       ?= zig
OPTIMIZE  ?= ReleaseSafe
DOER      ?= ./zig-out/bin/doer
DOEC      ?= ./zig-out/bin/doec
EXAMPLES_DIR ?= examples

# Detect platform: shared library extension and C compiler.
UNAME_S := $(shell uname -s 2>/dev/null)
ifeq ($(UNAME_S),Darwin)
    LIB_EXT := dylib
    CC ?= clang
else ifeq ($(UNAME_S),Linux)
    LIB_EXT := so
    CC ?= cc
else
    LIB_EXT := so
    CC ?= cc
endif

EXAMPLES := \
	$(EXAMPLES_DIR)/hello.do \
	$(EXAMPLES_DIR)/fizzbuzz.do \
	$(EXAMPLES_DIR)/fibonacci.do \
	$(EXAMPLES_DIR)/account.do \
	$(EXAMPLES_DIR)/fiber.do

# Targets that do not correspond to files.
.PHONY: all build debug fast clean rebuild \
        test behavior-test lib-test cli-test trace-test \
        examples hello fizzbuzz fib account fiber ffi version run help

# Default: build the CLI.
all: build

# Print available targets.
help:
	@echo "Doe Makefile targets:"
	@echo "  make            Build the CLI (ReleaseSafe)."
	@echo "  make debug      Build the CLI (Debug)."
	@echo "  make fast       Build the CLI (ReleaseFast)."
	@echo "  make clean      Remove build outputs."
	@echo "  make rebuild    Clean and rebuild."
	@echo "  make test       Run all tests."
	@echo "  make lib-test   Run library tests."
	@echo "  make cli-test   Run CLI tests."
	@echo "  make behavior-test  Run behavior tests."
	@echo "  make trace-test Run trace tests."
	@echo "  make examples   Run all example scripts."
	@echo "  make hello      Run the hello example."
	@echo "  make fizzbuzz   Run the fizzbuzz example."
	@echo "  make fib        Run the fibonacci example."
	@echo "  make account    Run the account example."
	@echo "  make ffi        Build libfoo and run the ffi example."
	@echo "  make version    Print the Doe version."
	@echo "  make run SCRIPT=<path>  Run any .do script."

# ---- Build targets ----

build:
	$(ZIG) build -Doptimize=$(OPTIMIZE) cli

debug:
	$(ZIG) build -Doptimize=Debug cli

fast:
	$(ZIG) build -Doptimize=ReleaseFast cli

# Build every test artifact without running them.
build-test:
	$(ZIG) build -Doptimize=$(OPTIMIZE) build-test

clean:
	rm -rf zig-out .zig-cache

rebuild: clean build

# ---- Test targets ----

test: behavior-test lib-test cli-test trace-test

behavior-test:
	$(ZIG) build -Doptimize=$(OPTIMIZE) behavior-test

lib-test:
	$(ZIG) build -Doptimize=$(OPTIMIZE) lib-test

cli-test:
	$(ZIG) build -Doptimize=$(OPTIMIZE) cli-test

trace-test:
	$(ZIG) build -Doptimize=Debug trace-test

# ---- Example targets ----

# Run all example scripts. Skip fiber.do since it is currently commented out.
examples: build $(EXAMPLES)

# Each example depends on the built CLI; the recipe runs the script.
$(EXAMPLES_DIR)/%.do: build
	@echo ""
	@echo "================================================================================"
	@echo "Running: $@"
	@echo "================================================================================"
	$(DOER) $@

# Fiber example is fully commented out; just confirm it parses.
fiber: build
	@echo "[fiber.do is currently commented out — skipping execution]"

# FFI example requires the cgen/tcc backend which was removed. Skipping.
ffi: build
	@echo "[ffi.do requires the removed cgen/tcc backend — skipping execution]"

libfoo.$(LIB_EXT): examples/foo.c
	$(CC) -shared -fPIC -o $@ $<

# Convenience aliases for individual examples.
hello:     build
	$(DOER) $(EXAMPLES_DIR)/hello.do

fizzbuzz:  build
	$(DOER) $(EXAMPLES_DIR)/fizzbuzz.do

fib:       build
	$(DOER) $(EXAMPLES_DIR)/fibonacci.do

account:   build
	$(DOER) $(EXAMPLES_DIR)/account.do

# ---- Misc ----

version: build
	$(DOER) version

# Generic runner: make run SCRIPT=examples/hello.do
run: build
	$(DOER) $(SCRIPT)

# Create compatibility symlink for `doe` -> `doer`
compat: build
	@cd zig-out/bin && ln -sf doer doe 2>/dev/null || true
	@echo "Created symlink: zig-out/bin/doe -> doer"
