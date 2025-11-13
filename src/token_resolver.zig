const std = @import("std");

pub const TokenResolver = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) TokenResolver {
        return TokenResolver{
            .allocator = allocator,
        };
    }

    /// Resolve GitHub token with fallback chain:
    /// 1. Use provided token (if not null)
    /// 2. Check GITHUB_TOKEN env var
    /// 3. Check GH_TOKEN env var
    /// 4. Try to get token from 'gh auth token' command
    pub fn resolve(self: TokenResolver, provided_token: ?[]const u8) ![]const u8 {
        // 1. Check provided token
        if (provided_token) |token| {
            return token;
        }

        // 2. Check GITHUB_TOKEN env var
        if (std.process.getEnvVarOwned(self.allocator, "GITHUB_TOKEN")) |token| {
            return token;
        } else |_| {}

        // 3. Check GH_TOKEN env var
        if (std.process.getEnvVarOwned(self.allocator, "GH_TOKEN")) |token| {
            return token;
        } else |_| {}

        // 4. Try to get token from gh CLI
        if (self.getTokenFromGhCli()) |token| {
            return token;
        } else |_| {}

        return error.NoTokenAvailable;
    }

    /// Attempt to get token from GitHub CLI command 'gh auth token'
    fn getTokenFromGhCli(self: TokenResolver) ![]const u8 {
        var child = std.process.Child.init(&[_][]const u8{"gh", "auth", "token"}, self.allocator);

        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        try child.spawn();
        defer {
            _ = child.kill() catch {};
        }

        var stdout_buf: [1024]u8 = undefined;
        const bytes_read = try child.stdout.?.readAll(&stdout_buf);
        const stdout = stdout_buf[0..bytes_read];

        const term = try child.wait();

        if (term.Exited != 0) {
            return error.GhCliExited;
        }

        // Trim whitespace from output
        const token = std.mem.trim(u8, stdout, " \t\n\r");
        if (token.len == 0) {
            return error.EmptyToken;
        }

        return try self.allocator.dupe(u8, token);
    }

    pub fn deinit(self: TokenResolver, token: []const u8) void {
        // Only free if it was allocated (from gh CLI or env var)
        self.allocator.free(token);
    }
};
