const std = @import("std");
const builtin = @import("builtin");
const build_config = @import("build_config");
const test_config = @import("test_config");
const stdx = @import("stdx");
const t = stdx.testing;
const zeroInit = std.mem.zeroInit;

const cli = @import("cli.zig");
const log = std.log.scoped(.behavior_test);
const c = @import("capi.zig");
const setup = @import("test/setup.zig");
const eval = setup.eval;
const compile = setup.compile;
const evalPass = setup.evalPass;
const VMrunner = setup.VMrunner;
const Config = setup.Config;
const eqUserError = setup.eqUserError;
const EvalResult = setup.EvalResult;
const is_wasm = builtin.cpu.arch.isWasm();

const Case = struct {
    config: Config,
    skip: bool = false,
};

const Runner = struct {
    cases: std.ArrayListUnmanaged(Case),

    fn case(s: *Runner, path: []const u8) void {
        s.case2(.{ .uri = path });
    }

    fn case2(s: *Runner, config: Config) void {
        s.cases.append(t.alloc, Case{ .config = config }) catch @panic("error");
    }

    fn caseSkip(s: *Runner, path: []const u8) void {
        s.cases.append(t.alloc, Case{ .config = .{ .uri = path }, .skip = true }) catch @panic("error");
    }

    fn caseDebug(s: *Runner, path: []const u8) void {
        s.case2(.{ .debug = true, .uri = path });
    }
};

const caseFilter: ?[]const u8 = null;
// const caseFilter: ?[]const u8 = "meta.do";
const failFast: bool = true;

pub fn isAot(backend: c.Backend) bool {
    _ = backend;
    return false;
}

fn test_syntax(run: *Runner) void {
    run.case("syntax/block_no_child_error.do");
    run.case("syntax/change_to_spaces_error.do");
    run.case("syntax/change_to_tabs_error.do");
    run.case("syntax/comment_first_line.do");
    run.case("syntax/comment_last_line.do");
    run.case("syntax/comment_multiple.do");
    run.case("syntax/compact_block_error.do");
    run.case("syntax/func_missing_param_type_error.do");
    run.case("syntax/func_param_group.do");
    run.case("syntax/indentation.do");
    run.case("syntax/last_line_empty_indent.do");
    run.case("syntax/no_stmts.do");
    run.case("syntax/parse_end_error.do");
    run.case("syntax/parse_middle_error.do");
    run.case("syntax/parse_skip_shebang_error.do");
    run.case("syntax/parse_skip_shebang_panic.do");
    run.case("syntax/parse_start_error.do");
    run.case("syntax/skip_utf8_bom.do");
    run.case("syntax/stmt_end_error.do");
    run.case("syntax/tabs_spaces_error.do");
    run.case("syntax/tuple_field_group.do");
    run.case("syntax/type_decl_eof.do");
    run.case("syntax/type_missing_colon_error.do");
    run.case("syntax/visibility.do");
    run.case("syntax/wrap_stmts.do");
}

