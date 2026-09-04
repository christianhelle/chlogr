const std = @import("std");
const github = @import("github/client.zig");
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
    const tag_name: ?[]const u8 = if (src.tag_name) |value| try allocator.dupe(u8, value) else null;
    errdefer if (tag_name) |value| allocator.free(value);
    const name: ?[]const u8 = if (src.name) |value| try allocator.dupe(u8, value) else null;
    errdefer if (name) |value| allocator.free(value);
    const published_at: ?[]const u8 = if (src.published_at) |value| try allocator.dupe(u8, value) else null;
    return .{ .tag_name = tag_name, .name = name, .published_at = published_at, .draft = src.draft };
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

fn copyIssuePullRequestRef(
    allocator: std.mem.Allocator,
    src: models.IssuePullRequestRef,
) !models.IssuePullRequestRef {
    const url: ?[]const u8 = if (src.url) |value| try allocator.dupe(u8, value) else null;
    return .{ .url = url };
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
    errdefer {
        for (labels) |l| {
            allocator.free(l.name);
            allocator.free(l.color);
        }
        allocator.free(labels);
    }
    const closed_at: ?[]const u8 = if (src.closed_at) |value| try allocator.dupe(u8, value) else null;
    errdefer if (closed_at) |value| allocator.free(value);
    const pull_request: ?models.IssuePullRequestRef = if (src.pull_request) |value|
        try copyIssuePullRequestRef(allocator, value)
    else
        null;
    errdefer if (pull_request) |value| if (value.url) |url| allocator.free(url);
    return .{
        .number = src.number,
        .title = title,
        .body = body,
        .html_url = html_url,
        .user = .{ .login = user_login, .html_url = user_html_url },
        .labels = labels,
        .closed_at = closed_at,
        .pull_request = pull_request,
    };
}

const github_api_base_url = "https://api.github.com";
const github_page_size: u32 = 100;
const github_page_size_usize: usize = @as(usize, github_page_size);

fn freeRelease(allocator: std.mem.Allocator, release: models.Release) void {
    if (release.tag_name) |value| allocator.free(value);
    if (release.name) |value| allocator.free(value);
    if (release.published_at) |value| allocator.free(value);
}

fn freePullRequest(allocator: std.mem.Allocator, pr: models.PullRequest) void {
    allocator.free(pr.title);
    if (pr.body) |body| allocator.free(body);
    allocator.free(pr.html_url);
    allocator.free(pr.user.login);
    allocator.free(pr.user.html_url);
    for (pr.labels) |label| {
        allocator.free(label.name);
        allocator.free(label.color);
    }
    allocator.free(pr.labels);
    if (pr.merged_at) |merged_at| allocator.free(merged_at);
}

fn freeIssue(allocator: std.mem.Allocator, issue: models.Issue) void {
    allocator.free(issue.title);
    if (issue.body) |body| allocator.free(body);
    allocator.free(issue.html_url);
    allocator.free(issue.user.login);
    allocator.free(issue.user.html_url);
    for (issue.labels) |label| {
        allocator.free(label.name);
        allocator.free(label.color);
    }
    allocator.free(issue.labels);
    if (issue.closed_at) |closed_at| allocator.free(closed_at);
    if (issue.pull_request) |pull_request| {
        if (pull_request.url) |url| allocator.free(url);
    }
}

fn freeReleaseSlice(allocator: std.mem.Allocator, releases: []models.Release) void {
    for (releases) |release| {
        freeRelease(allocator, release);
    }
    allocator.free(releases);
}

fn freePullRequestSlice(allocator: std.mem.Allocator, prs: []models.PullRequest) void {
    for (prs) |pr| {
        freePullRequest(allocator, pr);
    }
    allocator.free(prs);
}

fn freeIssueSlice(allocator: std.mem.Allocator, issues: []models.Issue) void {
    for (issues) |issue| {
        freeIssue(allocator, issue);
    }
    allocator.free(issues);
}

