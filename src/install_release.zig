//! Build helper that copies the release binary to the resolved install
//! directory. Zig 0.17 runs custom build logic out of process, so the
//! install-release step executes this program instead of a custom Step.
//!
//! Usage: install_release <binary> <install-prefix> <build-root>

const std = @import("std");
const build_install = @import("build_install.zig");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    if (args.len != 4) {
        std.debug.print("usage: {s} <binary> <install-prefix> <build-root>\n", .{args[0]});
        return error.InvalidArguments;
    }

    const binary = args[1];
    // Normalize both so a build root like `C:\repo\.` still matches.
    const install_prefix = try std.fs.path.resolve(arena, &.{args[2]});
    const default_prefix = try std.fs.path.resolve(arena, &.{ args[3], "zig-out" });

    const dest_dir = build_install.resolveInstallDir(arena, install_prefix, default_prefix, init.environ_map, @import("builtin").os.tag);
    const dest_path = try std.fs.path.join(arena, &.{ dest_dir, std.fs.path.basename(binary) });

    const cwd = std.Io.Dir.cwd();
    _ = try cwd.updateFile(init.io, binary, cwd, dest_path, .{});
    std.debug.print("installed {s}\n", .{dest_path});
}