fn test_functions(run: *Runner) void {
    run.case("functions/assign_capture_local_error.do");
    run.case("functions/assign_error.do");
    run.case("functions/call_at_ct.do");
    run.case("functions/call_at_ct_error.do");
    run.case("functions/call_block.do");
    run.case("functions/call_incompat_param_error.do");
    run.case("functions/call_closure.do");
    run.case("functions/call_closure_param_error.do");
    run.case("functions/call_excess_args_error.do");
    run.case("functions/call_excess_args_overloaded_error.do");
    run.case("functions/call_overload_incompat_arg_error.do");
    run.case("functions/call_float_param_error.do");
    run.case("functions/call_method_missing_error.do");
    run.case("functions/call_method_sig_error.do");
    run.case("functions/call_host.do");
    run.case("functions/call_host_param_error.do");
    run.case("functions/call_op.do");
    run.case("functions/call_recursive.do");
    run.case("functions/call_static_lambda_incompat_arg_error.do");
    run.case("functions/call_struct_param.do");
    run.case("functions/call_struct_param_error.do");
    run.case("functions/call_template_method_error.do");
    run.case("functions/call_typed_param.do");
    run.case("functions/call_undeclared_error.do");
    run.case("functions/call_missing_assignment_error.do");
    run.case("functions/decl_over_builtin.do");
    run.case("functions/funcsym_type.do");
    run.case("functions/func_type.do");
    run.case("functions/func_type_closure_error.do");
    run.case("functions/func_type_error.do");
    run.case("functions/func_union_type.do");
    run.case("functions/func_union_type_error.do");
    if (test_config.test_backend == .vm) {
        run.case("functions/jit_func.do");
    }
    run.case("functions/lambda.do");
    run.case("functions/lambda_incompat_arg_error.do");
    run.case("functions/main_func_overload_error.do");
    run.case("functions/main_func_panic.do");
    run.case("functions/main_func_sig_error.do");
    run.case("functions/main_func_top_stmt_error.do");
    run.case("functions/@init.do");
    run.case("functions/overload.do");
    run.case("functions/read_capture_local_error.do");
    run.case("functions/capture_non_ref_error.do");
    run.case("functions/static.do");
    run.case("functions/struct_funcs.do");
    run.case("functions/template_functions.do");
    run.case("functions/template_method_error.do");
    // run.case("functions/void_param_error.do");
}

fn test_memory(run: *Runner) void {
    run.case("memory/arc_cases.do");
    run.case("memory/borrow.do");
    run.case("memory/borrow_index_addr_error.do");
    run.case("memory/call_with_ref_local.do");
    run.case("memory/call_with_ref_rvalue.do");
    run.case("memory/custom_deinit.do");
    if (!is_wasm) {
        // run.case("memory/default_memory.do");
    }
    // run.case("memory/gc_reference_cycle_unreachable.do");
    // run.case2(.{ .cleanupGC = true }, "memory/gc_reference_cycle_reachable.do");
    run.case("memory/release_expr_stmt_return.do");
    run.case("memory/release_scope_end.do");
    run.case("memory/lift_borrow_error.do");
    run.case("memory/lift_borrow_container_error.do");
    run.case("memory/lift_moves_rvalue.do");
    run.case("memory/move_local_to_return.do");
    run.case("memory/move_use_after_error.do");
    run.case("memory/override_copy.do");
    run.case("memory/partial_move.do");
    run.case("memory/partial_move_use_after_error.do");
    run.case("memory/partial_move_ref_child_error.do");
    run.case("memory/return_moves_rvalue.do");
    run.case("memory/return_borrow_scope_missing_error.do");
    run.case("memory/return_borrow_container_scope_missing_error.do");
    run.case("memory/scope_param_missing_error.do");
    run.case("memory/scope_too_many_params_error.do");
    run.case("memory/scope_return_error.do");
    run.case("memory/scope_return.do");
    run.case("memory/scope_assign_shorter_span_lifetime_error.do");
    run.case("memory/scope_assign_shorter_borrow_lifetime_error.do");
    run.case("memory/sink_use_rec_after_error.do");
    run.case("memory/sink_use_arg_after_error.do");
}

