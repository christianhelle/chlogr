const std = @import("std");

pub const HttpResponse = struct {
    status: std.http.Status,
    body: []u8,
    link_header: ?[]u8 = null,

    pub fn deinit(self: HttpResponse, allocator: std.mem.Allocator) void {
        allocator.free(self.body);
        if (self.link_header) |link_header| {
            allocator.free(link_header);
        }
    }
};

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

    pub fn get(self: *HttpClient, endpoint: []const u8) !HttpResponse {
        const full_url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base_url, endpoint });
        defer self.allocator.free(full_url);

        var headers: std.ArrayList(std.http.Header) = .empty;
        defer headers.deinit(self.allocator);

        try headers.append(
            self.allocator,
            .{ .name = "User-Agent", .value = "chlogr/0.1.0" },
        );
        try headers.append(
            self.allocator,
            .{ .name = "Accept", .value = "application/vnd.github.v3+json" },
        );
        try headers.append(
            self.allocator,
            .{ .name = "Accept-Encoding", .value = "identity" },
        );

        var auth_header_value: ?[]u8 = null;
        defer if (auth_header_value) |v| self.allocator.free(v);

        if (self.token.len > 0) {
            auth_header_value = try std.fmt.allocPrint(self.allocator, "Bearer {s}", .{self.token});
            try headers.append(
                self.allocator,
                .{ .name = "Authorization", .value = auth_header_value.? },
            );
        }

        const uri = try std.Uri.parse(full_url);
        var request = try self.client.request(.GET, uri, .{
            .headers = .{
                .accept_encoding = .omit,
                .user_agent = .omit,
            },
            .extra_headers = headers.items,
        });
        defer request.deinit();

        try request.sendBodiless();

        var response = try request.receiveHead(&.{});
        const status = response.head.status;

        var link_header: ?[]u8 = null;
        errdefer if (link_header) |value| self.allocator.free(value);

        var header_it = response.head.iterateHeaders();
        while (header_it.next()) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, "link")) {
                link_header = try self.allocator.dupe(u8, header.value);
                break;
            }
        }

        var body = std.Io.Writer.Allocating.init(self.allocator);
        defer body.deinit();

        const decompress_buffer: []u8 = switch (response.head.content_encoding) {
            .identity => &.{},
            .zstd => try self.allocator.alloc(u8, std.compress.zstd.default_window_len),
            .deflate, .gzip => try self.allocator.alloc(u8, std.compress.flate.max_window_len),
            .compress => return error.UnsupportedCompressionMethod,
        };
        defer if (response.head.content_encoding != .identity) self.allocator.free(decompress_buffer);

        var transfer_buffer: [64]u8 = undefined;
        var decompress: std.http.Decompress = undefined;
        const reader = response.readerDecompressing(
            &transfer_buffer,
            &decompress,
            decompress_buffer,
        );
        _ = reader.streamRemaining(&body.writer) catch |err| switch (err) {
            error.ReadFailed => return response.bodyErr().?,
            else => |stream_err| return stream_err,
        };

        var list = body.toArrayList();
        const owned_body = try list.toOwnedSlice(self.allocator);

        return HttpResponse{
            .status = status,
            .body = owned_body,
            .link_header = link_header,
        };
    }

    pub fn deinit(self: *HttpClient) void {
        self.client.deinit();
    }
};
