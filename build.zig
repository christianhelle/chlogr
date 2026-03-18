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

    // P0 and P1 test suites
    const test_allocator_exe = b.addExecutable(.{
        .name = "test-allocator-failures",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test_allocator_failures.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const test_allocator_run = b.addRunArtifact(test_allocator_exe);
    const test_allocator_step = b.step("test-allocator", "Run allocator failure tests (Issue #3)");
    test_allocator_step.dependOn(&test_allocator_run.step);

    const test_token_exe = b.addExecutable(.{
        .name = "test-token-resolver",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test_token_resolver.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const test_token_run = b.addRunArtifact(test_token_exe);
    const test_token_step = b.step("test-token", "Run token resolver tests (Issue #4)");
    test_token_step.dependOn(&test_token_run.step);

    const test_pagination_exe = b.addExecutable(.{
        .name = "test-pagination",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test_pagination.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const test_pagination_run = b.addRunArtifact(test_pagination_exe);
    const test_pagination_step = b.step("test-pagination", "Run pagination tests (Issue #7)");
    test_pagination_step.dependOn(&test_pagination_run.step);

    const test_labels_exe = b.addExecutable(.{
        .name = "test-label-exclusion",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test_label_exclusion.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const test_labels_run = b.addRunArtifact(test_labels_exe);
    const test_labels_step = b.step("test-labels", "Run label exclusion tests (Issue #9)");
    test_labels_step.dependOn(&test_labels_run.step);

    const test_timestamps_exe = b.addExecutable(.{
        .name = "test-timestamp-comparison",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test_timestamp_comparison.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const test_timestamps_run = b.addRunArtifact(test_timestamps_exe);
    const test_timestamps_step = b.step("test-timestamps", "Run timestamp comparison tests (Issue #5)");
    test_timestamps_step.dependOn(&test_timestamps_run.step);

    // Run all P0/P1 tests
    const test_all_step = b.step("test-all", "Run all tests including P0/P1 test suites");
    test_all_step.dependOn(&test_run.step);
    test_all_step.dependOn(&test_allocator_run.step);
    test_all_step.dependOn(&test_token_run.step);
    test_all_step.dependOn(&test_pagination_run.step);
    test_all_step.dependOn(&test_labels_run.step);
    test_all_step.dependOn(&test_timestamps_run.step);
}