fn test_types(run: *Runner) void {
    run.case("types/bitcast.do");
    run.case("types/cast.do");
    run.case("types/cast_error.do");
    // // Failed to cast to abstract type at runtime.
    // try eval(.{ .silent = true },
    //     \\let a = 123
    //     \\print(a as string)
    // , struct { fn func(run: *VMrunner, res: EvalResult) !void {
    //     try run.expectErrorReport(res, error.Panic,
    //         \\panic: Can not cast `int` to `string`.
    //         \\
    //         \\main:2:9 main:
    //         \\print(a as string)
    //         \\        ^
    //         \\
    //     );
    // }}.func);
    run.case("types/choice_access_error.do");
    run.case("types/choice_type.do");
    run.case("types/choice_unwrap_panic.do");
    run.case("types/cstructs.do");
    run.case("types/enums.do");
    run.case("types/func_return_type_error.do");
    run.case("types/func_param_type_undeclared_error.do");
    run.case("types/method_implicit_self_assign_error.do");
    run.case("types/method_shadow_member.do");
    run.case("types/objects.do");
    run.case("types/object_downcast_panic.do");
    run.case("types/object_init_object_field.do");
    run.case("types/object_init_field.do");
    run.case("types/object_init_field_error.do");
    run.case("types/object_set_field.do");
    run.case("types/object_set_field_error.do");
    run.case("types/pointers.do");
    run.case("types/PtrSpan.do");
    run.case("types/Self.do");
    run.case("types/struct_circular_dep_error.do");
    run.case("types/structs.do");
    run.case("types/struct_default_initializer.do");
    run.case("types/struct_init_undeclared_field_error.do");
    run.case("types/struct_set_undeclared_field_error.do");
    run.case("types/struct_require_field_error.do");
    run.case("types/struct_nested.do");
    run.case("types/template_choices.do");
    run.case("types/template_dep_param_type.do");
    run.case("types/template_dep_param_type_error.do");
    run.case("types/template_object_init_noexpand_error.do");
    run.case("types/template_object_spec_noexpand_error.do");
    run.case("types/template_object_expand_error.do");
    run.case("types/template_structs.do");
    run.case("types/trait_error.do");
    run.case("types/trait.do");
    run.case("types/tuple.do");
    run.case("types/type_alias.do");
    run.case("types/type_alias_path_decl_error.do");
    run.case("types/type_embedding.do");
    run.case("types/type_spec.do");
    run.case("types/void.do");
}

fn test_modules(run: *Runner) void {
    const backend = setup.fromTestBackend(test_config.test_backend);
    const aot = isAot(backend);
    if (!is_wasm) {
        run.case("modules/type_spec.do");
        run.case("modules/type_alias.do");
        run.case("modules/import_not_found_error.do");
        run.case("modules/import_missing_sym_error.do");
        run.case("modules/import_rel_path.do");
        run.case("modules/import_implied_rel_path.do");
        run.case("modules/import_stmt_error.do");
        run.case("modules/import_unresolved_rel_path.do");

        // Import when running main script in the cwd.
        run.case2(Config.init("./import_rel_path.do").withChdir("./src/test/modules"));
        // Import when running main script in a child directory.
        run.case2(Config.init("../import_rel_path.do").withChdir("./src/test/modules/test_mods"));

        run.case("modules/import.do");
        run.case("modules/import_all.do");
        run.case("modules/import_sym_alias.do");
    }
    run.case("modules/core.do");
    if (!aot) {
        run.case("modules/cy.do");
    }

    run.case("modules/math.do");
    run.case("modules/meta.do");
    run.case("modules/test_eq_panic.do");
    run.case("modules/test.do");
    if (!is_wasm and build_config.ffi) {
        if (builtin.os.tag != .windows) {
            run.case("modules/libc.do");
        }
        if (builtin.abi != .msvc) {
            run.case("modules/os.do");
        }
        // run.case("modules/io.do");
    }
}

fn test_meta(run: *Runner) void {
    // Disabled test: printing to stdout hangs test runner.
    // run.case2(.{ .silent = true }, "meta/dump_locals.do");
    run.case("meta/ct_if.do");
    run.case("meta/get_panic.do");
    run.case("meta/get_set.do");
    run.case("meta/init_record.do");
    run.case("meta/init_record_error.do");
    run.case("meta/set_panic.do");
    run.case("meta/type.do");
}

fn test_concurrency(run: *Runner) void {
    const backend = setup.fromTestBackend(test_config.test_backend);
    const aot = isAot(backend);
    if (!aot) {
        run.case("concurrency/await.do");
        run.case("concurrency/generator.do");
        if (!is_wasm) {
            run.case("concurrency/spawn.do");
        }
    }
}

