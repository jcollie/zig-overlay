// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

const ZigIndex = @This();

const std = @import("std");

pub const ZigRelease = @import("ZigRelease.zig");

releases: std.StringArrayHashMapUnmanaged(ZigRelease) = .empty,

pub fn jsonParse(alloc: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !ZigIndex {
    const parsed = try std.json.innerParse(std.json.Value, alloc, source, options);
    if (parsed != .object) return error.UnexpectedToken;

    var tmp: ZigIndex = .{};

    var it = parsed.object.iterator();
    while (it.next()) |kv| {
        const version = kv.key_ptr.*;
        const value = kv.value_ptr.*;

        if (value != .object) return error.UnexpectedToken;

        var release = try std.json.innerParseFromValue(ZigRelease, alloc, value, .{});
        errdefer release.deinit(alloc);

        const result = try tmp.releases.getOrPut(alloc, version);
        if (!result.found_existing) {
            result.key_ptr.* = try alloc.dupe(u8, version);
            result.value_ptr.* = release;
        } else {
            result.value_ptr.*.deinit(alloc);
            result.value_ptr.* = release;
        }
    }

    return tmp;
}

pub fn jsonStringify(self: ZigIndex, jws: anytype) !void {
    var it = self.releases.iterator();

    try jws.beginObject();
    while (it.next()) |kv| {
        if (std.mem.eql(u8, kv.key_ptr.*, "latest")) continue;
        try jws.objectField(kv.key_ptr.*);
        try jws.write(kv.value_ptr.*);
    }
    if (self.releases.get("latest")) |latest| {
        try jws.objectField("latest");
        try jws.write(latest);
    }
    try jws.endObject();
}

test "zig index 1" {
    const data =
        \\{
        \\  "0.15.1": {
        \\    "date": "2025-08-19",
        \\    "docs": "https://ziglang.org/documentation/0.15.1/",
        \\    "stdDocs": "https://ziglang.org/documentation/0.15.1/std/",
        \\    "notes": "https://ziglang.org/download/0.15.1/release-notes.html",
        \\    "src": {
        \\      "tarball": "https://ziglang.org/download/0.15.1/zig-0.15.1.tar.xz",
        \\      "shasum": "816c0303ab313f59766ce2097658c9fff7fafd1504f61f80f9507cd11652865f",
        \\      "size": "21359884"
        \\    },
        \\    "bootstrap": {
        \\      "tarball": "https://ziglang.org/download/0.15.1/zig-bootstrap-0.15.1.tar.xz",
        \\      "shasum": "4c0cfbcf12da144955761ca43f89e3c74956bce978694fc1d0a63555f5c0a199",
        \\      "size": "52711548"
        \\    }
        \\  }
        \\}
    ;

    var parsed = try std.json.parseFromSlice(ZigIndex, std.testing.allocator, data, .{});
    defer parsed.deinit();

    try std.testing.expectEqual(1, parsed.value.releases.count());
    const release = parsed.value.releases.get("0.15.1").?;
    try std.testing.expectEqualStrings("2025-08-19", release.date.?);
    try std.testing.expectEqualStrings("https://ziglang.org/documentation/0.15.1/", release.docs.?);
    try std.testing.expectEqualStrings("https://ziglang.org/documentation/0.15.1/std/", release.stdDocs.?);
    try std.testing.expectEqualStrings("https://ziglang.org/download/0.15.1/release-notes.html", release.notes.?);
    try std.testing.expectEqual(2, release.artifacts.count());
    {
        const artifact = release.artifacts.get("src").?;
        try std.testing.expectEqualStrings("https://ziglang.org/download/0.15.1/zig-0.15.1.tar.xz", artifact.tarball);
        try std.testing.expectEqualStrings("816c0303ab313f59766ce2097658c9fff7fafd1504f61f80f9507cd11652865f", artifact.shasum);
        try std.testing.expectEqual(21359884, artifact.size);
    }
    {
        const artifact = release.artifacts.get("bootstrap").?;
        try std.testing.expectEqualStrings("https://ziglang.org/download/0.15.1/zig-bootstrap-0.15.1.tar.xz", artifact.tarball);
        try std.testing.expectEqualStrings("4c0cfbcf12da144955761ca43f89e3c74956bce978694fc1d0a63555f5c0a199", artifact.shasum);
        try std.testing.expectEqual(52711548, artifact.size);
    }
}
