const std = @import("std");
const http_client = @import("http_client.zig");
const models = @import("models.zig");

fn copyLabel(allocator: std.mem.Allocator, src: models.Label) !models.Label {
    const name = try allocator.dupe(u8, src.name);
    errdefer allocator.free(name);
    const color = try allocator.dupe(u8, src.color);
    return .{ .name = name, .color = color };
}

fn copyLabels(allocator: std.mem.Allocator, src: []const models.Label) ![]models.Label {
    var list = try std.ArrayList(models.Label).initCapacity(allocator, src.len);
    errdefer {
        for (list.items) |l| {
            allocator.free(l.name);
            allocator.free(l.color);
        }
        list.deinit(allocator);
    }
    for (src) |label| {
        list.appendAssumeCapacity(try copyLabel(allocator, label));
    }
    return try list.toOwnedSlice(allocator);
}

fn copyRelease(allocator: std.mem.Allocator, src: models.Release) !models.Release {
    const tag_name = try allocator.dupe(u8, src.tag_name);
    errdefer allocator.free(tag_name);
    const name = try allocator.dupe(u8, src.name);
    errdefer allocator.free(name);
    const published_at = try allocator.dupe(u8, src.published_at);
    return .{ .tag_name = tag_name, .name = name, .published_at = published_at };
}

fn copyPullRequest(allocator: std.mem.Allocator, src: models.PullRequest) !models.PullRequest {
    const title = try allocator.dupe(u8, src.title);
    errdefer allocator.free(title);
    const body: ?[]const u8 = if (src.body) |b| try allocator.dupe(u8, b) else null;
    errdefer if (body) |b| allocator.free(b);
    const html_url = try allocator.dupe(u8, src.html_url);
    errdefer allocator.free(html_url);
    const user_login = try allocator.dupe(u8, src.user.login);
    errdefer allocator.free(user_login);
    const user_html_url = try allocator.dupe(u8, src.user.html_url);
    errdefer allocator.free(user_html_url);
    const labels = try copyLabels(allocator, src.labels);
    errdefer {
        for (labels) |l| {
            allocator.free(l.name);
            allocator.free(l.color);
        }
        allocator.free(labels);
    }
    const merged_at: ?[]const u8 = if (src.merged_at) |m| try allocator.dupe(u8, m) else null;
    return .{
        .number = src.number,
        .title = title,
        .body = body,
        .html_url = html_url,
        .user = .{ .login = user_login, .html_url = user_html_url },
        .labels = labels,
        .merged_at = merged_at,
    };
}