fn test_core(run: *Runner) void {
    run.case("core/Array.do");
    run.case("core/Array_oob_panic.do");
    run.case("core/Array_neg_oob_panic.do");
    run.case("core/arithmetic_ops.do");
    run.case("core/arithmetic_unsupported_error.do");
    run.case("core/bool.do");
    run.case("core/byte.do");
    run.case("core/compare_eq.do");
    run.case("core/compare_neq.do");
    run.case("core/error_values.do");
    run.case("core/escape_sequences.do");
    run.case("core/floats.do");
    run.case("core/ints.do");
    run.case("core/int_unsupported_notation_error.do");
    run.case("core/logic_ops.do");
    run.case("core/map_index_panic.do");
    run.case("core/Map.do");
    run.case("core/op_precedence.do");
    run.case("core/optionals_incompat_value_error.do");
    run.case("core/optionals_unwrap_panic.do");
    run.case("core/Option.do");
    run.case("core/option_unwrap_block_reachable_error.do");
    run.case("core/panic_panic.do");
    run.case("core/PartialVector.do");
    run.case("core/raw_string_single_quote_error.do");
    run.case("core/raw_string_new_line_error.do");
    run.case("core/Result.do");
    run.case("core/result_unwrap_block_reachable_error.do");
    run.case("core/result_infer_return.do");
    run.case("core/rune_empty_lit_error.do");
    run.case("core/rune_multiple_lit_error.do");
    run.case("core/rune_grapheme_cluster_lit_error.do");
    run.case("core/set_index_unsupported_error.do");
    run.case("core/Slice.do");
    run.case("core/Slice_oob_panic.do");
    run.case("core/Slice_neg_oob_panic.do");
    run.case("core/str_new_line_error.do");
    run.case("core/str_interpolation.do");
    run.case("core/str_runeAt_neg_oob_panic.do");
    run.case("core/str_runeAt_oob_panic.do");
    run.case("core/str_index_neg_oob_panic.do");
    run.case("core/str_index_oob_panic.do");
    run.case("core/strings.do");
    run.case("core/strings_ascii.do");
    run.case("core/strings_utf8.do");
    run.case("core/symbols.do");
    // run.case("core/table.do");
    // run.case("core/table_access_panic.do");
    run.case("core/Vector.do");
    run.case("core/Vector_neg_oob_panic.do");
    run.case("core/Vector_oob_panic.do");
    run.case("core/wyhash.do");
}

fn test_vars(run: *Runner) void {
    run.case("vars/const.do");
    run.case("vars/const_init_rtval_error.do");
    run.case("vars/const_init_ctval_error.do");
    run.case("vars/const_write_error.do");
    run.case("vars/local_assign_error.do");
    run.case("vars/local_assign.do");
    run.case("vars/local_attr_error.do");
    run.case("vars/local_dup_error.do");
    run.case("vars/local_init.do");
    run.case("vars/local_shadow.do");
    run.case("vars/local_no_shadow_for_capture.do");
    run.case("vars/op_assign.do");
    run.case("vars/read_undeclared_error.do");
    run.case("vars/read_undeclared_diff_scope_error.do");
    run.case("vars/read_outside_if_var_error.do");
    run.case("vars/read_outside_for_iter_error.do");
    run.case("vars/read_outside_for_var_error.do");
    run.case("vars/set_undeclared_error.do");
    run.case("vars/global_assign.do");
    run.case("vars/global_init.do");
    // run.case("vars/global_init_call_error.do");
    run.case("vars/global_init_capture_error.do");
    run.case("vars/global_init_ref_error.do");
    run.case("vars/global_init_type_error.do");
}

