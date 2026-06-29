const std = @import("std");
const builtin = @import("builtin");
const build_config = @import("build_config");
const stdx = @import("stdx");
const app_debug = @import("app_debug.zig");
const c = @import("capi.zig");
const log = std.log.scoped(.main);
const cli = @import("cli.zig");
const os_mod = @import("std/os.zig");
const fmt = @import("fmt.zig");
const is_wasi = builtin.os.tag == .wasi;

test {
    std.testing.refAllDecls(cli);
}

var verbose = false;
var reload = false;
var output_file: ?[]const u8 = null;
var backend: c.Backend = undefined;
var dumpStats = false; // Only for trace build.
var exe_name: []const u8 = "doer"; // Default to VM runner

const CP_UTF8 = 65001;
var prevWinConsoleOutputCP: u32 = undefined;

// Default VM.
var gvm: *c.VM = undefined;
var ginit: std.process.Init = undefined;
var gargs: []const [:0]const u8 = &.{};

pub fn main(init: std.process.Init) !void {
    ginit = init;
    if (!is_wasi) {
        app_debug.attachSegfaultHandler(sig_handler);
    }

    if (builtin.os.tag == .windows) {
        prevWinConsoleOutputCP = std.os.windows.kernel32.GetConsoleOutputCP();
        _ = std.os.windows.kernel32.SetConsoleOutputCP(CP_UTF8);
    }
    defer {
        if (builtin.os.tag == .windows) {
            _ = std.os.windows.kernel32.SetConsoleOutputCP(prevWinConsoleOutputCP);
        }
    }

    const alloc = cli.getAllocator();
    defer cli.deinitAllocator();

    const args = try init.minimal.args.toSlice(alloc);
    gargs = args;

    // Detect executable name to set default backend
    if (args.len > 0) {
        const argv0 = args[0];
        if (std.mem.endsWith(u8, argv0, "doec") or std.mem.endsWith(u8, argv0, "doec.exe")) {
            exe_name = "doec";
            backend = c.BackendJIT;
        } else {
            exe_name = "doer";
            backend = c.BackendVM;
        }
    } else {
        backend = c.BackendVM;
    }

    var cmd: Command = if (std.mem.eql(u8, exe_name, "doec")) .compile else .repl;
    var arg0: ?[]const u8 = null;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (arg[0] == '-') {
            if (std.mem.eql(u8, arg, "-v")) {
                verbose = true;
            } else if (std.mem.eql(u8, arg, "-r")) {
                reload = true;
            } else if (std.mem.eql(u8, arg, "-o")) {
                if (i + 1 < args.len) {
                    i += 1;
                    output_file = args[i];
                } else {
                    std.debug.print("Error: -o requires an output filename argument\n", .{});
                    exit(1);
                }
            } else if (std.mem.eql(u8, arg, "-h")) {
                cmd = .help;
            } else if (std.mem.eql(u8, arg, "--help")) {
                cmd = .help;
            } else {
                if (build_config.trace) {
                    if (std.mem.eql(u8, arg, "-stats")) {
                        dumpStats = true;
                        continue;
                    }
                }
                // Ignore unrecognized options so a script can use them.
            }
        } else {
            // Parse command for both executables
            if (std.mem.eql(u8, arg, "compile")) {
                cmd = .compile;
            } else if (std.mem.eql(u8, arg, "version")) {
                cmd = .version;
            } else if (std.mem.eql(u8, arg, "help")) {
                cmd = .help;
            } else if (std.mem.eql(u8, arg, "fmt")) {
                // Only doer supports fmt for now
                if (std.mem.eql(u8, exe_name, "doer")) {
                    cmd = .fmt;
                } else {
                    if (arg0 == null) {
                        arg0 = arg;
                        os_mod.argv_start = i;
                        break;
                    }
                }
            } else {
                // This is a source file argument
                if (arg0 == null) {
                    arg0 = arg;
                    // If no command was explicitly set, default to eval (run)
                    if (cmd == .repl and !std.mem.eql(u8, exe_name, "doec")) {
                        cmd = .eval;
                    }
                    os_mod.argv_start = i;
                    break;
                }
            }
        }
    }

    // For doec, repl command is not available; default to compile if no command given
    if (std.mem.eql(u8, exe_name, "doec") and cmd == .repl) {
        cmd = .help;
    }

    switch (cmd) {
        .eval => {
            const path = arg0 orelse {
                help();
                return;
            };
            try evalPath(alloc, path);
        },
        .compile => {
            const path = arg0 orelse {
                help();
                return;
            };
            try compilePath(alloc, path);
        },
        .fmt => {
            std.debug.panic("TODO: Embed src/tools/fmt.do", .{});
        },
        .help => {
            help();
        },
        .version => {
            version();
        },
        .repl => {
            try repl(alloc);
        },
    }
}

