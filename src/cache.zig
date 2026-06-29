const std = @import("std");
const builtin = @import("builtin");
const stdx = @import("stdx");
const t = stdx.testing;
const platform = @import("platform.zig");
const cy = @import("cyber.zig");
const log = cy.log.scoped(.cache);

/// Loaded on demand.
/// Once loaded, common sub directories are assumed to exist.
var CyberPath: []const u8 = "";

const CyberDir = ".doe";
const EntriesDir = "entries";

extern "c" fn fseek(stream: ?*std.c.FILE, offset: c_long, whence: c_int) c_int;
extern "c" fn ftell(stream: ?*std.c.FILE) c_long;
extern "c" fn time(tloc: ?*c_long) c_long;
const fseek_ = fseek;
const ftell_ = ftell;
const SEEK_SET_: c_int = 0;
const SEEK_END_: c_int = 2;

fn nowTime() i64 {
    return @intCast(time(null));
}

fn ensureParentDir(file_path: []const u8) void {
    // Recursively mkdir -p the parent directory.
    if (std.fs.path.dirname(file_path)) |dir| {
        var iter = std.mem.tokenizeScalar(u8, dir, '/');
        var buf: [4096]u8 = undefined;
        var len: usize = 0;
        while (iter.next()) |part| {
            if (len + part.len + 2 > buf.len) return;
            buf[len] = '/';
            @memcpy(buf[len + 1 ..][0..part.len], part);
            len += 1 + part.len;
            const slice = buf[0..len];
            var z_buf: [4096]u8 = undefined;
            const z = std.fmt.bufPrintZ(&z_buf, "{s}", .{slice}) catch return;
            _ = std.c.mkdir(z, 0o755);
        }
    }
}

fn writeFile(file_path: []const u8, contents: []const u8) void {
    var path_buf: [4096]u8 = undefined;
    const path_z = std.fmt.bufPrintZ(&path_buf, "{s}", .{file_path}) catch return;
    const f = std.c.fopen(path_z.ptr, "wb") orelse return;
    defer _ = std.c.fclose(f);
    _ = std.c.fwrite(contents.ptr, 1, contents.len, f);
}

fn getCyberPath(alloc: std.mem.Allocator) ![]const u8 {
    const S = struct {
        var buf: [std.fs.max_path_bytes]u8 = undefined;
    };
    if (CyberPath.len == 0) {
        const homePath = (try platform.getPath(alloc, .home)) orelse return error.MissingHomeDir;
        defer alloc.free(homePath);
        std.mem.copyForwards(u8, &S.buf, homePath);
        S.buf[homePath.len] = std.fs.path.sep;
        std.mem.copyForwards(u8, S.buf[homePath.len + 1 .. homePath.len + 1 + CyberDir.len], CyberDir);
        CyberPath = S.buf[0 .. homePath.len + 1 + CyberDir.len];

        // Also ensure sub directories exist.
        var path_buf: [4096]u8 = undefined;
        // homePath/CyberDir
        const cyber_full = std.fmt.bufPrintZ(&path_buf, "{s}/{s}", .{ homePath, CyberDir }) catch unreachable;
        _ = std.c.mkdir(cyber_full, 0o755);
        // homePath/CyberDir/EntriesDir
        const entries_full = std.fmt.bufPrintZ(&path_buf, "{s}/{s}/{s}", .{ homePath, CyberDir, EntriesDir }) catch unreachable;
        _ = std.c.mkdir(entries_full, 0o755);
    }
    return CyberPath;
}

fn toCacheSpec(spec: []const u8) ![]const u8 {
    // Remove scheme part.
    if (std.mem.startsWith(u8, spec, "http://")) {
        return spec[7..];
    } else if (std.mem.startsWith(u8, spec, "https://")) {
        return spec[8..];
    } else {
        return error.UnsupportedScheme;
    }
}

pub fn saveNewSpecFile(alloc: std.mem.Allocator, specGroup: SpecHashGroup, spec: []const u8, contents: []const u8) !SpecEntry {
    const cacheSpec = try toCacheSpec(spec);
    const cyberPath = try getCyberPath(alloc);

    const now: u64 = @intCast(nowTime());

    const filePath = try std.fs.path.join(alloc, &.{ cyberPath, cacheSpec });
    defer alloc.free(filePath);

    // Ensure path exists.
    ensureParentDir(filePath);

    writeFile(filePath, contents);

    const new = SpecEntry{
        .spec = try alloc.dupe(u8, cacheSpec),
        .cacheDate = now,
    };

    const path = try std.fs.path.join(alloc, &.{ cyberPath, EntriesDir, &specGroup.hash });
    defer alloc.free(path);

    // Save spec entries.
    {
        var content_aw: std.Io.Writer.Allocating = .init(alloc);
        defer content_aw.deinit();
        for (specGroup.entries) |e| {
            if (e.removed) continue;
            try content_aw.writer.print("@{s}\n", .{e.spec});
            try content_aw.writer.print("cacheDate={}\n", .{e.cacheDate});
        }
        try content_aw.writer.print("@{s}\n", .{new.spec});
        try content_aw.writer.print("cacheDate={}\n", .{new.cacheDate});
        writeFile(path, content_aw.written());
    }
    return new;
}

