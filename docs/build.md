## Build
To get the maximum performance, you'll need to build Doe from source.

## Dependencies
Get the Zig compiler (0.15.2):
- [Zig download](https://ziglang.org/download)
- If you use Zig often, you can use [zigup](https://github.com/marler8997/zigup) to manage different versions of the compiler.

Once you have zig installed, checkout the repo:
```sh
git clone https://github.com/azhai/doe.git
```

## Run Tests
```sh
# Runs all tests.
zig build test

# Runs just the tracing tests.
zig build test-trace

# Test WASM/WASI target.
zig build build-test -Doptimize=ReleaseSafe -Dtarget=wasm32-wasi
wasm3 zig-out/bin/cli_test.wasm
wasm3 zig-out/bin/lib_test.wasm
wasm3 zig-out/bin/behaviour_test.wasm
wasm3 zig-out/bin/trace_test.wasm
```

## Build the CLI.
Doe is optimized for the ReleaseSafe build. The CLI includes two executables: `doer` (VM runner with REPL support) and `doec` (JIT compiler).
```sh
# For your native target.
zig build cli -Doptimize=ReleaseSafe

# For cross platform build. eg. Host: Linux x64, Target: MacOS arm64
zig build cli -Doptimize=ReleaseSafe -Dtarget=aarch64-macos-none

# For a debug build instead.
zig build cli
```

If all goes well, the Doe CLI executables will be located in `./zig-out/bin/doer` and `./zig-out/bin/doec`.

## Build as a Library. (libdoe)
When using Doe as a API library, you'll need to build a library instead.
```sh
# For your native target.
zig build lib -Doptimize=ReleaseSafe

# For cross platform build. eg. Host: Linux x64, Target: MacOS arm64
zig build lib -Doptimize=ReleaseSafe -Dtarget=aarch64-macos-none

# For Web/WASM.
zig build lib -Doptimize=ReleaseSafe -Dtarget=wasm32-freestanding
```

You'll find the resulting static library in `./zig-out/lib`. It can also be configured to output a shared library instead.

Link the library with your project and include `src/include/cyber.h`.
Zig users can also copy over `src/capi.zig` which is a wrapper over cyber.h. (Zig package TBD.)

See examples on how to use libdoe in `examples/libcyber` as well as the documentation https://azhai.github.io/doe/#libdoe

## Troubleshooting.
- If you have trouble building mimalloc on MacOS, consider changing the sdk path in `lib/mimalloc/lib.zig` to your installed version.

- On a linux distro with selinux (eg. Fedora), add `-Dselinux` to the zig build commands.