fn copyIssue(allocator: std.mem.Allocator, src: models.Issue) !models.Issue {
    const title = try allocator.dupe(u8, src.title);
    errdefer allocator.free(title);
    const body: ?[]const u8 = if (src.body) |b| try allocator.dupe(u8, b) else null;
    errdefer if (body) |b| allocator.free(b);
    const html_url = try allocator.dupe(u8, src.html_url);
    errdefer allocator.free(html_url);
    const user_login = try allocator.dupe(u8, src.user.login);
    errdefer allocator.free(user_login);
    const user_html_url = try allocator.dupe(u8, src.user.html_url);
    errdefer allocator.free(user_html_url);
    const labels = try copyLabels(allocator, src.labels);
    return .{
        .number = src.number,
        .title = title,
        .body = body,
        .html_url = html_url,
        .user = .{ .login = user_login, .html_url = user_html_url },
        .labels = labels,
    };
}

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

    /// Fetch all releases/tags for the repository (paginated)
    pub fn getReleases(self: *GitHubApiClient) ![]models.Release {
        const per_page: u32 = 100;
        var page: u32 = 1;
        var all_releases = try std.ArrayList(models.Release).initCapacity(self.allocator, 0);
        errdefer {
            for (all_releases.items) |r| {
                self.allocator.free(r.tag_name);
                self.allocator.free(r.name);
                self.allocator.free(r.published_at);
            }
            all_releases.deinit(self.allocator);
        }

        while (true) {
            std.debug.print("  Fetching releases page {d}...\r", .{page});
            const endpoint = try std.fmt.allocPrint(self.allocator, "/repos/{s}/releases?page={d}&per_page={d}", .{ self.repo, page, per_page });
            defer self.allocator.free(endpoint);

            const response = try self.http_client.get(endpoint);
            defer self.allocator.free(response.body);

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

            const page_count = parsed.value.len;
            for (parsed.value) |release| {
                try all_releases.append(self.allocator, try copyRelease(self.allocator, release));
            }

            if (page_count < per_page) break;
            page += 1;
        }
        std.debug.print("\n", .{});

        return try all_releases.toOwnedSlice(self.allocator);
    }

    /// Fetch merged pull requests (paginated)
    pub fn getMergedPullRequests(self: *GitHubApiClient) ![]models.PullRequest {
        const per_page: u32 = 100;
        var page: u32 = 1;
        var all_prs = try std.ArrayList(models.PullRequest).initCapacity(self.allocator, 0);
        errdefer {
            for (all_prs.items) |pr| {
                self.allocator.free(pr.title);
                if (pr.body) |b| self.allocator.free(b);
                self.allocator.free(pr.html_url);
                self.allocator.free(pr.user.login);
                self.allocator.free(pr.user.html_url);
                for (pr.labels) |l| {
                    self.allocator.free(l.name);
                    self.allocator.free(l.color);
                }
                self.allocator.free(pr.labels);
                if (pr.merged_at) |m| self.allocator.free(m);
            }
            all_prs.deinit(self.allocator);
        }

        while (true) {
            std.debug.print("  Fetching pull requests page {d}...\r", .{page});
            const endpoint = try std.fmt.allocPrint(self.allocator, "/repos/{s}/pulls?state=closed&page={d}&per_page={d}&sort=updated&direction=desc", .{ self.repo, page, per_page });
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

            const page_count = parsed.value.len;
            for (parsed.value) |pr| {
                try all_prs.append(self.allocator, try copyPullRequest(self.allocator, pr));
            }

            if (page_count < per_page) break;
            page += 1;
        }
        std.debug.print("\n", .{});

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
        errdefer {
            for (issues.items) |issue| {
                self.allocator.free(issue.title);
                if (issue.body) |b| self.allocator.free(b);
                self.allocator.free(issue.html_url);
                self.allocator.free(issue.user.login);
                self.allocator.free(issue.user.html_url);
                for (issue.labels) |l| {
                    self.allocator.free(l.name);
                    self.allocator.free(l.color);
                }
                self.allocator.free(issue.labels);
            }
            issues.deinit(self.allocator);
        }
        for (parsed.value) |issue| {
            issues.appendAssumeCapacity(try copyIssue(self.allocator, issue));
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

/// Results container for parallel fetch — fields written by threads, read by main after join
pub const ParallelFetchResults = struct {
    releases: []models.Release = &.{},
    prs: []models.PullRequest = &.{},
    releases_err: ?anyerror = null,
    prs_err: ?anyerror = null,
};

/// Context passed to each thread
const ReleasesThreadCtx = struct {
    allocator: std.mem.Allocator,
    token: []const u8,
    repo: []const u8,
    results: *ParallelFetchResults,
};

const PrsThreadCtx = struct {
    allocator: std.mem.Allocator,
    token: []const u8,
    repo: []const u8,
    results: *ParallelFetchResults,
};

fn releasesThreadFn(ctx: ReleasesThreadCtx) void {
    var client = GitHubApiClient.init(ctx.allocator, ctx.token, ctx.repo);
    defer client.deinit();
    ctx.results.releases = client.getReleases() catch |err| {
        ctx.results.releases_err = err;
        return;
    };
}

fn prsThreadFn(ctx: PrsThreadCtx) void {
    var client = GitHubApiClient.init(ctx.allocator, ctx.token, ctx.repo);
    defer client.deinit();
    ctx.results.prs = client.getMergedPullRequests() catch |err| {
        ctx.results.prs_err = err;
        return;
    };
}

pub const ParallelFetcher = struct {
    allocator: std.mem.Allocator,
    token: []const u8,
    repo: []const u8,

    pub fn init(allocator: std.mem.Allocator, token: []const u8, repo: []const u8) ParallelFetcher {
        return .{ .allocator = allocator, .token = token, .repo = repo };
    }

    /// Fetch releases and PRs concurrently. Caller owns the returned slices.
    /// On error, any successfully fetched data is freed before returning.
    pub fn fetch(self: *ParallelFetcher) !ParallelFetchResults {
        var results = ParallelFetchResults{};

        const releases_ctx = ReleasesThreadCtx{
            .allocator = self.allocator,
            .token = self.token,
            .repo = self.repo,
            .results = &results,
        };
        const prs_ctx = PrsThreadCtx{
            .allocator = self.allocator,
            .token = self.token,
            .repo = self.repo,
            .results = &results,
        };

        const releases_thread = try std.Thread.spawn(.{}, releasesThreadFn, .{releases_ctx});
        const prs_thread = try std.Thread.spawn(.{}, prsThreadFn, .{prs_ctx});

        releases_thread.join();
        prs_thread.join();

        // Check for errors — free any successfully fetched data before returning error
        if (results.releases_err) |err| {
            if (results.prs.len > 0) {
                // free prs using a temporary client for the free methods
                var tmp = GitHubApiClient.init(self.allocator, self.token, self.repo);
                defer tmp.deinit();
                tmp.freePullRequests(results.prs);
            }
            return err;
        }
        if (results.prs_err) |err| {
            if (results.releases.len > 0) {
                var tmp = GitHubApiClient.init(self.allocator, self.token, self.repo);
                defer tmp.deinit();
                tmp.freeReleases(results.releases);
            }
            return err;
        }

        return results;
    }
};

test "ParallelFetchResults default fields" {
    const r = ParallelFetchResults{};
    try std.testing.expect(r.releases.len == 0);
    try std.testing.expect(r.prs.len == 0);
    try std.testing.expect(r.releases_err == null);
    try std.testing.expect(r.prs_err == null);
}

test "copyLabel cleans up on allocation failure" {
    const src = models.Label{ .name = "bug", .color = "d73a4a" };
    // 2 allocations: name, color
    for (0..2) |i| {
        var fa = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = i });
        try std.testing.expectError(error.OutOfMemory, copyLabel(fa.allocator(), src));
    }
}