/// Given absolute specifier, return the cached spec entries.
/// If the file does not exist, an empty slice is returned.
pub fn getSpecHashGroup(alloc: std.mem.Allocator, spec: []const u8) !SpecHashGroup {
    const cacheSpec = try toCacheSpec(spec);
    const hash = computeSpecHashStr(cacheSpec);
    const cyberPath = try getCyberPath(alloc);
    const path = try std.fs.path.join(alloc, &.{ cyberPath, EntriesDir, &hash });
    defer alloc.free(path);
    const entries = readEntryFile(alloc, path) catch |err| {
        switch (err) {
            error.FileNotFound => {
                return SpecHashGroup{
                    .hash = hash,
                    .entries = &.{},
                };
            },
            else => {
                return err;
            },
        }
    };
    return SpecHashGroup{
        .hash = hash,
        .entries = entries,
    };
}

fn readEntryFile(alloc: std.mem.Allocator, path: []const u8) ![]SpecEntry {
    // Read file via libc.
    var path_buf: [4096]u8 = undefined;
    const path_z = std.fmt.bufPrintZ(&path_buf, "{s}", .{path}) catch return error.PathTooLong;
    const f = std.c.fopen(path_z.ptr, "rb") orelse return error.FileNotFound;
    defer _ = std.c.fclose(f);
    _ = fseek_(f, 0, SEEK_END_);
    const size = ftell_(f);
    _ = fseek_(f, 0, SEEK_SET_);
    if (size < 0) return error.InvalidFile;
    const content = try alloc.alloc(u8, @intCast(size));
    defer alloc.free(content);
    _ = std.c.fread(content.ptr, 1, @intCast(size), f);

    var entries: std.ArrayListUnmanaged(SpecEntry) = .empty;
    defer entries.deinit(alloc);

    var iter = std.mem.tokenizeAny(u8, content, "\r\n");
    while (iter.next()) |line| {
        if (line.len > 0 and line[0] == '@') {
            const spec = try alloc.dupe(u8, line[1..]);
            const bodyLine = iter.next() orelse return error.InvalidEntryFile;
            var bodyIter = std.mem.splitScalar(u8, bodyLine, ',');
            var entry = SpecEntry{
                .spec = spec,
                .cacheDate = 0,
            };
            while (bodyIter.next()) |field| {
                const idx = std.mem.indexOfScalar(u8, field, '=') orelse return error.InvalidEntryFile;
                if (std.mem.eql(u8, field[0..idx], "cacheDate")) {
                    if (entry.cacheDate > 0) {
                        return error.InvalidEntryFile;
                    }
                    entry.cacheDate = try std.fmt.parseInt(u64, field[idx + 1 ..], 10);
                }
            }
            if (entry.cacheDate == 0) {
                return error.InvalidEntryFile;
            }
            try entries.append(alloc, entry);
        }
    }
    return entries.toOwnedSlice(alloc);
}

pub fn allocSpecFilePath(alloc: std.mem.Allocator, entry: SpecEntry) ![]const u8 {
    const cyberPath = try getCyberPath(alloc);
    return try std.fs.path.join(alloc, &.{ cyberPath, entry.spec });
}

pub fn allocSpecFileContents(alloc: std.mem.Allocator, entry: SpecEntry) ![]const u8 {
    const cyberPath = try getCyberPath(alloc);
    const path = try std.fs.path.join(alloc, &.{ cyberPath, entry.spec });
    defer alloc.free(path);
    var path_buf: [4096]u8 = undefined;
    const path_z = std.fmt.bufPrintZ(&path_buf, "{s}", .{path}) catch return error.PathTooLong;
    const f = std.c.fopen(path_z.ptr, "rb") orelse return error.FileNotFound;
    defer _ = std.c.fclose(f);
    _ = fseek_(f, 0, SEEK_END_);
    const size = ftell_(f);
    _ = fseek_(f, 0, SEEK_SET_);
    if (size < 0) return error.InvalidFile;
    const content = try alloc.alloc(u8, @intCast(size));
    _ = std.c.fread(content.ptr, 1, @intCast(size), f);
    return content;
}

fn computeSpecHashStr(spec: []const u8) [16]u8 {
    var res: [16]u8 = undefined;
    const hash = std.hash.Wyhash.hash(0, spec);
    _ = std.fmt.printInt(&res, hash, 16, .lower, .{ .width = 16, .fill = '0' });
    return res;
}

test "computeSpecHashStr" {
    // Formats 0 to entire width.
    var res: [16]u8 = undefined;
    _ = std.fmt.printInt(&res, 0, 16, .lower, .{ .width = 16, .fill = '0' });
    try std.testing.expectEqualStrings(&res, "0000000000000000");
}

const SpecEntry = struct {
    /// Specifier name. Does not include the scheme.
    spec: []const u8,

    /// Unix timestamp (seconds) of when the file was cached.
    cacheDate: u64,

    /// Whether the next save should skip this entry.
    removed: bool = false,

    pub fn deinit(self: *const SpecEntry, alloc: std.mem.Allocator) void {
        alloc.free(self.spec);
    }
};

const SpecHashGroup = struct {
    hash: [16]u8,
    entries: []SpecEntry,

    pub fn deinit(self: *const SpecHashGroup, alloc: std.mem.Allocator) void {
        for (self.entries) |e| {
            e.deinit(alloc);
        }
        alloc.free(self.entries);
    }

    pub fn markEntryBySpecForRemoval(self: *const SpecHashGroup, spec: []const u8) !void {
        const cacheSpec = try toCacheSpec(spec);
        for (self.entries) |*e| {
            if (std.mem.eql(u8, e.spec, cacheSpec)) {
                e.removed = true;
                break;
            }
        }
    }

    pub fn findEntryBySpec(self: *const SpecHashGroup, spec: []const u8) !?SpecEntry {
        const cacheSpec = try toCacheSpec(spec);
        for (self.entries) |e| {
            if (std.mem.eql(u8, e.spec, cacheSpec)) {
                return e;
            }
        }
        return null;
    }
};