const PaginationStrategy = enum {
    single_page,
    sequential,
    bounded_parallel,
};

const PaginationPlan = struct {
    strategy: PaginationStrategy,
    worker_count: u32 = 0,
};

/// Pagination decisions use the raw parsed page count, not the post-filter item
/// count, so filtering drafts or pull-request markers never hides later pages.
/// The generated client does not expose response headers, so page counts are
/// discovered from page fullness: a short page is always the last one. When
/// parallel fetching is enabled, full pages are followed by speculative batches
/// of up to `degree_of_parallelism` concurrent page requests until a batch
/// contains the final short (or empty) page.
fn buildPaginationPlan(raw_page_count: usize, degree_of_parallelism: u32) PaginationPlan {
    if (raw_page_count < github_page_size_usize) {
        return .{ .strategy = .single_page };
    }

    if (degree_of_parallelism <= 1) {
        return .{ .strategy = .sequential };
    }

    return .{
        .strategy = .bounded_parallel,
        .worker_count = degree_of_parallelism,
    };
}

fn PageResult(comptime T: type) type {
    return struct {
        items: []T,
        raw_page_count: usize,
    };
}

fn ResourceOps(comptime T: type) type {
    return struct {
        fetchPage: *const fn (client: *GitHubApiClient, page: u32) anyerror!PageResult(T),
        freeSlice: *const fn (allocator: std.mem.Allocator, items: []T) void,
        freeElement: *const fn (allocator: std.mem.Allocator, item: T) void,
    };
}

