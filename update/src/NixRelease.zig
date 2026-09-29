// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

const NixRelease = @This();
const std = @import("std");

const NixArtifact = @import("NixArtifact.zig");

artifacts: std.StringArrayHashMapUnmanaged(NixArtifact) = .empty,

pub fn jsonParse(alloc: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !NixRelease {
    const parsed = try std.json.innerParse(std.json.Value, alloc, source, options);
    return NixRelease.jsonParseFromValue(alloc, parsed, options);
}

pub fn jsonParseFromValue(alloc: std.mem.Allocator, source: std.json.Value, options: std.json.ParseOptions) !NixRelease {
    if (source != .object) return error.UnexpectedToken;

    var tmp: NixRelease = .{};

    var it = source.object.iterator();
    while (it.next()) |kv| {
        const key = kv.key_ptr.*;
        const value = kv.value_ptr.*;
        if (value != .object) return error.UnexpectedToken;
        const artifact = try NixArtifact.jsonParseFromValue(alloc, value, options);
        const result = try tmp.artifacts.getOrPut(alloc, key);
        result.value_ptr.* = artifact;
    }

    return tmp;
}

pub fn jsonStringify(self: NixRelease, jws: anytype) !void {
    try jws.beginObject();
    var it = self.artifacts.iterator();
    while (it.next()) |kv| {
        try jws.objectField(kv.key_ptr.*);
        try jws.write(kv.value_ptr.*);
    }
    try jws.endObject();
}

test "zig release 2" {
    const data =
        \\{
        \\  "x86_64-darwin": {
        \\    "url": "https://ziglang.org/builds/zig-macos-x86_64-0.11.0-dev.1314+9856bea34.tar.xz",
        \\    "sha256": null,
        \\    "version": "0.11.0-dev.1314+9856bea34",
        \\    "broken": true
        \\  },
        \\  "aarch64-darwin": {
        \\    "url": "https://ziglang.org/builds/zig-macos-aarch64-0.11.0-dev.1314+9856bea34.tar.xz",
        \\    "sha256": null,
        \\    "version": "0.11.0-dev.1314+9856bea34",
        \\    "broken": true
        \\  },
        \\  "x86_64-linux": {
        \\    "url": "https://ziglang.org/builds/zig-linux-x86_64-0.11.0-dev.1314+9856bea34.tar.xz",
        \\    "sha256": null,
        \\    "version": "0.11.0-dev.1314+9856bea34",
        \\    "broken": true
        \\  },
        \\  "aarch64-linux": {
        \\    "url": "https://ziglang.org/builds/zig-linux-aarch64-0.11.0-dev.1314+9856bea34.tar.xz",
        \\    "sha256": null,
        \\    "version": "0.11.0-dev.1314+9856bea34",
        \\    "broken": true
        \\  },
        \\  "x86_64-windows": {
        \\    "url": "https://ziglang.org/builds/zig-windows-x86_64-0.11.0-dev.1314+9856bea34.zip",
        \\    "sha256": null,
        \\    "version": "0.11.0-dev.1314+9856bea34",
        \\    "broken": true
        \\  },
        \\  "aarch64-windows": {
        \\    "url": "https://ziglang.org/builds/zig-windows-aarch64-0.11.0-dev.1314+9856bea34.zip",
        \\    "sha256": null,
        \\    "version": "0.11.0-dev.1314+9856bea34",
        \\    "broken": true
        \\  }
        \\}
    ;
    const parsed = try std.json.parseFromSlice(NixRelease, std.testing.allocator, data, .{});
    defer parsed.deinit();

    try std.testing.expectEqual(6, parsed.value.artifacts.count());

    {
        const artifact = parsed.value.artifacts.get("x86_64-linux").?;
        try std.testing.expectEqualStrings("https://ziglang.org/builds/zig-linux-x86_64-0.11.0-dev.1314+9856bea34.tar.xz", artifact.url.?);
        try std.testing.expectEqualStrings("0.11.0-dev.1314+9856bea34", artifact.version.?);
        try std.testing.expect(artifact.sha256 == null);
        try std.testing.expectEqual(true, artifact.broken);
    }
}
