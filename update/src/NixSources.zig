// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

const NixSources = @This();

const std = @import("std");

const NixMaster = @import("NixMaster.zig");
const NixRelease = @import("NixRelease.zig");

master: NixMaster = .{},
releases: std.StringArrayHashMapUnmanaged(NixRelease) = .empty,

pub fn jsonParse(alloc: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !NixSources {
    const parsed = try std.json.innerParse(std.json.Value, alloc, source, options);
    return NixSources.jsonParseFromValue(alloc, parsed, options);
}

pub fn jsonParseFromValue(alloc: std.mem.Allocator, source: std.json.Value, options: std.json.ParseOptions) !NixSources {
    if (source != .object) return error.UnexpectedToken;

    var tmp: NixSources = .{};

    var it = source.object.iterator();
    while (it.next()) |kv| {
        const key = kv.key_ptr.*;
        const value = kv.value_ptr.*;
        if (std.mem.eql(u8, key, "master")) {
            if (value != .object) return error.UnexpectedToken;
            tmp.master = try NixMaster.jsonParseFromValue(alloc, value, options);
            continue;
        }
        _ = std.SemanticVersion.parse(key) catch {
            return error.UnexpectedToken;
        };
        if (value != .object) return error.UnexpectedToken;
        const release = try NixRelease.jsonParseFromValue(alloc, value, options);
        const result = try tmp.releases.getOrPut(alloc, key);
        result.value_ptr.* = release;
    }

    return tmp;
}

pub fn jsonStringify(self: NixSources, jws: anytype) !void {
    try jws.beginObject();
    try jws.objectField("master");
    try jws.write(self.master);

    var it = self.releases.iterator();
    while (it.next()) |kv| {
        try jws.objectField(kv.key_ptr.*);
        try jws.write(kv.value_ptr.*);
    }

    try jws.endObject();
}