test "copyLabels cleans up on allocation failure" {
    const src = [_]models.Label{
        .{ .name = "bug", .color = "d73a4a" },
        .{ .name = "feature", .color = "0075ca" },
    };
    // 5 allocations: ArrayList backing, label[0].name, label[0].color, label[1].name, label[1].color
    for (0..5) |i| {
        var fa = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = i });
        try std.testing.expectError(error.OutOfMemory, copyLabels(fa.allocator(), &src));
    }
}

test "copyRelease cleans up on allocation failure" {
    const src = models.Release{
        .tag_name = "v1.0.0",
        .name = "Release 1.0.0",
        .published_at = "2024-01-01T00:00:00Z",
    };
    // 3 allocations: tag_name, name, published_at
    for (0..3) |i| {
        var fa = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = i });
        try std.testing.expectError(error.OutOfMemory, copyRelease(fa.allocator(), src));
    }
}

test "copyPullRequest cleans up on allocation failure" {
    var label = models.Label{ .name = "bug", .color = "d73a4a" };
    const src = models.PullRequest{
        .number = 1,
        .title = "Fix bug",
        .body = "PR body",
        .html_url = "https://github.com/owner/repo/pull/1",
        .user = .{ .login = "author", .html_url = "https://github.com/author" },
        .labels = @as([*]models.Label, @ptrCast(&label))[0..1],
        .merged_at = "2024-01-01T12:00:00Z",
    };
    // 9 allocations: title, body, html_url, user.login, user.html_url,
    //   labels backing, label.name, label.color, merged_at
    for (0..9) |i| {
        var fa = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = i });
        try std.testing.expectError(error.OutOfMemory, copyPullRequest(fa.allocator(), src));
    }
}

test "copyIssue cleans up on allocation failure" {
    var label = models.Label{ .name = "bug", .color = "d73a4a" };
    const src = models.Issue{
        .number = 1,
        .title = "Bug report",
        .body = "Issue body",
        .html_url = "https://github.com/owner/repo/issues/1",
        .user = .{ .login = "reporter", .html_url = "https://github.com/reporter" },
        .labels = @as([*]models.Label, @ptrCast(&label))[0..1],
    };
    // 8 allocations: title, body, html_url, user.login, user.html_url,
    //   labels backing, label.name, label.color
    for (0..8) |i| {
        var fa = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = i });
        try std.testing.expectError(error.OutOfMemory, copyIssue(fa.allocator(), src));
    }
}

