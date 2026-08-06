const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "chlogr",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Integration test
    const test_exe = b.addExecutable(.{
        .name = "changelog-test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const test_run = b.addRunArtifact(test_exe);
    const test_step = b.step("test", "Run integration tests");
    test_step.dependOn(&test_run.step);

    // Unit tests for internal helpers (failing-allocator tests in github_api.zig)
    const unit_tests = b.addTest(.{
        .name = "unit-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/github_api.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    test_step.dependOn(&run_unit_tests.step);
}

fn getInstallPrefix(b: *std.Build) []const u8 {
    // Honor an explicit `--prefix` flag.
    const default_prefix = b.build_root.join(b.allocator, &.{"zig-out"}) catch @panic("OOM");
    if (!std.mem.eql(u8, b.install_prefix, default_prefix)) {
        return b.install_prefix;
    }

    // Honor the INSTALL_DIR environment variable used by the install scripts.
    if (b.graph.environ_map.get("INSTALL_DIR")) |install_dir| {
        if (install_dir.len > 0) return install_dir;
    }

    // Default to $HOME/.local/bin, falling back to %USERPROFILE% on Windows.
    if (b.graph.environ_map.get("HOME")) |home| {
        if (home.len > 0) return b.pathJoin(&.{ home, ".local", "bin" });
    }
    if (b.graph.environ_map.get("USERPROFILE")) |home| {
        if (home.len > 0) return b.pathJoin(&.{ home, ".local", "bin" });
    }

    @panic("unable to determine install directory: set HOME, USERPROFILE, or INSTALL_DIR");
}
