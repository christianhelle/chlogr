const std = @import("std");

/// Resolve the directory where the release binary is installed.
///
/// Resolution order:
///   1. An explicit `--prefix` (any value other than the build default) wins
///      and resolves to `<prefix>/bin`, matching Zig's standard layout.
///   2. The `INSTALL_DIR` environment variable is used verbatim as the
///      executable directory.
///   3. The platform home directory with a `.local/bin` suffix is used as the
///      default: `USERPROFILE` on Windows, `HOME` elsewhere.
pub fn resolveInstallDir(
    allocator: std.mem.Allocator,
    install_prefix: []const u8,
    default_prefix: []const u8,
    environ: *const std.process.Environ.Map,
    os_tag: std.Target.Os.Tag,
) []const u8 {
    if (!std.mem.eql(u8, install_prefix, default_prefix)) {
        return std.fs.path.join(allocator, &.{ install_prefix, "bin" }) catch @panic("OOM");
    }

    if (environ.get("INSTALL_DIR")) |install_dir| {
        if (install_dir.len > 0) return allocator.dupe(u8, install_dir) catch @panic("OOM");
    }

    const primary = if (os_tag == .windows) "USERPROFILE" else "HOME";
    const fallback = if (os_tag == .windows) "HOME" else "USERPROFILE";
    const home_vars = [_][]const u8{ primary, fallback };
    for (home_vars) |home_var| {
        if (environ.get(home_var)) |home| {
            if (home.len > 0) return std.fs.path.join(allocator, &.{ home, ".local", "bin" }) catch @panic("OOM");
        }
    }

    @panic("unable to determine install directory: set HOME, USERPROFILE, or INSTALL_DIR");
}

test "resolveInstallDir appends bin to an explicit --prefix" {
    const allocator = std.testing.allocator;
    var env = std.process.Environ.Map.init(allocator);
    defer env.deinit();

    const got = resolveInstallDir(allocator, "/usr/local", "zig-out", &env, .linux);
    defer allocator.free(got);

    const expected = try std.fs.path.join(allocator, &.{ "/usr/local", "bin" });
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, got);
}

test "resolveInstallDir --prefix wins over INSTALL_DIR" {
    const allocator = std.testing.allocator;
    var env = std.process.Environ.Map.init(allocator);
    defer env.deinit();
    try env.put("INSTALL_DIR", "/opt/chlogr");

    const got = resolveInstallDir(allocator, "/custom/prefix", "zig-out", &env, .linux);
    defer allocator.free(got);

    const expected = try std.fs.path.join(allocator, &.{ "/custom/prefix", "bin" });
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, got);
}

test "resolveInstallDir uses INSTALL_DIR verbatim without --prefix" {
    const allocator = std.testing.allocator;
    var env = std.process.Environ.Map.init(allocator);
    defer env.deinit();
    try env.put("INSTALL_DIR", "/opt/chlogr");

    const got = resolveInstallDir(allocator, "zig-out", "zig-out", &env, .linux);
    defer allocator.free(got);

    try std.testing.expectEqualStrings("/opt/chlogr", got);
}

test "resolveInstallDir prefers HOME on linux" {
    const allocator = std.testing.allocator;
    var env = std.process.Environ.Map.init(allocator);
    defer env.deinit();
    try env.put("HOME", "/home/me");
    try env.put("USERPROFILE", "/fake");

    const got = resolveInstallDir(allocator, "zig-out", "zig-out", &env, .linux);
    defer allocator.free(got);

    const expected = try std.fs.path.join(allocator, &.{ "/home/me", ".local", "bin" });
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, got);
}

test "resolveInstallDir prefers USERPROFILE on windows" {
    const allocator = std.testing.allocator;
    var env = std.process.Environ.Map.init(allocator);
    defer env.deinit();
    try env.put("USERPROFILE", "C:\\Users\\me");
    try env.put("HOME", "C:\\msys64\\home\\me");

    const got = resolveInstallDir(allocator, "zig-out", "zig-out", &env, .windows);
    defer allocator.free(got);

    const expected = try std.fs.path.join(allocator, &.{ "C:\\Users\\me", ".local", "bin" });
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, got);
}

test "resolveInstallDir falls back to HOME on windows when USERPROFILE is unset" {
    const allocator = std.testing.allocator;
    var env = std.process.Environ.Map.init(allocator);
    defer env.deinit();
    try env.put("HOME", "C:\\msys64\\home\\me");

    const got = resolveInstallDir(allocator, "zig-out", "zig-out", &env, .windows);
    defer allocator.free(got);

    const expected = try std.fs.path.join(allocator, &.{ "C:\\msys64\\home\\me", ".local", "bin" });
    defer allocator.free(expected);

    try std.testing.expectEqualStrings(expected, got);
}
