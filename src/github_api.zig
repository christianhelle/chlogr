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

    /// Parse Link header to extract next page URL
    fn extractNextPageUrl(link_header: []const u8) ?[]const u8 {
        // GitHub Link header format: <https://api.github.com/...?page=2>; rel="next", <https://...>; rel="last"
        var it = std.mem.tokenizeAny(u8, link_header, ",");
        while (it.next()) |link_part| {
            const trimmed = std.mem.trim(u8, link_part, " \t\r\n");
            
            // Check if this part contains rel="next"
            if (std.mem.indexOf(u8, trimmed, "rel=\"next\"") != null or 
                std.mem.indexOf(u8, trimmed, "rel='next'") != null) {
                // Extract URL between < and >
                if (std.mem.indexOfScalar(u8, trimmed, '<')) |start| {
                    if (std.mem.indexOfScalar(u8, trimmed, '>')) |end| {
                        if (end > start + 1) {
                            return trimmed[start + 1 .. end];
                        }
                    }
                }
            }
        }
        return null;
    }

    /// Fetch all releases/tags for the repository (with pagination)
    pub fn getReleases(self: *GitHubApiClient) ![]models.Release {
        var all_releases = std.ArrayList(models.Release).init(self.allocator);
        errdefer {
            for (all_releases.items) |release| {
                self.allocator.free(release.tag_name);
                self.allocator.free(release.name);
                self.allocator.free(release.published_at);
            }
            all_releases.deinit(self.allocator);
        }

        var endpoint = try std.fmt.allocPrint(self.allocator, "/repos/{s}/releases?per_page=100", .{self.repo});
        defer self.allocator.free(endpoint);

        var current_url: ?[]const u8 = endpoint;
        var page: usize = 1;

        while (current_url != null) : (page += 1) {
            const response = try self.http_client.get(current_url.?);
            defer self.allocator.free(response.body);
            defer if (response.link_header) |link| self.allocator.free(link);

            if (response.status != .ok) {
                return error.GitHubApiError;
            }

            var parsed = try std.json.parseFromSlice(
                []models.Release,
                self.allocator,
                response.body,
                .{ .ignore_unknown_fields = true },
            );
            defer parsed.deinit();

            // Deep copy releases from this page
            for (parsed.value) |release| {
                try all_releases.append(self.allocator, .{
                    .tag_name = try self.allocator.dupe(u8, release.tag_name),
                    .name = try self.allocator.dupe(u8, release.name),
                    .published_at = try self.allocator.dupe(u8, release.published_at),
                });
            }

            // Check for next page
            if (response.link_header) |link_header| {
                if (extractNextPageUrl(link_header)) |next_url| {
                    // Free old endpoint if not the original
                    if (page > 1) {
                        self.allocator.free(current_url.?);
                    }
                    current_url = try self.allocator.dupe(u8, next_url);
                } else {
                    // No more pages
                    if (page > 1) {
                        self.allocator.free(current_url.?);
                    }
                    current_url = null;
                }
            } else {
                // No Link header means this is the only/last page
                if (page > 1) {
                    self.allocator.free(current_url.?);
                }
                current_url = null;
            }
        }

        return try all_releases.toOwnedSlice(self.allocator);
    }

    /// Fetch merged pull requests (with pagination, filtered by merged_at)
    pub fn getMergedPullRequests(self: *GitHubApiClient, per_page: u32) ![]models.PullRequest {
        _ = per_page; // Ignore parameter, always use 100 for pagination efficiency
        
        var all_prs = std.ArrayList(models.PullRequest).init(self.allocator);
        errdefer {
            for (all_prs.items) |pr| {
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
            all_prs.deinit(self.allocator);
        }

        var endpoint = try std.fmt.allocPrint(self.allocator, "/repos/{s}/pulls?state=closed&per_page=100&sort=updated&direction=desc", .{self.repo});
        defer self.allocator.free(endpoint);

        var current_url: ?[]const u8 = endpoint;
        var page: usize = 1;

        while (current_url != null) : (page += 1) {
            const response = try self.http_client.get(current_url.?);
            defer self.allocator.free(response.body);
            defer if (response.link_header) |link| self.allocator.free(link);

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

            // Deep copy PRs from this page, but only include merged PRs
            for (parsed.value) |pr| {
                // Skip non-merged PRs
                if (pr.merged_at == null) continue;

                // Copy labels
                var labels = std.ArrayList(models.Label).init(self.allocator);
                errdefer {
                    for (labels.items) |label| {
                        self.allocator.free(label.name);
                        self.allocator.free(label.color);
                    }
                    labels.deinit(self.allocator);
                }
                
                for (pr.labels) |label| {
                    try labels.append(self.allocator, .{
                        .name = try self.allocator.dupe(u8, label.name),
                        .color = try self.allocator.dupe(u8, label.color),
                    });
                }

                try all_prs.append(self.allocator, .{
                    .number = pr.number,
                    .title = try self.allocator.dupe(u8, pr.title),
                    .body = if (pr.body) |body| try self.allocator.dupe(u8, body) else null,
                    .html_url = try self.allocator.dupe(u8, pr.html_url),
                    .user = .{
                        .login = try self.allocator.dupe(u8, pr.user.login),
                        .html_url = try self.allocator.dupe(u8, pr.user.html_url),
                    },
                    .labels = try labels.toOwnedSlice(self.allocator),
                    .merged_at = try self.allocator.dupe(u8, pr.merged_at.?),
                });
            }

            // Check for next page
            if (response.link_header) |link_header| {
                if (extractNextPageUrl(link_header)) |next_url| {
                    if (page > 1) {
                        self.allocator.free(current_url.?);
                    }
                    current_url = try self.allocator.dupe(u8, next_url);
                } else {
                    if (page > 1) {
                        self.allocator.free(current_url.?);
                    }
                    current_url = null;
                }
            } else {
                if (page > 1) {
                    self.allocator.free(current_url.?);
                }
                current_url = null;
            }
        }

        return try all_prs.toOwnedSlice(self.allocator);
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
