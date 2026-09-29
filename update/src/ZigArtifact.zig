// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

const ZigArtifact = @This();
const std = @import("std");

tarball: []const u8,
shasum: []const u8,
size: u32,

pub fn deinit(self: *const ZigArtifact, alloc: std.mem.Allocator) void {
    alloc.free(self.tarball);
    alloc.free(self.shasum);
}

test "zig artifact 1" {
    const data =
        \\{
        \\  "tarball": "https://ziglang.org/download/0.15.1/zig-0.15.1.tar.xz",
        \\  "shasum": "816c0303ab313f59766ce2097658c9fff7fafd1504f61f80f9507cd11652865f",
        \\  "size": "21359884"
        \\}
    ;
    const parsed = try std.json.parseFromSlice(ZigArtifact, std.testing.allocator, data, .{});
    defer parsed.deinit();

    try std.testing.expectEqualStrings("https://ziglang.org/download/0.15.1/zig-0.15.1.tar.xz", parsed.value.tarball);
    try std.testing.expectEqualStrings("816c0303ab313f59766ce2097658c9fff7fafd1504f61f80f9507cd11652865f", parsed.value.shasum);
    try std.testing.expectEqual(21359884, parsed.value.size);
}
