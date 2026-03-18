const std = @import("std");

/// Test data generator for pagination scenarios
pub const PaginationTestData = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) PaginationTestData {
        return .{ .allocator = allocator };
    }

    /// Generate N pull requests with sequential numbers
    pub fn generatePRs(self: PaginationTestData, count: usize, start_number: u32, merged_date: []const u8) ![]const u8 {
        var list = try std.ArrayList(u8).initCapacity(self.allocator, count * 300);
        defer list.deinit(self.allocator);

        var writer = list.writer(self.allocator);
        try writer.writeAll("[\n");

        for (0..count) |i| {
            if (i > 0) try writer.writeAll(",\n");
            
            const number = start_number + @as(u32, @intCast(i));
            try writer.print(
                \\  {{
                \\    "number": {d},
                \\    "title": "PR #{d}: Test pull request",
                \\    "body": "Test PR body",
                \\    "html_url": "https://github.com/owner/repo/pull/{d}",
                \\    "user": {{
                \\      "login": "user{d}",
                \\      "html_url": "https://github.com/user{d}"
                \\    }},
                \\    "labels": [
                \\      {{
                \\        "name": "feature",
                \\        "color": "0366d6"
                \\      }}
                \\    ],
                \\    "merged_at": "{s}"
                \\  }}
            , .{ number, number, number, (i % 10), (i % 10), merged_date });
        }

        try writer.writeAll("\n]");
        return try list.toOwnedSlice(self.allocator);
    }

    /// Generate N releases with sequential versions
    pub fn generateReleases(self: PaginationTestData, count: usize, base_date: []const u8) ![]const u8 {
        var list = try std.ArrayList(u8).initCapacity(self.allocator, count * 200);
        defer list.deinit(self.allocator);

        var writer = list.writer(self.allocator);
        try writer.writeAll("[\n");

        for (0..count) |i| {
            if (i > 0) try writer.writeAll(",\n");
            
            const version = count - i; // Reverse order (latest first)
            try writer.print(
                \\  {{
                \\    "tag_name": "v1.{d}.0",
                \\    "name": "Release v1.{d}.0",
                \\    "published_at": "{s}"
                \\  }}
            , .{ version, version, base_date });
        }

        try writer.writeAll("\n]");
        return try list.toOwnedSlice(self.allocator);
    }
};

/// Mock test data for pagination tests
pub const test_pagination_250_prs_page1 = 
    \\[
    \\  {"number": 1, "title": "PR 1", "body": "", "html_url": "https://github.com/owner/repo/pull/1", "user": {"login": "alice", "html_url": "https://github.com/alice"}, "labels": [{"name": "feature", "color": "0366d6"}], "merged_at": "2024-01-15T10:00:00Z"}
    \\]
;

pub const test_releases_15_page1 = 
    \\[
    \\  {"tag_name": "v1.15.0", "name": "Release v1.15.0", "published_at": "2024-01-15T00:00:00Z"},
    \\  {"tag_name": "v1.14.0", "name": "Release v1.14.0", "published_at": "2024-01-14T00:00:00Z"},
    \\  {"tag_name": "v1.13.0", "name": "Release v1.13.0", "published_at": "2024-01-13T00:00:00Z"}
    \\]
;

pub const test_releases_unsorted = 
    \\[
    \\  {"tag_name": "v1.2.0", "name": "Release v1.2.0", "published_at": "2024-01-12T00:00:00Z"},
    \\  {"tag_name": "v1.5.0", "name": "Release v1.5.0", "published_at": "2024-01-15T00:00:00Z"},
    \\  {"tag_name": "v1.1.0", "name": "Release v1.1.0", "published_at": "2024-01-10T00:00:00Z"},
    \\  {"tag_name": "v1.3.0", "name": "Release v1.3.0", "published_at": "2024-01-13T00:00:00Z"}
    \\]
;

pub const test_prs_merged_at_vs_updated = 
    \\[
    \\  {"number": 1, "title": "PR merged early, updated late", "body": "", "html_url": "https://github.com/owner/repo/pull/1", "user": {"login": "alice", "html_url": "https://github.com/alice"}, "labels": [{"name": "feature", "color": "0366d6"}], "merged_at": "2024-01-10T08:00:00Z"},
    \\  {"number": 2, "title": "PR merged late, updated early", "body": "", "html_url": "https://github.com/owner/repo/pull/2", "user": {"login": "bob", "html_url": "https://github.com/bob"}, "labels": [{"name": "bug", "color": "d73a4a"}], "merged_at": "2024-01-15T10:00:00Z"}
    \\]
;

pub const test_same_day_merge_and_release = 
    \\{
    \\  "releases": [
    \\    {"tag_name": "v1.0.0", "name": "Release v1.0.0", "published_at": "2024-01-10T14:00:00Z"}
    \\  ],
    \\  "prs": [
    \\    {"number": 1, "title": "PR merged morning", "body": "", "html_url": "https://github.com/owner/repo/pull/1", "user": {"login": "alice", "html_url": "https://github.com/alice"}, "labels": [{"name": "feature", "color": "0366d6"}], "merged_at": "2024-01-10T10:00:00Z"},
    \\    {"number": 2, "title": "PR merged afternoon", "body": "", "html_url": "https://github.com/owner/repo/pull/2", "user": {"login": "bob", "html_url": "https://github.com/bob"}, "labels": [{"name": "bug", "color": "d73a4a"}], "merged_at": "2024-01-10T16:00:00Z"}
    \\  ]
    \\}
;

pub const test_1000_prs_sample = 
    \\[
    \\  {"number": 1, "title": "PR 1 of 1000", "body": "", "html_url": "https://github.com/owner/repo/pull/1", "user": {"login": "user1", "html_url": "https://github.com/user1"}, "labels": [], "merged_at": "2024-01-01T01:00:00Z"},
    \\  {"number": 500, "title": "PR 500 of 1000", "body": "", "html_url": "https://github.com/owner/repo/pull/500", "user": {"login": "user2", "html_url": "https://github.com/user2"}, "labels": [], "merged_at": "2024-01-05T12:00:00Z"},
    \\  {"number": 1000, "title": "PR 1000 of 1000", "body": "", "html_url": "https://github.com/owner/repo/pull/1000", "user": {"login": "user3", "html_url": "https://github.com/user3"}, "labels": [], "merged_at": "2024-01-10T23:59:59Z"}
    \\]
;

/// Test rate limiting response (403)
pub const test_rate_limit_response = 
    \\{
    \\  "message": "API rate limit exceeded for user ID 12345.",
    \\  "documentation_url": "https://docs.github.com/rest/overview/resources-in-the-rest-api#rate-limiting"
    \\}
;

/// Test rate limiting response (429)
pub const test_rate_limit_429_response = 
    \\{
    \\  "message": "You have exceeded a secondary rate limit. Please wait a few minutes before you try again.",
    \\  "documentation_url": "https://docs.github.com/en/rest/overview/resources-in-the-rest-api#secondary-rate-limits"
    \\}
;