fn test_control_flow(run: *Runner) void {
    run.case("control_flow/for_iter.do");
    run.case("control_flow/for_iter_unsupported_error.do");
    run.case("control_flow/for_range.do");
    run.case("control_flow/if_expr.do");
    run.case("control_flow/if_expr_error.do");
    run.case("control_flow/if_stmt.do");
    run.case("control_flow/if_unwrap.do");
    run.case("control_flow/return.do");
    run.case("control_flow/switch.do");
    run.case("control_flow/switch_error.do");
    run.case("control_flow/switch_choice_else_error.do");
    run.case("control_flow/switch_choice_dup_case_error.do");
    run.case("control_flow/switch_choice_unhandled_error.do");
    run.case("control_flow/try_error.do");
    run.case("control_flow/try.do");
    run.case("control_flow/try_panic.do");
    run.case("control_flow/unreachable.do");
    // run.case("control_flow/unreachable_error.do");
    run.case("control_flow/while_cond.do");
    run.case("control_flow/while_inf.do");
    run.case("control_flow/while_unwrap.do");
}

// TODO: This could be split into compiler only tests and backend tests.
//       Compiler tests would only need to be run once.
//       Right now we just run everything again since it's not that much.
test "Tests." {
    var run = Runner{ .cases = .empty };
    defer run.cases.deinit(t.alloc);

    test_syntax(&run);
    test_functions(&run);
    test_memory(&run);
    test_types(&run);
    test_modules(&run);
    test_meta(&run);
    test_concurrency(&run);
    test_core(&run);
    test_vars(&run);
    test_control_flow(&run);

    run.case("../tokenizer.do");

    var numPassed: u32 = 0;
    var skipped: u32 = 0;
    defer std.debug.print("Tests passed: {}/{}, skipped: {}\n", .{ numPassed, run.cases.items.len, skipped });
    for (run.cases.items) |run_case| {
        if (caseFilter) |filter| {
            if (std.mem.indexOf(u8, run_case.config.uri, filter) == null) {
                continue;
            }
        }
        std.debug.print("test: {s}\n", .{run_case.config.uri});

        if (run_case.skip) {
            skipped += 1;
            continue;
        }

        errdefer std.debug.print("failed test: {s}\n", .{run_case.config.uri});
        case2(run_case.config) catch |err| {
            std.debug.print("Failed: {}\n", .{err});
            if (failFast) {
                return err;
            } else {
                continue;
            }
        };
        numPassed += 1;
    }
    if (numPassed < run.cases.items.len) {
        return error.Failed;
    }
}

test "Compile." {
    // examples.
    // try compileCase(.{}, "../examples/fiber.do");
    try compileCase("../examples/fizzbuzz.do");
    try compileCase("../examples/hello.do");
    if (!is_wasm and build_config.ffi) {
        try compileCase("../examples/ffi.do");
    }
    try compileCase("../examples/account.do");
    try compileCase("../examples/fibonacci.do");

    // tools.
    try compileCase("tools/bench.do");
    if (!is_wasm) {
        // TODO: Temporary skipping these tests because they involve ffi binding. However, compilation shouldn't involve any binding.
        try compileCase("tools/clang_bs.do");
        try compileCase("tools/md4c.do");
        try compileCase("tools/cbindgen.do");
        try compileCase("../docs/gen-docs.do");
    }

    // benchmarks.
    try compileCase("test/bench/fib/fib.do");
    // try compileCase("test/bench/fiber/fiber.do"); TODO: Re-enable.
    try compileCase("test/bench/for/for.do");
    // try compileCase("test/bench/heap/heap.do"); TODO: Re-enable
    try compileCase("test/bench/string/index.do");
}

fn compileCase(path: []const u8) !void {
    std.debug.print("test: {s}\n", .{path});
    const fpath = try std.mem.concat(t.alloc, u8, &.{ "src/", path });
    defer t.alloc.free(fpath);
    try compile(.{ .uri = fpath, .silent = false }, null);
}

