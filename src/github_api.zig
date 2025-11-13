const std = @import("std");
const http_client = @import("http_client.zig");
const models = @import("models.zig");

pub const GitHubApiClient = struct {
    allocator: std.mem.Allocator,
    http_client: http_client.HttpClient,
    owner: []const u8,
    repo: []const u8,

    pub fn init(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8) GitHubApiClient {
        return GitHubApiClient{
            .allocator = allocator,
            .http_client = http_client.HttpClient.init(allocator, token),
            .owner = owner,
            .repo = repo,
        };
    }

    /// Fetch all releases/tags for the repository
    pub fn getReleases(self: *GitHubApiClient) ![]models.Release {
        const endpoint = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}/releases", .{ self.owner, self.repo });
        defer self.allocator.free(endpoint);

        const response = try self.http_client.get(endpoint);
        defer self.allocator.free(response);

        // Parse JSON response
        var parsed = try std.json.parseFromSlice(
            []models.Release,
            self.allocator,
            response,
            .{},
        );
        defer parsed.deinit();

        return parsed.value;
    }

    /// Fetch merged pull requests
    pub fn getMergedPullRequests(self: *GitHubApiClient, per_page: u32) ![]models.PullRequest {
        const endpoint = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}/pulls?state=closed&per_page={d}", .{ self.owner, self.repo, per_page });
        defer self.allocator.free(endpoint);

        const response = try self.http_client.get(endpoint);
        defer self.allocator.free(response);

        var parsed = try std.json.parseFromSlice(
            []models.PullRequest,
            self.allocator,
            response,
            .{},
        );
        defer parsed.deinit();

        return parsed.value;
    }

    /// Fetch closed issues
    pub fn getClosedIssues(self: *GitHubApiClient, per_page: u32) ![]models.Issue {
        const endpoint = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}/issues?state=closed&per_page={d}", .{ self.owner, self.repo, per_page });
        defer self.allocator.free(endpoint);

        const response = try self.http_client.get(endpoint);
        defer self.allocator.free(response);

        var parsed = try std.json.parseFromSlice(
            []models.Issue,
            self.allocator,
            response,
            .{},
        );
        defer parsed.deinit();

        return parsed.value;
    }

    pub fn deinit(self: *GitHubApiClient) void {
        self.http_client.deinit();
    }
};
