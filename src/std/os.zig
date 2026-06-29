const std = @import("std");
const stdx = @import("stdx");
const builtin = @import("builtin");
const C = @import("../capi.zig");
const fmt = @import("../fmt.zig");
const bindings = @import("../builtins/bindings.zig");
const cli = @import("../cli.zig");
const zErrFunc = cli.zErrFunc;
const Symbol = bindings.Symbol;
// const ffi = @import("os_ffi.zig");
const http = @import("../http.zig");
const cache = @import("../cache.zig");
const is_wasm = builtin.cpu.arch.isWasm();

const log = std.log.scoped(.os);

extern "c" fn system(command: [*:0]const u8) c_int;

pub const Src = @embedFile("os.do");

/// Adjusted by the CLI main when args are used to interpret a script file.
pub var argv_start: usize = 0;

const funcs = [_]struct { []const u8, C.BindFunc }{
    // Top level
    .{ "cacheUrl", zErrFunc(cacheUrl) },
    .{ "fetchUrl", zErrFunc(fetchUrl) },

    .{ "stderr", zErrFunc(stderr) },
    .{ "stdin", zErrFunc(stdin) },
    .{ "stdout", zErrFunc(stdout) },
    .{ "exec", zErrFunc(exec) },
    .{ "_args", zErrFunc(_args) },
    .{ "openLib", zErrFunc(openLib) },
};

const types = [_]struct { []const u8, C.BindType }{
    // .{"FFI",          CS.TYPE_HOBJ(null, ffi.FFI_deinit)},
};

pub fn bind(_: ?*C.VM, mod: ?*C.Sym) callconv(.c) C.Bytes {
    for (funcs) |e| {
        C.mod_add_func(mod.?, e.@"0", e.@"1");
    }

    for (types) |e| {
        C.mod_add_type(mod.?, e.@"0", e.@"1");
    }

    C.mod_add_global(mod.?, "vecBitSize", C.BIND_GLOBAL(&simd_bit_size));
    return C.to_bytes("");
}

var simd_bit_size: i64 = if (std.simd.suggestVectorLength(u8)) |VecSize|
    VecSize * 8
else
    0;

const File = extern struct {
    fd: std.c.fd_t,
    closed: bool = false,
};

fn stderr(t: *C.Thread) !C.Ret {
    // if (!cy.hasStdFiles) return t.ret_panic("Unsupported.");

    const ret = C.thread_ret(t, File);
    const handle = std.Io.File.stderr().handle;
    ret.* = .{ .fd = handle };
    return C.RetOk;
}

fn stdin(t: *C.Thread) !C.Ret {
    // if (!cy.hasStdFiles) return t.ret_panic("Unsupported.");

    const ret = C.thread_ret(t, File);
    const handle = std.Io.File.stdin().handle;
    ret.* = .{ .fd = handle };
    return C.RetOk;
}

fn stdout(t: *C.Thread) !C.Ret {
    // if (!cy.hasStdFiles) return t.ret_panic("Unsupported.");

    const ret = C.thread_ret(t, File);
    const handle = std.Io.File.stdout().handle;
    ret.* = .{ .fd = handle };
    return C.RetOk;
}

fn _args(t: *C.Thread) !C.Ret {
    // if (is_wasm) return t.ret_panic("Unsupported.");

    const ret = C.thread_ret(t, C.Slice);
    const byte_buffer_t: C.TypeId = @intCast(C.thread_int(t));
    _ = byte_buffer_t;

    const alloc = C.thread_allocator(t);

    var args: std.ArrayListUnmanaged(C.str) = .empty;
    defer {
        for (args.items) |*arg| {
            C.str_deinit(t, arg);
        }
        args.deinit(alloc);
    }

    for (cli.process_args) |arg| {
        const str = C.str_init(t, arg);
        try args.append(alloc, str);
    }

    const final_args = args.items[argv_start..];

    const slice = C.slice_init(t, final_args.len, @sizeOf(C.str));
    @memcpy(C.slice_items(slice, C.str), final_args);
    try args.resize(alloc, argv_start);
    ret.* = slice;
    return C.RetOk;
}

extern fn hostSleep(secs: u64, nsecs: u64) void;

pub fn openLib(t: *C.Thread) anyerror!C.Ret {
    // if (!cy.hasFFI) return t.ret_panic("Unsupported.");

    // const ret = C.thread_ret(t, ffi.DynLib);

    // const config: ffi.BindLibConfig = .{};
    // return @call(.never_inline, ffi.ffiBindLib, .{t, config, ret});
    return C.thread_ret_panic(t, "TODO");
}