pub const GitHubApiClient = struct {
    allocator: std.mem.Allocator,
    client: github.Client,
    owner: []const u8,
    repo_name: []const u8,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, token: []const u8, repo: []const u8) GitHubApiClient {
        var client = github.Client.init(allocator, io, token);
        client.withBaseUrl(github_api_base_url);
        const separator = std.mem.indexOfScalar(u8, repo, '/');
        return .{
            .allocator = allocator,
            .client = client,
            .owner = if (separator) |index| repo[0..index] else repo,
            .repo_name = if (separator) |index| repo[index + 1 ..] else repo,
        };
    }

    /// Fetch all releases/tags for the repository (paginated)
    pub fn getReleases(self: *GitHubApiClient) ![]models.Release {
        return self.getAllReleases(1);
    }

    /// Fetch merged pull requests (paginated)
    pub fn getMergedPullRequests(self: *GitHubApiClient) ![]models.PullRequest {
        return self.getAllPullRequests(1);
    }

    /// Fetch closed issues (paginated)
    pub fn getClosedIssues(self: *GitHubApiClient) ![]models.Issue {
        return self.getAllClosedIssues(1);
    }

    fn getAllReleases(self: *GitHubApiClient, degree_of_parallelism: u32) ![]models.Release {
        return self.getAll(models.Release, releases_ops, degree_of_parallelism);
    }

    fn getAllPullRequests(self: *GitHubApiClient, degree_of_parallelism: u32) ![]models.PullRequest {
        return self.getAll(models.PullRequest, pull_requests_ops, degree_of_parallelism);
    }

    fn getAllClosedIssues(self: *GitHubApiClient, degree_of_parallelism: u32) ![]models.Issue {
        return self.getAll(models.Issue, issues_ops, degree_of_parallelism);
    }

    const releases_ops = ResourceOps(models.Release){
        .fetchPage = fetchReleasePage,
        .freeSlice = freeReleaseSlice,
        .freeElement = freeRelease,
    };

    const pull_requests_ops = ResourceOps(models.PullRequest){
        .fetchPage = fetchPullRequestPage,
        .freeSlice = freePullRequestSlice,
        .freeElement = freePullRequest,
    };

    const issues_ops = ResourceOps(models.Issue){
        .fetchPage = fetchIssuePage,
        .freeSlice = freeIssueSlice,
        .freeElement = freeIssue,
    };

    fn getAll(
        self: *GitHubApiClient,
        comptime T: type,
        ops: ResourceOps(T),
        degree_of_parallelism: u32,
    ) ![]T {
        const first_page = try ops.fetchPage(self, 1);
        const plan = buildPaginationPlan(first_page.raw_page_count, degree_of_parallelism);

        return switch (plan.strategy) {
            .single_page => first_page.items,
            .sequential => self.fetchRemainingSequential(T, ops, first_page.items, 2),
            .bounded_parallel => self.fetchRemainingParallel(
                T,
                ops,
                first_page.items,
                2,
                plan.worker_count,
            ),
        };
    }

    fn fetchReleasePage(self: *GitHubApiClient, page: u32) !PageResult(models.Release) {
        std.debug.print("  Fetching releases page {d}...\n", .{page});
        var raw = try github.@"repos/list-releasesRaw"(
            &self.client,
            self.owner,
            self.repo_name,
            github_page_size,
            page,
        );
        defer raw.deinit();

        if (raw.status != .ok) {
            return error.GitHubApiError;
        }

        var parsed = try std.json.parseFromSlice(
            []models.Release,
            self.allocator,
            raw.body,
            .{ .ignore_unknown_fields = true },
        );
        defer parsed.deinit();

        return .{
            .items = try copyNonDraftReleases(self.allocator, parsed.value),
            .raw_page_count = parsed.value.len,
        };
    }

    fn fetchPullRequestPage(self: *GitHubApiClient, page: u32) !PageResult(models.PullRequest) {
        std.debug.print("  Fetching pull requests page {d}...\n", .{page});
        var raw = try github.@"pulls/listRaw"(
            &self.client,
            self.owner,
            self.repo_name,
            "closed",
            null,
            null,
            "updated",
            "desc",
            github_page_size,
            page,
        );
        defer raw.deinit();

        if (raw.status != .ok) {
            return error.GitHubApiError;
        }

        var parsed = try std.json.parseFromSlice(
            []models.PullRequest,
            self.allocator,
            raw.body,
            .{ .ignore_unknown_fields = true },
        );
        defer parsed.deinit();

        var prs = try std.ArrayList(models.PullRequest).initCapacity(
            self.allocator,
            parsed.value.len,
        );
        errdefer {
            for (prs.items) |pr| {
                freePullRequest(self.allocator, pr);
            }
            prs.deinit(self.allocator);
        }

        for (parsed.value) |pr| {
            prs.appendAssumeCapacity(try copyPullRequest(self.allocator, pr));
        }

        return .{
            .items = try prs.toOwnedSlice(self.allocator),
            .raw_page_count = parsed.value.len,
        };
    }

    fn fetchIssuePage(self: *GitHubApiClient, page: u32) !PageResult(models.Issue) {
        std.debug.print("  Fetching closed issues page {d}...\n", .{page});
        var raw = try github.@"issues/list-for-repoRaw"(
            &self.client,
            self.owner,
            self.repo_name,
            null,
            "closed",
            null,
            null,
            null,
            null,
            null,
            null,
            "updated",
            "desc",
            null,
            github_page_size,
            page,
        );
        defer raw.deinit();

        if (raw.status != .ok) {
            return error.GitHubApiError;
        }

        var parsed = try std.json.parseFromSlice(
            []models.Issue,
            self.allocator,
            raw.body,
            .{ .ignore_unknown_fields = true },
        );
        defer parsed.deinit();

        return .{
            .items = try copyClosedIssues(self.allocator, parsed.value),
            .raw_page_count = parsed.value.len,
        };
    }

    fn appendMovedPage(
        self: *GitHubApiClient,
        comptime T: type,
        ops: ResourceOps(T),
        items: *std.ArrayList(T),
        page_items: []T,
    ) !void {
        errdefer ops.freeSlice(self.allocator, page_items);

        try items.appendSlice(self.allocator, page_items);
        self.allocator.free(page_items);
    }

    fn fetchRemainingSequential(
        self: *GitHubApiClient,
        comptime T: type,
        ops: ResourceOps(T),
        first_page_items: []T,
        start_page: u32,
    ) ![]T {
        var items = try std.ArrayList(T).initCapacity(
            self.allocator,
            first_page_items.len,
        );
        errdefer {
            for (items.items) |item| {
                ops.freeElement(self.allocator, item);
            }
            items.deinit(self.allocator);
        }

        try self.appendMovedPage(T, ops, &items, first_page_items);

        var page = start_page;
        while (true) : (page += 1) {
            const page_result = try ops.fetchPage(self, page);
            const last_page = page_result.raw_page_count < github_page_size_usize;

            try self.appendMovedPage(T, ops, &items, page_result.items);

            if (last_page) break;
        }

        return try items.toOwnedSlice(self.allocator);
    }

    fn fetchRemainingParallel(
        self: *GitHubApiClient,
        comptime T: type,
        ops: ResourceOps(T),
        first_page_items: []T,
        start_page: u32,
        batch_size: u32,
    ) ![]T {
        const PageSlot = struct {
            items: ?[]T = null,
            raw_page_count: usize = 0,
            err: ?anyerror = null,
        };
        const Worker = struct {
            fn run(client: *GitHubApiClient, worker_ops: ResourceOps(T), page: u32, slot: *PageSlot) void {
                const result = worker_ops.fetchPage(client, page) catch |err| {
                    slot.* = .{ .err = err };
                    return;
                };
                slot.* = .{ .items = result.items, .raw_page_count = result.raw_page_count };
            }
        };

        var items = try std.ArrayList(T).initCapacity(
            self.allocator,
            first_page_items.len,
        );
        errdefer {
            for (items.items) |item| {
                ops.freeElement(self.allocator, item);
            }
            items.deinit(self.allocator);
        }

        try self.appendMovedPage(T, ops, &items, first_page_items);

        const batch_size_usize: usize = @intCast(batch_size);
        const slots = try self.allocator.alloc(PageSlot, batch_size_usize);
        defer self.allocator.free(slots);

        var next_page = start_page;
        while (true) {
            @memset(slots, .{});

            var threads = try std.ArrayList(std.Thread).initCapacity(
                self.allocator,
                batch_size_usize,
            );
            defer threads.deinit(self.allocator);

            for (0..batch_size_usize) |slot_index| {
                const page = next_page + @as(u32, @intCast(slot_index));
                const thread = std.Thread.spawn(.{}, Worker.run, .{ self, ops, page, &slots[slot_index] }) catch |err| {
                    for (threads.items) |started_thread| {
                        started_thread.join();
                    }
                    for (slots) |*slot| {
                        if (slot.items) |page_items| {
                            ops.freeSlice(self.allocator, page_items);
                        }
                    }
                    return err;
                };
                threads.appendAssumeCapacity(thread);
            }

            for (threads.items) |thread| {
                thread.join();
            }

            var reached_end = false;
            for (slots, 0..) |*slot, slot_index| {
                if (reached_end) {
                    // Pages past the first short page are beyond the end of the
                    // list; GitHub answers them with empty arrays.
                    if (slot.items) |page_items| {
                        ops.freeSlice(self.allocator, page_items);
                    }
                    continue;
                }

                if (slot.err) |err| {
                    for (slots[slot_index..]) |*rest| {
                        if (rest.items) |page_items| {
                            ops.freeSlice(self.allocator, page_items);
                        }
                    }
                    return err;
                }

                try self.appendMovedPage(T, ops, &items, slot.items.?);
                if (slot.raw_page_count < github_page_size_usize) {
                    reached_end = true;
                }
            }

            if (reached_end) break;
            next_page += batch_size;
        }

        return try items.toOwnedSlice(self.allocator);
    }

    pub fn deinit(self: *GitHubApiClient) void {
        self.client.deinit();
    }

    /// Free all allocated releases and their strings
    pub fn freeReleases(self: *GitHubApiClient, releases: []models.Release) void {
        freeReleaseSlice(self.allocator, releases);
    }

    /// Free all allocated PRs and their strings
    pub fn freePullRequests(self: *GitHubApiClient, prs: []models.PullRequest) void {
        freePullRequestSlice(self.allocator, prs);
    }

    /// Free all allocated issues and their strings
    pub fn freeIssues(self: *GitHubApiClient, issues: []models.Issue) void {
        freeIssueSlice(self.allocator, issues);
    }
};

