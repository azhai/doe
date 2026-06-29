const std = @import("std");
const builtin = @import("builtin");
const cy = @import("../cyber.zig");
const sema = cy.sema;
const C = @import("../capi.zig");
const core = @import("../builtins/core.zig");
const os = @import("../std/os.zig");
const os_mod = @import("../std/os.zig");

const Src = @embedFile("c.do");

const types = [_]struct { []const u8, C.BindType }{
    .{ "u32", C.TYPE_CREATE(createU32Type) },
    .{ "variadic", C.TYPE_CREATE(createVariadicType) },
    .{ "size_t", C.TYPE_CREATE(createSizeTType) },
    .{ "ssize_t", C.TYPE_CREATE(createSSizeTType) },
    .{ "c_int", C.TYPE_CREATE(createCIntType) },
    .{ "c_uint", C.TYPE_CREATE(createCUIntType) },
    .{ "c_long", C.TYPE_CREATE(createCLongType) },
    .{ "c_ulong", C.TYPE_CREATE(createCULongType) },
    .{ "c_char", C.TYPE_CREATE(createCCharType) },
    .{ "c_short", C.TYPE_CREATE(createCShortType) },
    .{ "c_ushort", C.TYPE_CREATE(createCUShortType) },
    .{ "c_longlong", C.TYPE_CREATE(createCLongLongType) },
    .{ "c_ulonglong", C.TYPE_CREATE(createCULongLongType) },
};

comptime {
    @export(&bind, .{ .name = "cl_mod_bind_c", .linkage = .strong });
}

pub fn bind(_: *C.VM, mod: *C.Sym) callconv(.c) C.Bytes {
    for (funcs) |e| {
        C.mod_add_func(mod, e.@"0", e.@"1");
    }

    for (types) |e| {
        C.mod_add_type(mod, e.@"0", e.@"1");
    }
    return C.to_bytes(Src);
}

const funcs = [_]struct { []const u8, C.BindFunc }{
    .{ "@initBindLib", core.zErrFunc(initBindLib) },
    .{ "include", core.zErrConstEvalFunc(import) },
    .{ "flag", core.zErrConstEvalFunc(flag) },
    .{ "bind_lib", core.zErrConstEvalFunc(bind_lib) },
    .{ "from_strz", core.zErrFunc(from_strz) },
    .{ "to_strz", core.zErrFunc(to_strz) },
};

/// C bindings backend was removed (cgen + tcc). This is now a no-op.
pub fn initBindLib(t: *cy.Thread) !C.Ret {
    _ = t;
    return C.RetOk;
}

fn createVariadicType(vm: ?*C.VM, c_mod: ?*C.Sym, decl: ?*C.Node) callconv(.c) *C.Type {
    _ = vm;
    _ = decl;
    const chunk_sym = cy.Sym.fromC(c_mod).cast(.chunk);
    const c = chunk_sym.chunk;

    const new_t = c.sema.createType(.c_variadic, .{}) catch @panic("error");
    return @ptrCast(new_t);
}

fn createU32Type(vm: ?*C.VM, c_mod: ?*C.Sym, decl: ?*C.Node) callconv(.c) *C.Type {
    _ = vm;
    _ = decl;
    const chunk_sym = cy.Sym.fromC(c_mod).cast(.chunk);
    const c = chunk_sym.chunk;

    const new_t = c.sema.createType(.int, .{ .bits = 32 }) catch @panic("error");
    return @ptrCast(new_t);
}

fn createIntType(vm: ?*C.VM, c_mod: ?*C.Sym, decl: ?*C.Node, bits: u32) *C.Type {
    _ = vm;
    _ = decl;
    const chunk_sym = cy.Sym.fromC(c_mod).cast(.chunk);
    const c = chunk_sym.chunk;
    const new_t = c.sema.createType(.int, .{ .bits = bits }) catch @panic("error");
    return @ptrCast(new_t);
}

fn createSizeTType(vm: ?*C.VM, c_mod: ?*C.Sym, decl: ?*C.Node) callconv(.c) *C.Type {
    return createIntType(vm, c_mod, decl, @intCast(@bitSizeOf(usize)));
}

fn createSSizeTType(vm: ?*C.VM, c_mod: ?*C.Sym, decl: ?*C.Node) callconv(.c) *C.Type {
    return createIntType(vm, c_mod, decl, @intCast(@bitSizeOf(isize)));
}

