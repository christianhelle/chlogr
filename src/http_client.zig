const std = @import("std");

pub const HttpClient = struct {
    allocator: std.mem.Allocator,
    client: std.http.Client,
    token: []const u8,
    base_url: []const u8 = "https://api.github.com",

    pub fn init(allocator: std.mem.Allocator, token: []const u8) HttpClient {
        return HttpClient{
            .allocator = allocator,
            .client = std.http.Client{ .allocator = allocator },
            .token = token,
        };
    }

    pub fn get(self: *HttpClient, endpoint: []const u8) ![]u8 {
        const full_url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base_url, endpoint });
        defer self.allocator.free(full_url);

        var headers: std.ArrayList(std.http.Header) = .empty;
        defer headers.deinit(self.allocator);

        try headers.append(self.allocator, .{ .name = "User-Agent", .value = "chlogr/0.1.0" });
        try headers.append(self.allocator, .{ .name = "Accept", .value = "application/vnd.github.v3+json" });
        try headers.append(self.allocator, .{ .name = "Accept-Encoding", .value = "identity" });

        if (self.token.len > 0) {
            try headers.append(self.allocator, .{ .name = "Authorization", .value = self.token });
        }

        var body = std.Io.Writer.Allocating.init(self.allocator);
        defer body.deinit();

        const result = self.client.fetch(.{
            .method = .GET,
            .location = .{ .url = full_url },
            .extra_headers = headers.items,
            .response_writer = &body.writer,
        }) catch |err| {
            return err;
        };

        if (result.status != .ok) {
            return error.HttpError;
        }

        var list = body.toArrayList();
        return try list.toOwnedSlice(self.allocator);
    }

    pub fn deinit(self: *HttpClient) void {
        self.client.deinit();
    }
};