fn copyClosedIssues(allocator: std.mem.Allocator, src: []const models.Issue) ![]models.Issue {
    var issues = try std.ArrayList(models.Issue).initCapacity(allocator, src.len);
    errdefer {
        for (issues.items) |issue| {
            freeIssue(allocator, issue);
        }
        issues.deinit(allocator);
    }

    for (src) |issue| {
        if (issue.pull_request != null) continue;
        issues.appendAssumeCapacity(try copyIssue(allocator, issue));
    }

    return try issues.toOwnedSlice(allocator);
}

fn copyNonDraftReleases(allocator: std.mem.Allocator, src: []const models.Release) ![]models.Release {
    var releases = try std.ArrayList(models.Release).initCapacity(allocator, src.len);
    errdefer {
        for (releases.items) |release| {
            freeRelease(allocator, release);
        }
        releases.deinit(allocator);
    }

    for (src) |release| {
        if (release.draft or release.published_at == null or release.tag_name == null) continue;
        releases.appendAssumeCapacity(try copyRelease(allocator, release));
    }

    return try releases.toOwnedSlice(allocator);
}

/// Results container for parallel fetch — fields written by threads, read by main after join
pub const ParallelFetchResults = struct {
    releases: []models.Release = &.{},
    prs: []models.PullRequest = &.{},
    issues: []models.Issue = &.{},
    releases_fetched: bool = false,
    prs_fetched: bool = false,
    issues_fetched: bool = false,
    releases_err: ?anyerror = null,
    prs_err: ?anyerror = null,
    issues_err: ?anyerror = null,
};

