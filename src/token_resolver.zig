const std = @import("std");

pub const ResolvedToken = struct {
    value: []const u8,
    has_token: bool,
    is_owned: bool,
};

pub const TokenResolver = struct {
    allocator: std.mem.Allocator,
    environ: std.process.Environ,
    io: std.Io,

    pub fn init(allocator: std.mem.Allocator, environ: std.process.Environ, io: std.Io) TokenResolver {
        return TokenResolver{
            .allocator = allocator,
            .environ = environ,
            .io = io,
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
        if (std.process.Environ.getAlloc(self.environ, self.allocator, "GITHUB_TOKEN")) |token| {
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
            if (err != error.EnvironmentVariableMissing) return err;
        }

        // 3. Check GH_TOKEN env var (owned - must free)
        if (std.process.Environ.getAlloc(self.environ, self.allocator, "GH_TOKEN")) |token| {
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
            if (err != error.EnvironmentVariableMissing) return err;
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
        const result = try std.process.run(self.allocator, self.io, .{
            .argv = &.{ "gh", "auth", "token" },
        });
        defer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);

        switch (result.term) {
            .exited => |code| if (code != 0) return error.GhCliExited,
            else => return error.GhCliExited,
        }

        const token = std.mem.trim(u8, result.stdout, " \t\n\r");
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
