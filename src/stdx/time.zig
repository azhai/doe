const std = @import("std");
const builtin = @import("builtin");

const time_wasm = @import("time_wasm.zig");
const IsWasm = builtin.target.cpu.arch.isWasm() and builtin.os.tag != .wasi;

extern "c" fn clock(clk_id: i32) i64;
const CLOCK_MONOTONIC: i32 = 1;

/// Simple monotonic timer using libc `clock` since `std.time.Timer` was removed in Zig 0.16.
pub const Timer = struct {
    start_ns: u64,

    pub fn start() !Timer {
        return .{ .start_ns = @intCast(clock(CLOCK_MONOTONIC) * std.time.ns_per_s) };
    }

    pub fn read(self: Timer) u64 {
        const now_ns: u64 = @intCast(clock(CLOCK_MONOTONIC) * std.time.ns_per_s);
        return now_ns - self.start_ns;
    }

    pub fn lap(self: *Timer) u64 {
        const now_ns: u64 = @intCast(clock(CLOCK_MONOTONIC) * std.time.ns_per_s);
        const lap_ns = now_ns - self.start_ns;
        self.start_ns = now_ns;
        return lap_ns;
    }
};

pub const Duration = struct {
    const Self = @This();

    ns: u64,

    pub fn initSecsF(secs: f32) Self {
        return .{
            .ns = @intFromFloat(secs * 1e9),
        };
    }

    pub fn toMillis(self: Self) u32 {
        return @intCast(self.ns / 1000000);
    }
};

pub fn getMilliTimestamp() i64 {
    if (IsWasm) {
        return time_wasm.getMilliTimestamp();
    } else {
        return clock(CLOCK_MONOTONIC) * 1000;
    }
}
