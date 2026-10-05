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
            // Zig 0.16 only strips ReleaseSmall by default; strip release
            // builds so the released binaries don't embed DWARF debug info.
            .strip = switch (optimize) {
                .Debug, .ReleaseSafe => false,
                .ReleaseFast, .ReleaseSmall => true,
            },
        }),
    });
    addAppIcon(b, exe);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.addPassthruArgs();

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
    addAppIcon(b, release_exe);

    const install_release_tool = b.addExecutable(.{
        .name = "install-release",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/install_release.zig"),
            .target = b.graph.host,
        }),
    });

    const install_release = b.addRunArtifact(install_release_tool);
    install_release.addArtifactArg(release_exe);
    install_release.addDirectoryArg2(.{ .relative = .{ .base = .install_prefix } }, .{ .make_absolute = true });
    install_release.addDirectoryArg2(b.path(""), .{ .make_absolute = true });

    const install_release_step = b.step("install-release", "Build ReleaseSmall and install to ~/.local/bin (%USERPROFILE%/.local/bin on Windows)");
    install_release_step.dependOn(&install_release.step);
}

fn addAppIcon(b: *std.Build, exe: *std.Build.Step.Compile) void {
    if (exe.rootModuleTarget().os.tag != .windows) return;
    exe.root_module.addWin32ResourceFile(.{ .file = b.path("assets/chlogr.rc") });
}
