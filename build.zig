const std = @import("std");
const build_install = @import("src/build_install.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "chlogr",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            // Zig 0.16 only strips ReleaseSmall by default; strip release
            // builds so the released binaries don't embed DWARF debug info.
            .strip = switch (optimize) {
                .Debug, .ReleaseSafe => false,
                .ReleaseFast, .ReleaseSmall => true,
            },
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

    // Unit tests for build install directory resolution
    const install_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/build_install.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_install_tests = b.addRunArtifact(install_tests);
    test_step.dependOn(&run_install_tests.step);

    const release_exe = b.addExecutable(.{
        .name = "chlogr",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = .ReleaseSmall,
        }),
    });

    const install_release_step = b.step("install-release", "Build ReleaseSmall and install to ~/.local/bin (%USERPROFILE%/.local/bin on Windows)");
    const install_release = InstallReleaseStep.create(b, release_exe.getEmittedBin(), getInstallPrefix(b), release_exe.out_filename);
    install_release_step.dependOn(&install_release.step);
}

fn getInstallPrefix(b: *std.Build) []const u8 {
    const default_prefix = b.build_root.join(b.allocator, &.{"zig-out"}) catch @panic("OOM");
    return build_install.resolveInstallDir(b.allocator, b.install_prefix, default_prefix, &b.graph.environ_map, @import("builtin").os.tag);
}

const InstallReleaseStep = struct {
    step: std.Build.Step,
    source: std.Build.LazyPath,
    dest_dir: []const u8,
    dest_name: []const u8,

    fn create(
        b: *std.Build,
        source: std.Build.LazyPath,
        dest_dir: []const u8,
        dest_name: []const u8,
    ) *InstallReleaseStep {
        const self = b.allocator.create(InstallReleaseStep) catch @panic("OOM");
        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .custom,
                .name = b.fmt("install {s} to {s}", .{ dest_name, dest_dir }),
                .owner = b,
                .makeFn = make,
            }),
            .source = source.dupe(b),
            .dest_dir = b.dupePath(dest_dir),
            .dest_name = b.dupePath(dest_name),
        };
        source.addStepDependencies(&self.step);
        return self;
    }

    fn make(step: *std.Build.Step, options: std.Build.Step.MakeOptions) anyerror!void {
        _ = options;
        const b = step.owner;
        const self: *InstallReleaseStep = @fieldParentPtr("step", step);
        const dest_path = b.pathResolve(&.{ self.dest_dir, self.dest_name });
        const p = try step.installFile(self.source, dest_path);
        step.result_cached = p == .fresh;
    }
};
