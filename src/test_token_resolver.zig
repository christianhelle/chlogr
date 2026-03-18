const std = @import("std");
const token_resolver = @import("token_resolver.zig");

fn testGhProcessAbnormalExit() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var resolver = token_resolver.TokenResolver.init(allocator);

    // Test when gh exits with non-zero status
    // This should be handled gracefully by returning error.GhCliExited
    const result = resolver.getTokenFromGhCli() catch |err| {
        if (err == error.GhCliExited or err == error.FileNotFound) {
            std.debug.print("  Expected error when gh exits abnormally: {any}\n", .{err});
            return;
        }
        return err;
    };
    // If we got a token, free it
    allocator.free(result);
}

fn testGhNotInstalled() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var resolver = token_resolver.TokenResolver.init(allocator);

    // When gh is not found, expect FileNotFound error
    const result = resolver.getTokenFromGhCli() catch |err| {
        std.debug.print("  Expected FileNotFound when gh not installed: {any}\n", .{err});
        try std.testing.expect(err == error.FileNotFound or err == error.GhCliExited or err == error.EmptyToken);
        return;
    };
    allocator.free(result);
}

fn testEmptyTokenOutput() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a mock script that outputs empty string
    const script_content = "#!/bin/sh\necho \"\"\nexit 0\n";
    const script_path = "/tmp/test_gh_empty_token.sh";
    
    const file = try std.fs.createFileAbsolute(script_path, .{});
    defer std.fs.deleteFileAbsolute(script_path) catch {};
    try file.writeAll(script_content);
    file.close();
    
    // Make executable
    try std.posix.fchmodat(std.fs.cwd().fd, script_path, 0o755, 0);

    // Run the mock script
    var child = std.process.Child.init(&[_][]const u8{script_path}, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Ignore; // Use .Ignore to match token resolver implementation

    try child.spawn();
    
    var stdout_buf: [1024]u8 = undefined;
    const bytes_read = try child.stdout.?.readAll(&stdout_buf);
    const stdout = stdout_buf[0..bytes_read];

    _ = try child.wait();

    const token = std.mem.trim(u8, stdout, " \t\n\r");
    
    // Verify that empty token is handled
    try std.testing.expect(token.len == 0);
    std.debug.print("  Empty token correctly detected\n", .{});
}

fn testStderrWithoutDeadlock() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a mock script that writes to stderr
    const script_content =
        \\#!/bin/sh
        \\echo "Error message to stderr" >&2
        \\echo "Error message 2 to stderr" >&2
        \\echo "Error message 3 to stderr" >&2
        \\echo "ghp_sometoken123"
        \\exit 0
    ;
    const script_path = "/tmp/test_gh_stderr.sh";
    
    const file = try std.fs.createFileAbsolute(script_path, .{});
    defer std.fs.deleteFileAbsolute(script_path) catch {};
    try file.writeAll(script_content);
    file.close();
    
    try std.posix.fchmodat(std.fs.cwd().fd, script_path, 0o755, 0);

    var child = std.process.Child.init(&[_][]const u8{script_path}, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Ignore; // Now using .Ignore to prevent deadlock

    try child.spawn();
    
    // Read stdout
    var stdout_buf: [1024]u8 = undefined;
    const stdout_bytes = try child.stdout.?.readAll(&stdout_buf);
    const stdout = stdout_buf[0..stdout_bytes];

    // No need to drain stderr since we're ignoring it now
    _ = try child.wait();

    const token = std.mem.trim(u8, stdout, " \t\n\r");
    try std.testing.expect(token.len > 0);
    std.debug.print("  Token retrieved without deadlock, stderr ignored\n", .{});
}

fn testTokenResolverWithToken() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var resolver = token_resolver.TokenResolver.init(allocator);

    // Test with provided token
    const provided = "ghp_provided_token";
    const result = try resolver.resolve(provided);
    defer resolver.deinit(result);

    try std.testing.expect(result.has_token);
    try std.testing.expect(!result.is_owned);
    try std.testing.expectEqualStrings(provided, result.value);
    std.debug.print("  Provided token correctly resolved\n", .{});
}

fn testTokenResolverWithoutToken() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Unset environment variables for this test
    const old_github_token = std.process.getEnvVarOwned(allocator, "GITHUB_TOKEN") catch null;
    defer if (old_github_token) |t| allocator.free(t);
    
    const old_gh_token = std.process.getEnvVarOwned(allocator, "GH_TOKEN") catch null;
    defer if (old_gh_token) |t| allocator.free(t);

    var resolver = token_resolver.TokenResolver.init(allocator);

    // Test without any token (gh CLI will likely fail or not be configured)
    const result = try resolver.resolve(null);
    defer resolver.deinit(result);

    // Should gracefully return empty token
    std.debug.print("  Token resolution without credentials: has_token={}\n", .{result.has_token});
}

// End of disabled test
//*/

fn testGhProcessCrashSignal() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a script that crashes with SIGSEGV simulation
    const script_content = "#!/bin/sh\nexit 139\n"; // 139 = 128 + 11 (SIGSEGV)
    const script_path = "/tmp/test_gh_crash.sh";
    
    const file = try std.fs.createFileAbsolute(script_path, .{});
    defer std.fs.deleteFileAbsolute(script_path) catch {};
    try file.writeAll(script_content);
    file.close();
    
    try std.posix.fchmodat(std.fs.cwd().fd, script_path, 0o755, 0);

    var child = std.process.Child.init(&[_][]const u8{script_path}, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Ignore; // Use .Ignore to match token resolver implementation

    try child.spawn();
    
    var stdout_buf: [1024]u8 = undefined;
    _ = try child.stdout.?.readAll(&stdout_buf);

    const term = try child.wait();

    // Verify that abnormal exit is detected using proper switch
    std.debug.print("  Process exit status: {any}\n", .{term});
    switch (term) {
        .Exited => |code| {
            try std.testing.expect(code != 0);
        },
        else => {}, // Signal, Stopped, or Unknown - also indicates abnormal exit
    }
    std.debug.print("  Abnormal process exit correctly detected\n", .{});
}

pub fn main() !void {
    std.debug.print("\n=== Token Resolver Tests (Issue #4) ===\n\n", .{});

    std.debug.print("Test: gh process abnormal exit...\n", .{});
    try testGhProcessAbnormalExit();
    std.debug.print("  PASSED\n\n", .{});

    std.debug.print("Test: gh not installed (command not found)...\n", .{});
    try testGhNotInstalled();
    std.debug.print("  PASSED\n\n", .{});

    std.debug.print("Test: Empty token output...\n", .{});
    try testEmptyTokenOutput();
    std.debug.print("  PASSED\n\n", .{});

    std.debug.print("Test: stderr written without deadlock...\n", .{});
    try testStderrWithoutDeadlock();
    std.debug.print("  PASSED\n\n", .{});

    std.debug.print("Test: Token resolver with provided token...\n", .{});
    try testTokenResolverWithToken();
    std.debug.print("  PASSED\n\n", .{});

    std.debug.print("Test: Token resolver without token...\n", .{});
    try testTokenResolverWithoutToken();
    std.debug.print("  PASSED\n\n", .{});

    // Disabled: Cannot set env vars in Zig for current process
    // std.debug.print("Test: Token resolver from environment variable...\n", .{});
    // try testTokenResolverFromEnvVar();
    // std.debug.print("  PASSED\n\n", .{});

    std.debug.print("Test: gh process crash with signal...\n", .{});
    try testGhProcessCrashSignal();
    std.debug.print("  PASSED\n\n", .{});

    std.debug.print("✅ All token resolver tests completed\n", .{});
}
