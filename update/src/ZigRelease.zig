// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

const ZigRelease = @This();

const std = @import("std");

const ZigArtifact = @import("ZigArtifact.zig");

version: ?[]const u8 = null,
date: ?[]const u8 = null,
docs: ?[]const u8 = null,
stdDocs: ?[]const u8 = null,
notes: ?[]const u8 = null,
artifacts: std.StringArrayHashMapUnmanaged(ZigArtifact) = .empty,

pub fn deinit(self: *ZigRelease, alloc: std.mem.Allocator) void {
    if (self.version) |v| alloc.free(v);
    if (self.date) |v| alloc.free(v);
    if (self.docs) |v| alloc.free(v);
    if (self.stdDocs) |v| alloc.free(v);
    if (self.notes) |v| alloc.free(v);
    var it = self.artifacts.iterator();
    while (it.next()) |kv| {
        kv.value_ptr.deinit(alloc);
        alloc.free(kv.key_ptr.*);
    }
    self.artifacts.deinit(alloc);
}

pub fn jsonParse(alloc: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !ZigRelease {
    const parsed = try std.json.innerParse(std.json.Value, alloc, source, options);
    return ZigRelease.jsonParseFromValue(alloc, parsed, options);
}

pub fn jsonParseFromValue(alloc: std.mem.Allocator, source: std.json.Value, options: std.json.ParseOptions) !ZigRelease {
    if (source != .object) return error.UnexpectedToken;

    var tmp: ZigRelease = .{};

    var it = source.object.iterator();
    while (it.next()) |kv| {
        const key = kv.key_ptr.*;
        const value = kv.value_ptr.*;
        if (std.mem.eql(u8, key, "version")) {
            if (value != .string) return error.UnexpectedToken;
            _ = std.SemanticVersion.parse(value.string) catch return error.UnexpectedToken;
            tmp.version = try alloc.dupe(u8, value.string);
            continue;
        }
        if (std.mem.eql(u8, key, "date")) {
            if (value != .string) return error.UnexpectedToken;
            if (!isValidDate(value.string)) return error.UnexpectedToken;
            tmp.date = try alloc.dupe(u8, value.string);
            continue;
        }
        if (std.mem.eql(u8, key, "docs")) {
            if (value != .string) return error.UnexpectedToken;
            tmp.docs = try alloc.dupe(u8, value.string);
            continue;
        }
        if (std.mem.eql(u8, key, "stdDocs")) {
            if (value != .string) return error.UnexpectedToken;
            tmp.stdDocs = try alloc.dupe(u8, value.string);
            continue;
        }
        if (std.mem.eql(u8, key, "notes")) {
            if (value != .string) return error.UnexpectedToken;
            tmp.notes = try alloc.dupe(u8, value.string);
            continue;
        }
        if (value != .object) return error.UnexpectedToken;
        const artifact = try std.json.innerParseFromValue(ZigArtifact, alloc, value, options);
        errdefer artifact.deinit(alloc);
        const result = try tmp.artifacts.getOrPut(alloc, key);
        if (!result.found_existing) {
            result.key_ptr.* = try alloc.dupe(u8, key);
            result.value_ptr.* = artifact;
        } else {
            alloc.free(artifact.tarball);
            alloc.free(artifact.shasum);
            result.value_ptr.* = artifact;
        }
    }

    return tmp;
}

pub fn jsonStringify(self: ZigRelease, jws: anytype) !void {
    try jws.beginObject();
    if (self.version) |version| {
        try jws.objectField("version");
        try jws.write(version);
    }
    if (self.date) |date| {
        try jws.objectField("date");
        try jws.write(date);
    }

    var it = self.artifacts.iterator();

    while (it.next()) |kv| {
        try jws.objectField(kv.key_ptr.*);
        try jws.write(kv.value_ptr.*);
    }
    try jws.endObject();
}

test "zig release 1" {
    const data =
        \\{
        \\  "date": "2025-08-19",
        \\  "docs": "https://ziglang.org/documentation/0.15.1/",
        \\  "stdDocs": "https://ziglang.org/documentation/0.15.1/std/",
        \\  "notes": "https://ziglang.org/download/0.15.1/release-notes.html",
        \\  "src": {
        \\    "tarball": "https://ziglang.org/download/0.15.1/zig-0.15.1.tar.xz",
        \\    "shasum": "816c0303ab313f59766ce2097658c9fff7fafd1504f61f80f9507cd11652865f",
        \\    "size": "21359884"
        \\  },
        \\  "bootstrap": {
        \\    "tarball": "https://ziglang.org/download/0.15.1/zig-bootstrap-0.15.1.tar.xz",
        \\    "shasum": "4c0cfbcf12da144955761ca43f89e3c74956bce978694fc1d0a63555f5c0a199",
        \\    "size": "52711548"
        \\  }
        \\}
    ;

    const parsed = try std.json.parseFromSlice(ZigRelease, std.testing.allocator, data, .{});
    defer parsed.deinit();

    try std.testing.expectEqualStrings("2025-08-19", parsed.value.date.?);
    try std.testing.expectEqualStrings("https://ziglang.org/documentation/0.15.1/", parsed.value.docs.?);
    try std.testing.expectEqualStrings("https://ziglang.org/documentation/0.15.1/std/", parsed.value.stdDocs.?);
    try std.testing.expectEqualStrings("https://ziglang.org/download/0.15.1/release-notes.html", parsed.value.notes.?);
    try std.testing.expectEqual(2, parsed.value.artifacts.count());
    {
        const v = parsed.value.artifacts.get("src").?;
        try std.testing.expectEqualStrings("https://ziglang.org/download/0.15.1/zig-0.15.1.tar.xz", v.tarball);
        try std.testing.expectEqualStrings("816c0303ab313f59766ce2097658c9fff7fafd1504f61f80f9507cd11652865f", v.shasum);
        try std.testing.expectEqual(21359884, v.size);
    }
    {
        const v = parsed.value.artifacts.get("bootstrap").?;
        try std.testing.expectEqualStrings("https://ziglang.org/download/0.15.1/zig-bootstrap-0.15.1.tar.xz", v.tarball);
        try std.testing.expectEqualStrings("4c0cfbcf12da144955761ca43f89e3c74956bce978694fc1d0a63555f5c0a199", v.shasum);
        try std.testing.expectEqual(52711548, v.size);
    }
}

fn isValidDate(str: []const u8) bool {
    if (str.len != 10) return false;
    if (str[4] != '-') return false;
    if (str[7] != '-') return false;
    if (std.mem.indexOfNone(u8, str[0..4], "0123456789")) |_| return false;
    if (std.mem.indexOfNone(u8, str[5..7], "0123456789")) |_| return false;
    if (std.mem.indexOfNone(u8, str[8..], "0123456789")) |_| return false;
    // TODO: check days per month
    return true;
}

test "is valid date" {
    try std.testing.expect(isValidDate("2026-02-23"));
    try std.testing.expect(!isValidDate("master"));
    try std.testing.expect(!isValidDate("2026102223"));
    try std.testing.expect(!isValidDate("a026-02-23"));
}
