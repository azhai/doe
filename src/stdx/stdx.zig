// Copied only what is used from the cosmic project.
// TODO: Remove this package.

const std = @import("std");

pub const testing = @import("testing.zig");

pub const time = @import("time.zig");
pub const heap = @import("heap.zig");

pub const stack = @import("ds/stack.zig");
pub const Stack = stack.Stack;

pub const debug = @import("debug.zig");

/// Simple spinlock-based mutex. Replacement for the removed `std.Thread.Mutex`.
pub const Mutex = struct {
    inner: std.atomic.Mutex = .unlocked,

    pub fn lock(m: *Mutex) void {
        while (!m.inner.tryLock()) {
            std.atomic.spinLoopHint();
        }
    }

    pub fn tryLock(m: *Mutex) bool {
        return m.inner.tryLock();
    }

    pub fn unlock(m: *Mutex) void {
        m.inner.unlock();
    }
};

/// Simple condition variable using a spin loop. Replacement for the removed `std.Thread.Condition`.
pub const Condition = struct {
    epoch: std.atomic.Value(u32) = .init(0),

    pub fn signal(c: *Condition) void {
        _ = c.epoch.fetchAdd(1, .release);
    }

    pub fn broadcast(c: *Condition) void {
        _ = c.epoch.fetchAdd(1, .release);
    }

    pub fn wait(c: *Condition, mutex: *Mutex) void {
        const old = c.epoch.load(.acquire);
        mutex.unlock();
        while (c.epoch.load(.acquire) == old) {
            std.Thread.yield() catch {};
        }
        mutex.lock();
    }
};
