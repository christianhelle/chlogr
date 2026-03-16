const std = @import("std");
const http_client = @import("http_client.zig");
const models = @import("models.zig");

pub const GitHubApiClient = struct {
    allocator: std.mem.Allocator,
    http_client: http_client.HttpClient,
    repo: []const u8,

    pub fn init(allocator: std.mem.Allocator, token: []const u8, repo: []const u8) GitHubApiClient {
        return GitHubApiClient{
            .allocator = allocator,
            .http_client = http_client.HttpClient.init(allocator, token),
            .repo = repo,
        };
    }

    /// Fetch all releases/tags for the repository
    pub fn getReleases(self: *GitHubApiClient) ![]models.Release {
        const endpoint = try std.fmt.allocPrint(self.allocator, "/repos/{s}/releases", .{self.repo});
        defer self.allocator.free(endpoint);

        const response = try self.http_client.get(endpoint);
        defer self.allocator.free(response.body);

        if (response.status != .ok) {
            return error.GitHubApiError;
        }

        // Parse JSON response with ignoring unknown fields
        var parsed = try std.json.parseFromSlice(
            []models.Release,
            self.allocator,
            response.body,
            .{ .ignore_unknown_fields = true },
        );
        defer parsed.deinit();

        // Deep copy releases with string duplication
        var releases = try std.ArrayList(models.Release).initCapacity(self.allocator, parsed.value.len);
        for (parsed.value) |release| {
            releases.appendAssumeCapacity(.{
                .tag_name = try self.allocator.dupe(u8, release.tag_name),
                .name = try self.allocator.dupe(u8, release.name),
                .published_at = try self.allocator.dupe(u8, release.published_at),
            });
        }
        return try releases.toOwnedSlice(self.allocator);
    }

    /// Fetch merged pull requests
    pub fn getMergedPullRequests(self: *GitHubApiClient, per_page: u32) ![]models.PullRequest {
        const endpoint = try std.fmt.allocPrint(self.allocator, "/repos/{s}/pulls?state=closed&per_page={d}&sort=updated&direction=desc", .{ self.repo, per_page });
        defer self.allocator.free(endpoint);

        const response = try self.http_client.get(endpoint);
        defer self.allocator.free(response.body);

        if (response.status != .ok) {
            return error.GitHubApiError;
        }

        var parsed = try std.json.parseFromSlice(
            []models.PullRequest,
            self.allocator,
            response.body,
            .{ .ignore_unknown_fields = true },
        );
        defer parsed.deinit();

        // Deep copy PRs with string and struct duplication
        var prs = try std.ArrayList(models.PullRequest).initCapacity(self.allocator, parsed.value.len);
        for (parsed.value) |pr| {
            // Copy labels
            var labels = try std.ArrayList(models.Label).initCapacity(self.allocator, pr.labels.len);
            for (pr.labels) |label| {
                labels.appendAssumeCapacity(.{
                    .name = try self.allocator.dupe(u8, label.name),
                    .color = try self.allocator.dupe(u8, label.color),
                });
            }

            prs.appendAssumeCapacity(.{
                .number = pr.number,
                .title = try self.allocator.dupe(u8, pr.title),
                .body = if (pr.body) |body| try self.allocator.dupe(u8, body) else null,
                .html_url = try self.allocator.dupe(u8, pr.html_url),
                .user = .{
                    .login = try self.allocator.dupe(u8, pr.user.login),
                    .html_url = try self.allocator.dupe(u8, pr.user.html_url),
                },
                .labels = try labels.toOwnedSlice(self.allocator),
                .merged_at = if (pr.merged_at) |merged| try self.allocator.dupe(u8, merged) else null,
            });
        }
        return try prs.toOwnedSlice(self.allocator);
    }

    /// Fetch closed issues
    pub fn getClosedIssues(self: *GitHubApiClient, per_page: u32) ![]models.Issue {
        const endpoint = try std.fmt.allocPrint(self.allocator, "/repos/{s}/issues?state=closed&per_page={d}", .{ self.repo, per_page });
        defer self.allocator.free(endpoint);

        const response = try self.http_client.get(endpoint);
        defer self.allocator.free(response.body);

        if (response.status != .ok) {
            return error.GitHubApiError;
        }

        var parsed = try std.json.parseFromSlice(
            []models.Issue,
            self.allocator,
            response.body,
            .{ .ignore_unknown_fields = true },
        );
        defer parsed.deinit();

        // Deep copy Issues with string and struct duplication
        var issues = try std.ArrayList(models.Issue).initCapacity(self.allocator, parsed.value.len);
        for (parsed.value) |issue| {
            // Copy labels
            var labels = try std.ArrayList(models.Label).initCapacity(self.allocator, issue.labels.len);
            for (issue.labels) |label| {
                labels.appendAssumeCapacity(.{
                    .name = try self.allocator.dupe(u8, label.name),
                    .color = try self.allocator.dupe(u8, label.color),
                });
            }

            issues.appendAssumeCapacity(.{
                .number = issue.number,
                .title = try self.allocator.dupe(u8, issue.title),
                .body = if (issue.body) |body| try self.allocator.dupe(u8, body) else null,
                .html_url = try self.allocator.dupe(u8, issue.html_url),
                .user = .{
                    .login = try self.allocator.dupe(u8, issue.user.login),
                    .html_url = try self.allocator.dupe(u8, issue.user.html_url),
                },
                .labels = try labels.toOwnedSlice(self.allocator),
            });
        }
        return try issues.toOwnedSlice(self.allocator);
    }

    pub fn deinit(self: *GitHubApiClient) void {
        self.http_client.deinit();
    }

    /// Free all allocated releases and their strings
    pub fn freeReleases(self: *GitHubApiClient, releases: []models.Release) void {
        for (releases) |release| {
            self.allocator.free(release.tag_name);
            self.allocator.free(release.name);
            self.allocator.free(release.published_at);
        }
        self.allocator.free(releases);
    }

    /// Free all allocated PRs and their strings
    pub fn freePullRequests(self: *GitHubApiClient, prs: []models.PullRequest) void {
        for (prs) |pr| {
            self.allocator.free(pr.title);
            if (pr.body) |body| self.allocator.free(body);
            self.allocator.free(pr.html_url);
            self.allocator.free(pr.user.login);
            self.allocator.free(pr.user.html_url);
            for (pr.labels) |label| {
                self.allocator.free(label.name);
                self.allocator.free(label.color);
            }
            self.allocator.free(pr.labels);
            if (pr.merged_at) |merged| self.allocator.free(merged);
        }
        self.allocator.free(prs);
    }

    /// Free all allocated issues and their strings
    pub fn freeIssues(self: *GitHubApiClient, issues: []models.Issue) void {
        for (issues) |issue| {
            self.allocator.free(issue.title);
            if (issue.body) |body| self.allocator.free(body);
            self.allocator.free(issue.html_url);
            self.allocator.free(issue.user.login);
            self.allocator.free(issue.user.html_url);
            for (issue.labels) |label| {
                self.allocator.free(label.name);
                self.allocator.free(label.color);
            }
            self.allocator.free(issue.labels);
        }
        self.allocator.free(issues);
    }
};