fn createCIntType(vm: ?*C.VM, c_mod: ?*C.Sym, decl: ?*C.Node) callconv(.c) *C.Type {
    return createIntType(vm, c_mod, decl, @intCast(@bitSizeOf(c_int)));
}

fn createCUIntType(vm: ?*C.VM, c_mod: ?*C.Sym, decl: ?*C.Node) callconv(.c) *C.Type {
    return createIntType(vm, c_mod, decl, @intCast(@bitSizeOf(c_uint)));
}

fn createCLongType(vm: ?*C.VM, c_mod: ?*C.Sym, decl: ?*C.Node) callconv(.c) *C.Type {
    return createIntType(vm, c_mod, decl, @intCast(@bitSizeOf(c_long)));
}

fn createCULongType(vm: ?*C.VM, c_mod: ?*C.Sym, decl: ?*C.Node) callconv(.c) *C.Type {
    return createIntType(vm, c_mod, decl, @intCast(@bitSizeOf(c_ulong)));
}

fn createCCharType(vm: ?*C.VM, c_mod: ?*C.Sym, decl: ?*C.Node) callconv(.c) *C.Type {
    return createIntType(vm, c_mod, decl, 8);
}

fn createCShortType(vm: ?*C.VM, c_mod: ?*C.Sym, decl: ?*C.Node) callconv(.c) *C.Type {
    return createIntType(vm, c_mod, decl, 16);
}

fn createCUShortType(vm: ?*C.VM, c_mod: ?*C.Sym, decl: ?*C.Node) callconv(.c) *C.Type {
    return createIntType(vm, c_mod, decl, 16);
}

fn createCLongLongType(vm: ?*C.VM, c_mod: ?*C.Sym, decl: ?*C.Node) callconv(.c) *C.Type {
    return createIntType(vm, c_mod, decl, 64);
}

fn createCULongLongType(vm: ?*C.VM, c_mod: ?*C.Sym, decl: ?*C.Node) callconv(.c) *C.Type {
    return createIntType(vm, c_mod, decl, 64);
}

pub fn from_strz(t: *cy.Thread) !C.Ret {
    if (cy.isWasm) return t.ret_panic("Unsupported.");
    const ret = t.ret(cy.heap.Str);
    const ptr = t.param([*]const u8);
    const bytes = std.mem.span(@as([*:0]const u8, @ptrCast(ptr)));
    ret.* = try t.heap.init_str(bytes);
    return C.RetOk;
}

fn to_strz(t: *cy.Thread) !C.Ret {
    if (cy.isWasm) return t.ret_panic("Unsupported.");
    const ret = t.ret([*]u8);
    const str = t.param(cy.heap.Str);
    defer t.heap.destructStr(&str);
    const slice = str.slice();
    const new: [*]u8 = @ptrCast(std.c.malloc(slice.len + 1));
    @memcpy(new[0..slice.len], slice);
    new[slice.len] = 0;
    ret.* = new;
    return C.RetOk;
}

pub fn bind_lib(c: *cy.Chunk, ctx: *cy.ConstEvalContext) !cy.TypeValue {
    const opt_path = ctx.args[0].asPtr(?*cy.heap.EvalStr);
    defer c.heap.release_object_opt(@ptrCast(opt_path));
    c.has_bind_lib = true;
    if (c.bind_lib) |dl_bind| {
        c.alloc.free(dl_bind);
    }
    c.bind_lib = null;
    if (opt_path) |path| {
        const new_dl_bind = try c.alloc.dupe(u8, path.slice());
        c.bind_lib = new_dl_bind;
    }
    return cy.TypeValue.init(c.sema.void_t, cy.Value.Void);
}

pub fn import(c: *cy.Chunk, ctx: *cy.ConstEvalContext) !cy.TypeValue {
    const spec = ctx.args[0].as_eval_str();
    defer c.heap.release(ctx.args[0]);
    const dupe = try c.alloc.dupe(u8, spec);
    try c.compiler.c_includes.append(c.alloc, dupe);
    return cy.TypeValue.init(c.sema.void_t, cy.Value.Void);
}

pub fn flag(c: *cy.Chunk, ctx: *cy.ConstEvalContext) !cy.TypeValue {
    const str = ctx.args[0].as_eval_str();
    defer c.heap.release(ctx.args[0]);
    const dupe = try c.alloc.dupe(u8, str);
    try c.compiler.c_flags.append(c.alloc, dupe);
    return cy.TypeValue.init(c.sema.void_t, cy.Value.Void);
}