/// Context passed to each thread
const ReleasesThreadCtx = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    token: []const u8,
    repo: []const u8,
    degree_of_parallelism: u32,
    results: *ParallelFetchResults,
};

const PrsThreadCtx = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    token: []const u8,
    repo: []const u8,
    degree_of_parallelism: u32,
    results: *ParallelFetchResults,
};

const IssuesThreadCtx = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    token: []const u8,
    repo: []const u8,
    degree_of_parallelism: u32,
    results: *ParallelFetchResults,
};

fn releasesThreadFn(ctx: ReleasesThreadCtx) void {
    var client = GitHubApiClient.init(ctx.allocator, ctx.io, ctx.token, ctx.repo);
    defer client.deinit();
    ctx.results.releases = client.getAllReleases(ctx.degree_of_parallelism) catch |err| {
        ctx.results.releases_err = err;
        return;
    };
    ctx.results.releases_fetched = true;
}

fn prsThreadFn(ctx: PrsThreadCtx) void {
    var client = GitHubApiClient.init(ctx.allocator, ctx.io, ctx.token, ctx.repo);
    defer client.deinit();
    ctx.results.prs = client.getAllPullRequests(ctx.degree_of_parallelism) catch |err| {
        ctx.results.prs_err = err;
        return;
    };
    ctx.results.prs_fetched = true;
}

fn issuesThreadFn(ctx: IssuesThreadCtx) void {
    var client = GitHubApiClient.init(ctx.allocator, ctx.io, ctx.token, ctx.repo);
    defer client.deinit();
    ctx.results.issues = client.getAllClosedIssues(ctx.degree_of_parallelism) catch |err| {
        ctx.results.issues_err = err;
        return;
    };
    ctx.results.issues_fetched = true;
}