test "FFI." {
    if (is_wasm or builtin.abi == .msvc or !build_config.ffi) {
        return;
    }

    // TODO: Test callback failure and verify stack trace.
    // Currently, the VM aborts when encountering a callback error.
    // A config could be added to make the initial FFI call detect an error and throw a panic instead.

    try case("ffi/ffi.do");
}

test "windows new lines" {
    try eval(.{ .silent = true }, "a = 123\r\nb = 234\r\nc =", struct {
        fn func(run: *VMrunner, res: EvalResult) !void {
            try run.expectErrorReport(res, c.ErrorCompile,
                \\ParseError: Expected right expression for assignment statement.
                \\
                \\@MainPath():3:4:
                \\c =
                \\   ^
                \\
            );
        }
    }.func);
}

// test "Function named parameters call." {
//     const run = VMrunner.create();
//     defer run.destroy();

//     var val = try run.eval(
//         \\func foo(a, b):
//         \\  return a - b
//         \\foo(a: 3, b: 1)
//     );
//     try t.eq(val.asF64toI32(), 2);
//     run.deinitValue(val);

//     val = try run.eval(
//         \\func foo(a, b):
//         \\  return a - b
//         \\foo(a: 1, b: 3)
//     );
//     try t.eq(val.asF64toI32(), -2);
//     run.deinitValue(val);

//     // New line as arg separation.
//     val = try run.eval(
//         \\func foo(a, b):
//         \\  return a - b
//         \\foo(
//         \\  a: 3
//         \\  b: 1
//         \\)
//     );
//     try t.eq(val.asF64toI32(), 2);
//     run.deinitValue(val);
// }

// test "@name" {
//     const run = VMrunner.create();
//     defer run.destroy();

//     const parse_res = try run.parse(
//         \\@name foo
//     );
//     try t.eqStr(parse_res.name, "foo");

//     if (build_options.cyEngine == .qjs) {
//         // Compile step skips the statement.
//         const compile_res = try run.compile(
//             \\@name foo
//         );
//         try t.eqStr(compile_res.output, "(function () {});");
//     }
// }

fn case(path: []const u8) !void {
    try case2(Config.init(path));
}

fn seekCommentEnd(str: []const u8, start: usize) usize {
    var idx = start;
    while (true) {
        if (str[idx..].len >= 3 and str[idx] == '\n' and str[idx + 1] == '-' and str[idx + 2] == '-') {
            idx += 1;
            if (std.mem.indexOfScalarPos(u8, str, idx, '\n')) |nl| {
                idx = nl;
            } else {
                idx = str.len;
            }
        } else {
            break;
        }
    }
    return idx;
}

extern "c" fn fseek(stream: ?*std.c.FILE, offset: c_long, whence: c_int) c_int;
extern "c" fn ftell(stream: ?*std.c.FILE) c_long;

