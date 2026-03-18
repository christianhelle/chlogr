const std = @import("std");

pub const ResolvedToken = struct {
    value: []const u8,
    has_token: bool,
    is_owned: bool,
};

pub const TokenResolver = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) TokenResolver {
        return TokenResolver{
            .allocator = allocator,
        };
    }

    /// Resolve GitHub token with fallback chain:
    /// 1. Use provided token (if not null and not empty)
    /// 2. Check GITHUB_TOKEN env var
    /// 3. Check GH_TOKEN env var
    /// 4. Try to get token from 'gh auth token' command
    /// Returns a ResolvedToken - if no token found, returns empty string with has_token=false
    pub fn resolve(self: TokenResolver, provided_token: ?[]const u8) !ResolvedToken {
        // 1. Check provided token (not owned - don't free)
        if (provided_token) |token| {
            if (token.len > 0) {
                return ResolvedToken{
                    .value = token,
                    .has_token = true,
                    .is_owned = false,
                };
            }
        }

        // 2. Check GITHUB_TOKEN env var (owned - must free)
        if (std.process.getEnvVarOwned(self.allocator, "GITHUB_TOKEN")) |token| {
            if (token.len > 0) {
                std.debug.print("Using GITHUB_TOKEN from environment variable\n", .{});
                return ResolvedToken{
                    .value = token,
                    .has_token = true,
                    .is_owned = true,
                };
            } else {
                self.allocator.free(token);
            }
        } else |err| {
            if (err != error.EnvironmentVariableNotFound) return err;
        }

        // 3. Check GH_TOKEN env var (owned - must free)
        if (std.process.getEnvVarOwned(self.allocator, "GH_TOKEN")) |token| {
            if (token.len > 0) {
                std.debug.print("Using GH_TOKEN from environment variable\n", .{});
                return ResolvedToken{
                    .value = token,
                    .has_token = true,
                    .is_owned = true,
                };
            } else {
                self.allocator.free(token);
            }
        } else |err| {
            if (err != error.EnvironmentVariableNotFound) return err;
        }

        // 4. Try to get token from gh CLI (owned - must free)
        if (self.getTokenFromGhCli()) |token| {
            std.debug.print("Using token from 'gh auth token' command\n", .{});
            return ResolvedToken{
                .value = token,
                .has_token = true,
                .is_owned = true,
            };
        } else |err| {
            if (err != error.GhCliExited and err != error.EmptyToken and err != error.FileNotFound) return err;
        }

        // No token found - return empty token but don't error
        std.debug.print("No GitHub token provided or found - proceeding without token (may have lower rate limits)\n", .{});
        return ResolvedToken{
            .value = "",
            .has_token = false,
            .is_owned = false,
        };
    }

    /// Attempt to get token from GitHub CLI command 'gh auth token'
    fn getTokenFromGhCli(self: TokenResolver) ![]const u8 {
        var child = std.process.Child.init(&[_][]const u8{ "gh", "auth", "token" }, self.allocator);

        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Ignore;

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

    pub fn deinit(self: TokenResolver, resolved_token: ResolvedToken) void {
        // Only free if it was allocated (from gh CLI or env var)
        if (resolved_token.is_owned) {
            self.allocator.free(resolved_token.value);
        }
    }
};