pub const ParallelFetcher = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    token: []const u8,
    repo: []const u8,
    degree_of_parallelism: u32,

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        token: []const u8,
        repo: []const u8,
        degree_of_parallelism: u32,
    ) ParallelFetcher {
        return .{
            .allocator = allocator,
            .io = io,
            .token = token,
            .repo = repo,
            .degree_of_parallelism = degree_of_parallelism,
        };
    }

    /// Fetch releases, pull requests, and issues concurrently. Caller owns the returned slices.
    /// On error, any successfully fetched data is freed before returning.
    pub fn fetch(self: *ParallelFetcher) !ParallelFetchResults {
        var results = ParallelFetchResults{};

        const releases_ctx = ReleasesThreadCtx{
            .allocator = self.allocator,
            .io = self.io,
            .token = self.token,
            .repo = self.repo,
            .degree_of_parallelism = self.degree_of_parallelism,
            .results = &results,
        };
        const prs_ctx = PrsThreadCtx{
            .allocator = self.allocator,
            .io = self.io,
            .token = self.token,
            .repo = self.repo,
            .degree_of_parallelism = self.degree_of_parallelism,
            .results = &results,
        };
        const issues_ctx = IssuesThreadCtx{
            .allocator = self.allocator,
            .io = self.io,
            .token = self.token,
            .repo = self.repo,
            .degree_of_parallelism = self.degree_of_parallelism,
            .results = &results,
        };

        const releases_thread = try std.Thread.spawn(.{}, releasesThreadFn, .{releases_ctx});
        const prs_thread = std.Thread.spawn(.{}, prsThreadFn, .{prs_ctx}) catch |err| {
            releases_thread.join();
            if (results.releases_fetched) {
                freeReleaseSlice(self.allocator, results.releases);
            }
            return err;
        };
        const issues_thread = std.Thread.spawn(.{}, issuesThreadFn, .{issues_ctx}) catch |err| {
            prs_thread.join();
            releases_thread.join();
            if (results.prs_fetched) {
                freePullRequestSlice(self.allocator, results.prs);
            }
            if (results.releases_fetched) {
                freeReleaseSlice(self.allocator, results.releases);
            }
            return err;
        };

        releases_thread.join();
        prs_thread.join();
        issues_thread.join();

        // Check for errors — free any successfully fetched data before returning error
        if (results.releases_err) |err| {
            if (results.prs_fetched) {
                freePullRequestSlice(self.allocator, results.prs);
            }
            if (results.issues_fetched) {
                freeIssueSlice(self.allocator, results.issues);
            }
            return err;
        }
        if (results.prs_err) |err| {
            if (results.releases_fetched) {
                freeReleaseSlice(self.allocator, results.releases);
            }
            if (results.issues_fetched) {
                freeIssueSlice(self.allocator, results.issues);
            }
            return err;
        }
        if (results.issues_err) |err| {
            if (results.releases_fetched) {
                freeReleaseSlice(self.allocator, results.releases);
            }
            if (results.prs_fetched) {
                freePullRequestSlice(self.allocator, results.prs);
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
    try std.testing.expect(r.issues.len == 0);
    try std.testing.expect(!r.releases_fetched);
    try std.testing.expect(!r.prs_fetched);
    try std.testing.expect(!r.issues_fetched);
    try std.testing.expect(r.releases_err == null);
    try std.testing.expect(r.prs_err == null);
    try std.testing.expect(r.issues_err == null);
}

test "buildPaginationPlan keeps a short page single-page" {
    const plan = buildPaginationPlan(github_page_size_usize - 1, 4);
    try std.testing.expectEqual(PaginationStrategy.single_page, plan.strategy);
    try std.testing.expectEqual(@as(u32, 0), plan.worker_count);
}

test "buildPaginationPlan paginates a full page sequentially without parallelism" {
    const plan = buildPaginationPlan(github_page_size_usize, 1);
    try std.testing.expectEqual(PaginationStrategy.sequential, plan.strategy);
    try std.testing.expectEqual(@as(u32, 0), plan.worker_count);
}

test "buildPaginationPlan batches a full page across parallel workers" {
    const plan = buildPaginationPlan(github_page_size_usize, 4);
    try std.testing.expectEqual(PaginationStrategy.bounded_parallel, plan.strategy);
    try std.testing.expectEqual(@as(u32, 4), plan.worker_count);
}

test "buildPaginationPlan uses the raw page count, not the filtered item count" {
    // A full page of drafts filters down to zero items; pagination must still
    // continue from the raw count, or later pages would never be fetched.
    const plan = buildPaginationPlan(github_page_size_usize, 4);
    try std.testing.expectEqual(PaginationStrategy.bounded_parallel, plan.strategy);
}

test "copyClosedIssues skips pull request entries" {
    const td = @import("test_data.zig");

    var parsed = try std.json.parseFromSlice(
        []models.Issue,
        std.testing.allocator,
        td.test_closed_issues_with_pull_request_marker,
        .{},
    );
    defer parsed.deinit();

    const issues = try copyClosedIssues(std.testing.allocator, parsed.value);
    defer freeIssueSlice(std.testing.allocator, issues);

    try std.testing.expectEqual(@as(usize, 2), issues.len);
    try std.testing.expectEqual(@as(u32, 910), issues[0].number);
    try std.testing.expectEqual(@as(u32, 912), issues[1].number);
    try std.testing.expectEqualStrings("2024-01-13T09:00:00Z", issues[0].closed_at.?);
}

test "copyNonDraftReleases skips draft releases" {
    const td = @import("test_data.zig");

    var parsed = try std.json.parseFromSlice(
        []models.Release,
        std.testing.allocator,
        td.test_releases_with_draft,
        .{},
    );
    defer parsed.deinit();

    const releases = try copyNonDraftReleases(std.testing.allocator, parsed.value);
    defer freeReleaseSlice(std.testing.allocator, releases);

    try std.testing.expectEqual(@as(usize, 1), releases.len);
    try std.testing.expectEqualStrings("0.3.6", releases[0].tag_name.?);
    try std.testing.expectEqualStrings("2026-03-20T17:14:17Z", releases[0].published_at.?);
    try std.testing.expect(!releases[0].draft);
}

test "copyNonDraftReleases cleans up on allocation failure" {
    const td = @import("test_data.zig");

    var parsed = try std.json.parseFromSlice(
        []models.Release,
        std.testing.allocator,
        td.test_releases_with_draft,
        .{},
    );
    defer parsed.deinit();

    // 5 allocation points: ArrayList backing, tag_name, name, published_at dupes,
    // then toOwnedSlice allocating a trimmed copy when drafts shrink the array.
    for (0..5) |i| {
        var fa = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = i });
        try std.testing.expectError(error.OutOfMemory, copyNonDraftReleases(fa.allocator(), parsed.value));
    }
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
    const pull_request = models.IssuePullRequestRef{
        .url = "https://api.github.com/repos/owner/repo/pulls/1",
    };
    const src = models.Issue{
        .number = 1,
        .title = "Bug report",
        .body = "Issue body",
        .html_url = "https://github.com/owner/repo/issues/1",
        .user = .{ .login = "reporter", .html_url = "https://github.com/reporter" },
        .labels = @as([*]models.Label, @ptrCast(&label))[0..1],
        .closed_at = "2024-01-01T12:00:00Z",
        .pull_request = pull_request,
    };
    // 10 allocations: title, body, html_url, user.login, user.html_url,
    //   labels backing, label.name, label.color, closed_at, pull_request.url
    for (0..10) |i| {
        var fa = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = i });
        try std.testing.expectError(error.OutOfMemory, copyIssue(fa.allocator(), src));
    }
}
