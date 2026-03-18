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