pub extern fn hostFileWrite(fid: u32, str: [*]const u8, strLen: usize) void;

fn cacheUrl(t: *C.Thread) anyerror!C.Ret {
    // if (is_wasm) return t.ret_panic("Unsupported.");

    const vm = C.thread_vm(t);
    const alloc = C.thread_allocator(t);

    const ret = C.thread_ret(t, C.str);
    const url = C.str_bytes(C.thread_str(t));
    const path = try allocCacheUrl(vm, url);
    defer alloc.free(path);
    ret.* = C.str_init(t, path);
    return C.RetOk;
}

pub fn allocCacheUrl(vm: *C.VM, url: []const u8) ![]const u8 {
    const alloc = C.vm_allocator(vm);

    const specGroup = try cache.getSpecHashGroup(alloc, url);
    defer specGroup.deinit(alloc);

    const a: *cli.App = @ptrCast(@alignCast(C.vm_user_data(vm)));
    if (a.config.reload) {
        try specGroup.markEntryBySpecForRemoval(url);
    } else {
        // First check local cache.
        if (try specGroup.findEntryBySpec(url)) |entry| {
            return cache.allocSpecFilePath(alloc, entry);
        }
    }

    const resp = try http.get(alloc, a.httpClient, url);
    defer alloc.free(resp.body);
    if (resp.status != .ok) {
        cli.tracev("cacheUrl response status: {}", .{resp.status});
        return error.UnknownError;
    } else {
        const entry = try cache.saveNewSpecFile(alloc, specGroup, url, resp.body);
        defer entry.deinit(alloc);
        return cache.allocSpecFilePath(alloc, entry);
    }
}

const ExecResult = extern struct {
    out: C.str,
    err: C.str,
    code: i64,
};

pub fn exec(t: *C.Thread) anyerror!C.Ret {
    if (is_wasm) return C.thread_ret_panic(t, "Unsupported.");

    const alloc = C.thread_allocator(t);

    const ret = C.thread_ret(t, ExecResult);
    const args_slice = C.thread_slice(t);
    const args = C.slice_items(args_slice, C.str);
    var buf: std.ArrayListUnmanaged([]const u8) = .empty;
    defer {
        buf.deinit(alloc);
    }
    for (args) |arg| {
        try buf.append(alloc, C.str_bytes(arg));
    }

    // Build a shell command and run via libc system().
    var cmd_aw: std.Io.Writer.Allocating = .init(alloc);
    defer cmd_aw.deinit();
    for (buf.items, 0..) |arg, idx| {
        if (idx > 0) try cmd_aw.writer.writeByte(' ');
        try cmd_aw.writer.print("'{s}'", .{arg});
    }
    try cmd_aw.writer.writeByte(0);
    const cmd = cmd_aw.written();
    const cmd_z: [*:0]const u8 = @ptrCast(cmd.ptr);
    const status = system(cmd_z);

    const out = C.str_init(t, "");
    errdefer t.heap.destructStr(&out);
    const err = C.str_init(t, "");
    errdefer t.heap.destructStr(&err);
    const code: i64 = @intCast(status);

    ret.* = .{
        .out = out,
        .err = err,
        .code = code,
    };
    return C.RetOk;
}

pub fn fetchUrl(t: *C.Thread) anyerror!C.Ret {
    // if (is_wasm) return t.ret_panic("Unsupported.");

    const ret = C.thread_ret(t, C.str);
    const url = C.str_bytes(C.thread_param(t, C.str));

    const vm = C.thread_vm(t);
    const alloc = C.thread_allocator(t);

    const a: *cli.App = @ptrCast(@alignCast(C.vm_user_data(vm)));
    const resp = try http.get(alloc, a.httpClient, url);
    defer alloc.free(resp.body);
    ret.* = C.str_init(t, resp.body);

    return C.RetOk;
}

extern fn hostFetchUrl(url: [*]const u8, urlLen: usize) void;

pub fn dlopen(path: []const u8) !std.DynLib {
    if (builtin.os.tag == .linux and builtin.link_libc) {
        const path_c = try std.posix.toPosixPath(path);
        // Place the lookup scope of the symbols in this library ahead of the global scope.
        const RTLD_DEEPBIND = 0x00008;
        var mode: u32 = @bitCast(std.c.RTLD{
            .LAZY = true,
        });
        mode |= RTLD_DEEPBIND;
        return std.DynLib{
            .inner = .{
                .handle = std.c.dlopen(&path_c, @bitCast(mode)) orelse {
                    return error.FileNotFound;
                },
            },
        };
    } else {
        return std.DynLib.open(path);
    }
}
