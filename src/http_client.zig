const std = @import("std");

pub const HttpClient = struct {
    allocator: std.mem.Allocator,
    token: []const u8,
    base_url: []const u8 = "https://api.github.com",

    pub fn init(allocator: std.mem.Allocator, token: []const u8) HttpClient {
        return HttpClient{
            .allocator = allocator,
            .token = token,
        };
    }

    pub fn get(self: *HttpClient, endpoint: []const u8) ![]u8 {
        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base_url, endpoint });
        defer self.allocator.free(url);

        // Use curl as fallback for HTTP requests
        const auth_header = try std.fmt.allocPrint(self.allocator, "Authorization: token {s}", .{self.token});
        defer self.allocator.free(auth_header);

        const user_agent = "User-Agent: chlogr/0.1.0";

        const args = [_][]const u8{
            "curl",
            "-s",
            "-H",
            auth_header,
            "-H",
            user_agent,
            "-H",
            "Accept: application/vnd.github.v3+json",
            url,
        };

        var child = std.process.Child.init(&args, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        try child.spawn();

        // Read response with fixed buffer then copy to owned slice
        var buffer: [10 * 1024 * 1024]u8 = undefined;
        const bytes_read = try child.stdout.?.readAll(&buffer);

        const term = try child.wait();
        if (term.Exited != 0) {
            return error.CurlFailed;
        }

        if (bytes_read == 0) {
            return error.EmptyResponse;
        }

        return try self.allocator.dupe(u8, buffer[0..bytes_read]);
    }

    pub fn deinit(self: *HttpClient) void {
        _ = self;
    }
};
