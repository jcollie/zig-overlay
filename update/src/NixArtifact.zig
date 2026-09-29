// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

const NixArtifact = @This();
const std = @import("std");

url: ?[]const u8 = null,
version: ?[]const u8 = null,
sha256: ?[]const u8 = null,
broken: bool = false,

pub fn jsonParse(alloc: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !NixArtifact {
    const parsed = try std.json.innerParse(std.json.Value, alloc, source, options);
    return NixArtifact.jsonParseFromValue(alloc, parsed, options);
}

pub fn jsonParseFromValue(_: std.mem.Allocator, source: std.json.Value, _: std.json.ParseOptions) !NixArtifact {
    if (source != .object) return error.UnexpectedToken;

    var tmp: NixArtifact = .{};

    var it = source.object.iterator();
    while (it.next()) |kv| {
        const key = kv.key_ptr.*;
        const value = kv.value_ptr.*;

        if (std.mem.eql(u8, "url", key)) {
            if (value == .null) {
                tmp.url = null;
                continue;
            }
            if (value != .string) return error.UnexpectedToken;
            tmp.url = value.string;
            continue;
        }
        if (std.mem.eql(u8, "version", key)) {
            if (value == .null) {
                tmp.version = null;
                continue;
            }
            if (value != .string) return error.UnexpectedToken;
            _ = std.SemanticVersion.parse(value.string) catch return error.UnexpectedToken;
            tmp.version = value.string;
            continue;
        }
        if (std.mem.eql(u8, "sha256", key)) {
            if (value == .null) {
                tmp.sha256 = null;
                continue;
            }
            if (value != .string) return error.UnexpectedToken;
            tmp.sha256 = value.string;
            continue;
        }
        if (std.mem.eql(u8, "broken", key)) {
            if (value == .null) {
                tmp.broken = false;
                continue;
            }
            if (value != .bool) return error.UnexpectedToken;
            tmp.broken = value.bool;
            continue;
        }
        return error.UnexpectedToken;
    }

    return tmp;
}

pub fn jsonStringify(self: NixArtifact, jws: anytype) !void {
    try jws.beginObject();
    try jws.objectField("url");
    if (self.url) |url| try jws.write(url) else try jws.write(null);
    try jws.objectField("version");
    if (self.version) |version| try jws.write(version) else try jws.write(null);
    try jws.objectField("sha256");
    if (self.sha256) |sha256| try jws.write(sha256) else try jws.write(null);
    if (self.broken) {
        try jws.objectField("broken");
        try jws.write(true);
    }
    try jws.endObject();
}

test "nix artifact 1" {
    const data =
        \\{
        \\  "url": "https://ziglang.org/builds/zig-linux-x86_64-0.8.0-dev.1141+68e772647.tar.xz",
        \\  "version": "0.8.0-dev.1141+68e772647",
        \\  "sha256": "0721a91fcc3f8f03f7a9557899bbd3c3a36351480704f0917f0a7648d03f738f"
        \\}
    ;
    const parsed = try std.json.parseFromSlice(NixArtifact, std.testing.allocator, data, .{});
    defer parsed.deinit();

    try std.testing.expectEqualStrings("https://ziglang.org/builds/zig-linux-x86_64-0.8.0-dev.1141+68e772647.tar.xz", parsed.value.url.?);
    try std.testing.expectEqualStrings("0.8.0-dev.1141+68e772647", parsed.value.version.?);
    try std.testing.expectEqualStrings("0721a91fcc3f8f03f7a9557899bbd3c3a36351480704f0917f0a7648d03f738f", parsed.value.sha256.?);
    try std.testing.expectEqual(false, parsed.value.broken);
}

test "nix artifact 2" {
    const data =
        \\{
        \\  "url": "https://ziglang.org/builds/zig-linux-aarch64-0.11.0-dev.1314+9856bea34.tar.xz",
        \\  "sha256": null,
        \\  "version": "0.11.0-dev.1314+9856bea34",
        \\  "broken": true
        \\}
    ;
    const parsed = try std.json.parseFromSlice(NixArtifact, std.testing.allocator, data, .{});
    defer parsed.deinit();

    try std.testing.expectEqualStrings("https://ziglang.org/builds/zig-linux-aarch64-0.11.0-dev.1314+9856bea34.tar.xz", parsed.value.url.?);
    try std.testing.expectEqualStrings("0.11.0-dev.1314+9856bea34", parsed.value.version.?);
    try std.testing.expect(parsed.value.sha256 == null);
    try std.testing.expectEqual(true, parsed.value.broken);
}
