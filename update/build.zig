// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const datetime = b.dependency("datetime", .{
        .target = target,
        .optimize = optimize,
    });
    const zqlite = b.dependency("zqlite", .{
        .target = target,
        .optimize = optimize,
    });
    const http = b.dependency("http", .{
        .target = target,
        .optimize = optimize,
    });
    const uri = b.dependency("uri", .{
        .target = target,
        .optimize = optimize,
    });
    const dns_client = b.dependency("dns_client", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "zig-overlay-update",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{
                    .name = "datetime",
                    .module = datetime.module("datetime"),
                },
                .{
                    .name = "zqlite",
                    .module = zqlite.module("zqlite"),
                },
                .{
                    .name = "http_io",
                    .module = http.module("http_io"),
                },
                .{
                    .name = "uri",
                    .module = uri.module("uri"),
                },
                .{
                    .name = "dns_client",
                    .module = dns_client.module("dns_client"),
                },
            },
        }),
    });

    b.installArtifact(exe);
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    // run_cmd.addPassthruArgs();

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