fn case2(config: Config) !void {
    var contents: []u8 = undefined;
    var final_path: []const u8 = undefined;
    if (config.chdir) |chdir| {
        const path = try std.fmt.allocPrint(t.alloc, "{s}/{s}", .{ chdir, config.uri });
        defer t.alloc.free(path);
        const path_z = try t.alloc.dupeZ(u8, path);
        defer t.alloc.free(path_z);
        const f = std.c.fopen(path_z.ptr, "rb") orelse return error.FileNotFound;
        defer _ = std.c.fclose(f);
        _ = fseek(f, 0, 2);
        const sz = ftell(f);
        _ = fseek(f, 0, 0);
        contents = try t.alloc.alloc(u8, @intCast(sz));
        _ = std.c.fread(contents.ptr, 1, contents.len, f);
        final_path = try t.alloc.dupe(u8, config.uri);
    } else {
        final_path = try std.mem.concat(t.alloc, u8, &.{ "src/test/", config.uri });
        const path_z = try t.alloc.dupeZ(u8, final_path);
        defer t.alloc.free(path_z);
        const f = std.c.fopen(path_z.ptr, "rb") orelse return error.FileNotFound;
        defer _ = std.c.fclose(f);
        _ = fseek(f, 0, 2);
        const sz = ftell(f);
        _ = fseek(f, 0, 0);
        contents = try t.alloc.alloc(u8, @intCast(sz));
        _ = std.c.fread(contents.ptr, 1, contents.len, f);
    }
    defer t.alloc.free(final_path);
    defer t.alloc.free(contents);

    var idx = std.mem.indexOf(u8, contents, "cytest:") orelse {
        return error.MissingTestDefinition;
    };

    var rest = contents[idx + 7 ..];
    idx = std.mem.indexOfScalar(u8, rest, '\n') orelse rest.len;
    const test_t = std.mem.trim(u8, rest[0..idx], " ");

    if (std.mem.eql(u8, test_t, "error")) {
        const start = idx + 1;
        const end = seekCommentEnd(rest, idx);
        const exp = rest[start..end];

        var buf: [1024]u8 = undefined;
        const len = std.mem.replacementSize(u8, exp, "--", "");
        _ = std.mem.replace(u8, exp, "--", "", &buf);

        const Context = struct {
            exp: []const u8,
        };
        var ctx = Context{ .exp = buf[0..len] };
        var fconfig: Config = config;
        fconfig.uri = final_path;
        fconfig.silent = true;
        fconfig.ctx = &ctx;
        try eval(fconfig, null, struct {
            fn func(run: *VMrunner, res: EvalResult) !void {
                const ctx_: *Context = @ptrCast(@alignCast(run.ctx));
                try run.expectErrorReport2(res, ctx_.exp, false);
            }
        }.func);
    } else if (std.mem.eql(u8, test_t, "panic")) {
        const start = idx;
        var buf: [1024]u8 = undefined;
        const len = std.mem.replacementSize(u8, rest[start..], "\n--", "\n");
        _ = std.mem.replace(u8, rest[start..], "\n--", "\n", &buf);
        const cur = buf[0..len];
        _ = cur;

        var exp_str: []const u8 = undefined;
        const backend = setup.fromTestBackend(test_config.test_backend);
        const aot = isAot(backend);

        const trace_idx = std.mem.indexOf(u8, buf[0..len], "[trace]") orelse {
            return error.MissingExpectedTrace;
        };
        if (!aot) {
            const starts_with = buf[1..trace_idx];
            const ends_with = buf[trace_idx + 8 .. len];
            const Context2 = struct {
                exp_start: []const u8,
                exp_end: []const u8,
            };
            var ctx = Context2{ .exp_start = starts_with, .exp_end = ends_with };
            var fconfig: Config = config;
            fconfig.uri = final_path;
            fconfig.ctx = &ctx;
            try eval(fconfig, null, struct {
                fn func(run: *VMrunner, res: EvalResult) !void {
                    const ctx_: *Context2 = @ptrCast(@alignCast(run.ctx));
                    try run.expectErrorReport3(res, ctx_.exp_start, ctx_.exp_end);
                }
            }.func);
            return;
        } else {
            exp_str = buf[1 .. trace_idx - 1];
        }

        const Context = struct {
            exp: []const u8,
        };
        var ctx = Context{ .exp = exp_str };
        var fconfig: Config = config;
        fconfig.uri = final_path;
        fconfig.silent = true;
        fconfig.ctx = &ctx;
        try eval(fconfig, null, struct {
            fn func(run: *VMrunner, res: EvalResult) !void {
                const ctx_: *Context = @ptrCast(@alignCast(run.ctx));
                const backend_ = setup.fromTestBackend(test_config.test_backend);
                const aot_ = isAot(backend_);
                try run.expectErrorReport2(res, ctx_.exp, aot_);
            }
        }.func);
    } else if (std.mem.eql(u8, test_t, "pass")) {
        var fconfig: Config = config;
        fconfig.silent = false;
        fconfig.uri = final_path;
        try evalPass(fconfig, null);
    } else {
        return error.UnsupportedTestType;
    }
}
