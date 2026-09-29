// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

const NixMaster = @This();

const std = @import("std");

const NixRelease = @import("NixRelease.zig");

releases: std.StringArrayHashMapUnmanaged(NixRelease) = .empty,

pub fn jsonParse(alloc: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !NixMaster {
    const parsed = try std.json.innerParse(std.json.Value, alloc, source, options);
    return NixMaster.jsonParseFromValue(alloc, parsed, options);
}

pub fn jsonParseFromValue(alloc: std.mem.Allocator, source: std.json.Value, options: std.json.ParseOptions) !NixMaster {
    if (source != .object) return error.UnexpectedToken;

    var tmp: NixMaster = .{};

    var it = source.object.iterator();
    while (it.next()) |kv| {
        const key = kv.key_ptr.*;
        const value = kv.value_ptr.*;
        if (!std.mem.eql(u8, "latest", key) and !isValidDate(key)) {
            return error.UnexpectedToken;
        }
        if (value != .object) return error.UnexpectedToken;
        const release = try NixRelease.jsonParseFromValue(alloc, value, options);
        const result = try tmp.releases.getOrPut(alloc, key);
        result.value_ptr.* = release;
    }

    return tmp;
}

pub fn jsonStringify(self: NixMaster, jws: anytype) !void {
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

test "zig master 1" {
    const data =
        \\{
        \\  "2021-02-13": {
        \\    "x86_64-linux": {
        \\      "url": "https://ziglang.org/builds/zig-linux-x86_64-0.8.0-dev.1140+9270aae07.tar.xz",
        \\      "version": "0.8.0-dev.1140+9270aae07",
        \\      "sha256": "b86aea4d977e3e42f3b226ca3a4618c964fd6e03d1bbddbcae78f369f1facf0e"
        \\    },
        \\    "aarch64-linux": {
        \\      "url": "https://ziglang.org/builds/zig-linux-aarch64-0.8.0-dev.1140+9270aae07.tar.xz",
        \\      "version": "0.8.0-dev.1140+9270aae07",
        \\      "sha256": "5508020c075bc4c90bbcecb9f9f1f6d6ecded00e592ae337a91004ae0d127543"
        \\    },
        \\    "x86_64-darwin": {
        \\      "url": "https://ziglang.org/builds/zig-macos-x86_64-0.8.0-dev.1140+9270aae07.tar.xz",
        \\      "version": "0.8.0-dev.1140+9270aae07",
        \\      "sha256": "0a526cf2b6d06c5c5b9331dc86c5fe85b250d799baecbb2725e6b5d42c107b3c"
        \\    }
        \\  },
        \\  "latest": {
        \\    "x86_64-linux": {
        \\      "url": "https://ziglang.org/builds/zig-linux-x86_64-0.8.0-dev.1141+68e772647.tar.xz",
        \\      "version": "0.8.0-dev.1141+68e772647",
        \\      "sha256": "0721a91fcc3f8f03f7a9557899bbd3c3a36351480704f0917f0a7648d03f738f"
        \\    },
        \\    "aarch64-linux": {
        \\      "url": "https://ziglang.org/builds/zig-linux-aarch64-0.8.0-dev.1141+68e772647.tar.xz",
        \\      "version": "0.8.0-dev.1141+68e772647",
        \\      "sha256": "1a68083132362744ebd1ac53e7366c712e3854ded0ea896df54227ebc3e34bb7"
        \\    },
        \\    "x86_64-darwin": {
        \\      "url": "https://ziglang.org/builds/zig-macos-x86_64-0.8.0-dev.1141+68e772647.tar.xz",
        \\      "version": "0.8.0-dev.1141+68e772647",
        \\      "sha256": "e2f8d208562f5a437dc9240c220588c9514a4d15af7c23135da09644b88cc2fe"
        \\    }
        \\  }
        \\}
    ;
    const parsed = try std.json.parseFromSlice(NixMaster, std.testing.allocator, data, .{});
    defer parsed.deinit();

    try std.testing.expectEqual(2, parsed.value.releases.count());

    {
        const release = parsed.value.releases.get("2021-02-13").?;

        {
            const artifact = release.artifacts.get("aarch64-linux").?;
            try std.testing.expectEqualStrings("https://ziglang.org/builds/zig-linux-aarch64-0.8.0-dev.1140+9270aae07.tar.xz", artifact.url.?);
            try std.testing.expectEqualStrings("0.8.0-dev.1140+9270aae07", artifact.version.?);
            try std.testing.expectEqualStrings("5508020c075bc4c90bbcecb9f9f1f6d6ecded00e592ae337a91004ae0d127543", artifact.sha256.?);
            try std.testing.expectEqual(false, artifact.broken);
        }
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