fn exit(code: u8) noreturn {
    if (builtin.os.tag == .windows) {
        _ = std.os.windows.kernel32.SetConsoleOutputCP(prevWinConsoleOutputCP);
    }
    std.c.exit(code);
}

const Command = enum {
    eval,
    compile,
    fmt,
    help,
    version,
    repl,
};

fn compilePath(alloc: std.mem.Allocator, path: []const u8) !void {
    c.setVerbose(verbose);

    const vm = c.vm_initx(alloc);
    defer c.vm_deinit(vm);
    gvm = vm;
    try cli.init_cli(vm, alloc, ginit.io, gargs);
    defer cli.deinit_cli(vm);

    var config = c.defaultCompileConfig();
    config.single_run = builtin.mode == .ReleaseFast;
    config.backend = backend;
    const res = c.vm_compile_path(vm, path, config);
    if (res != c.Success) {
        switch (res) {
            c.ErrorCompile => {
                if (!c.silent()) {
                    const report = c.vm_compile_error_summary(vm);
                    defer c.vm_freeb(vm, report);
                    std.debug.print("{s}", .{report});
                }
                exit(1);
            },
            else => {
                std.debug.panic("unexpected {}\n", .{res});
            },
        }
    }

    if (output_file) |out_path| {
        var path_buf: [4096]u8 = undefined;
        const path_z = std.fmt.bufPrintZ(&path_buf, "{s}", .{out_path}) catch {
            std.debug.print("Error: output path too long\n", .{});
            exit(1);
        };
        if (!c.vm_dump_bytecode_to_file(vm, path_z.ptr)) {
            std.debug.print("Error: failed to write output to {s}\n", .{out_path});
            exit(1);
        }
        if (verbose) {
            std.debug.print("Output written to {s}\n", .{out_path});
        }
    } else {
        c.vm_dump_bytecode(vm);
    }
}

fn repl(alloc: std.mem.Allocator) !void {
    c.setVerbose(verbose);

    const vm: *c.VM = c.vm_initx(alloc);
    defer c.vm_deinit(vm);
    gvm = vm;

    try cli.init_cli(vm, alloc, ginit.io, gargs);
    defer cli.deinit_cli(vm);

    const a: *cli.App = @ptrCast(@alignCast(c.vm_user_data(vm)));
    a.config.reload = reload;

    var config = c.defaultEvalConfig();
    config.single_run = builtin.mode == .ReleaseFast;
    config.backend = c.BackendVM;
    config.spawn_exe = false;

    const src =
        \\use cli
        \\
        \\cli.repl()
        \\
    ;
    var eval_res: c.EvalResult = undefined;
    const res = c.vm_evalx(vm, "main", src, config, &eval_res);
    if (res != c.Success) {
        const thread = c.vm_main_thread(vm);
        switch (res) {
            c.ErrorPanic => {
                if (!c.silent()) {
                    const report = c.thread_panic_summary(thread);
                    defer c.vm_freeb(vm, report);
                    std.debug.print("{s}", .{report});
                }
            },
            c.ErrorCompile => {
                if (!c.silent()) {
                    const report = c.vm_compile_error_summary(vm);
                    defer c.vm_freeb(vm, report);
                    std.debug.print("{s}", .{report});
                }
            },
            else => {
                std.debug.print("unexpected {}\n", .{res});
            },
        }
        if (builtin.mode == .Debug) {
            return error.EvalError;
        } else {
            exit(1);
        }
    }

    if (verbose) {
        // std.debug.print("\n==VM Info==\n", .{});
        // try vm.dumpInfo();
    }
    const main_thread = c.vm_main_thread(vm);
    if (build_config.trace and dumpStats) {
        c.thread_dump_stats(main_thread);
    }
    if (c.TRACE()) {
        const grc = c.thread_rc(main_thread);
        if (grc != 0) {
            std.debug.print("unreleased refcount: {}\n", .{grc});
            c.thread_dump_live_objects(main_thread);
        }
    }
}

fn evalPath(alloc: std.mem.Allocator, path: []const u8) !void {
    c.setVerbose(verbose);

    const vm: *c.VM = c.vm_initx(alloc);
    defer c.vm_deinit(vm);
    gvm = vm;

    try cli.init_cli(vm, alloc, ginit.io, gargs);
    defer cli.deinit_cli(vm);

    const a: *cli.App = @ptrCast(@alignCast(c.vm_user_data(vm)));
    a.config.reload = reload;

    var config = c.defaultEvalConfig();
    config.single_run = builtin.mode == .ReleaseFast;
    config.backend = backend;
    config.spawn_exe = true;

    var eval_res: c.EvalResult = undefined;
    const res = c.vm_eval_path(vm, path, config, &eval_res);
    if (res != c.Success) {
        switch (res) {
            c.ErrorPanic => {
                if (!c.silent()) {
                    const thread = c.vm_main_thread(vm);
                    const report = c.thread_panic_summary(thread);
                    defer c.vm_freeb(vm, report);
                    std.debug.print("{s}", .{report});
                }
            },
            c.ErrorCompile => {
                if (!c.silent()) {
                    const report = c.vm_compile_error_summary(vm);
                    defer c.vm_freeb(vm, report);
                    std.debug.print("{s}", .{report});
                }
            },
            else => {
                std.debug.print("unexpected {}\n", .{res});
            },
        }
        if (builtin.mode == .Debug) {
            return error.EvalError;
        } else {
            exit(1);
        }
    }

    if (verbose) {
        if (eval_res.res_t != c.TypeVoid) {
            const val_s = c.value_desc(vm, eval_res.res_t, eval_res.res);
            defer c.vm_freeb(vm, val_s);
            std.debug.print("\nmain return: {s}", .{val_s});
        }
        // std.debug.print("\n==VM Info==\n", .{});
        // try c.vm_dump_info() vm.dumpInfo();
    }
    const main_thread = c.vm_main_thread(vm);
    if (build_config.trace and dumpStats) {
        c.thread_dump_stats(main_thread);
    }
    if (c.TRACE()) {
        const grc = c.thread_rc(main_thread);
        if (grc != 0) {
            std.debug.print("unreleased refcount: {}\n", .{grc});
            c.thread_dump_live_objects(main_thread);
        }
    }
}

fn help() void {
    if (std.mem.eql(u8, exe_name, "doer")) {
        std.debug.print(
            \\Doe Runner (VM backend) {s}
            \\
            \\Usage: doer [command?] [options] [source]
            \\
            \\Commands:
            \\  doer                    Run the REPL.
            \\  doer [source]           Compile and run with VM.
            \\  doer compile [source]   Compile and dump bytecode.
            \\  doer help               Print usage.
            \\  doer version            Print version number.
            \\
            \\General options:
            \\  -o <file>  Output bytecode dump to file (compile command only).
            \\  -r         Refetch url imports and cached assets.
            \\  -v         Verbose.
            \\
        , .{c.version()});
    } else {
        std.debug.print(
            \\Doe Compiler (JIT backend) {s}
            \\
            \\Usage: doec [command?] [options] [source]
            \\
            \\Commands:
            \\  doec [source]           Compile to machine code and run. (Experimental)
            \\  doec compile [source]   Compile and dump machine code.
            \\  doec help               Print usage.
            \\  doec version            Print version number.
            \\
            \\General options:
            \\  -o <file>  Output machine code dump to file (compile command only).
            \\  -r         Refetch url imports and cached assets.
            \\  -v         Verbose.
            \\
        , .{c.version()});
    }
}

fn version() void {
    std.debug.print("{s}\n", .{c.full_version()});
}

pub fn panic(msg: []const u8, trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = trace;
    _ = ret_addr;
    app_debug.defaultPanic(msg, @returnAddress(), panic_handler);
}

fn panic_handler() !void {
    try app_debug.vm_panic_handler(gvm);
}

fn sig_handler(sig: std.c.SIG, info: *const std.posix.siginfo_t, ctx_ptr: ?*anyopaque) callconv(.c) void {
    app_debug.handleSegfaultPosix(sig, info, ctx_ptr, sig_handler_inner);
}

fn sig_handler_inner() callconv(.c) void {
    app_debug.vm_segv_handler(gvm) catch |err| {
        std.debug.panic("failed during segfault: {}", .{err});
    };
}
