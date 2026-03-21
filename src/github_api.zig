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

const github_page_size: u32 = 100;
const github_page_size_usize: usize = @as(usize, github_page_size);

fn freeRelease(allocator: std.mem.Allocator, release: models.Release) void {
    allocator.free(release.tag_name);
    allocator.free(release.name);
    allocator.free(release.published_at);
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

const LinkRelation = enum {
    next,
    last,
};

const PaginationInfo = struct {
    header_present: bool = false,
    has_next: bool = false,
    last_page: ?u32 = null,
};

const PaginationStrategy = enum {
    single_page,
    sequential_fallback,
    bounded_parallel,
};

const PaginationPlan = struct {
    strategy: PaginationStrategy,
    total_pages: ?u32 = null,
    worker_count: u32 = 0,
};

const WorkerPageState = struct {
    total_pages: u32,
    next_page: u32 = 2,
    err: ?anyerror = null,
    mutex: std.Thread.Mutex = .{},

    fn claimNextPage(self: *WorkerPageState) ?u32 {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.err != null) return null;
        if (self.next_page > self.total_pages) return null;

        const page = self.next_page;
        self.next_page += 1;
        return page;
    }

    fn setError(self: *WorkerPageState, err: anyerror) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.err == null) {
            self.err = err;
        }
    }
};

fn linkRelationName(relation: LinkRelation) []const u8 {
    return switch (relation) {
        .next => "next",
        .last => "last",
    };
}

fn linkSegmentHasRelation(segment: []const u8, relation: LinkRelation) bool {
    var parts = std.mem.splitScalar(u8, segment, ';');
    _ = parts.next();

    const relation_name = linkRelationName(relation);
    while (parts.next()) |part| {
        const trimmed_part = std.mem.trim(u8, part, " \t");
        if (!std.ascii.startsWithIgnoreCase(trimmed_part, "rel=")) continue;

        var value = std.mem.trim(u8, trimmed_part[4..], " \t");
        if (value.len >= 2 and value[0] == '"' and value[value.len - 1] == '"') {
            value = value[1 .. value.len - 1];
        }

        var relations = std.mem.splitScalar(u8, value, ' ');
        while (relations.next()) |candidate| {
            if (std.ascii.eqlIgnoreCase(candidate, relation_name)) {
                return true;
            }
        }
    }

    return false;
}

fn linkHeaderHasRelation(link_header: ?[]const u8, relation: LinkRelation) bool {
    const header = link_header orelse return false;

    var links = std.mem.splitScalar(u8, header, ',');
    while (links.next()) |link| {
        if (linkSegmentHasRelation(std.mem.trim(u8, link, " \t"), relation)) {
            return true;
        }
    }

    return false;
}

fn parsePageQueryParameter(url: []const u8) ?u32 {
    const marker = "page=";
    var start: usize = 0;

    while (std.mem.indexOfPos(u8, url, start, marker)) |idx| {
        if (idx > 0) {
            const previous = url[idx - 1];
            if (previous != '?' and previous != '&') {
                start = idx + marker.len;
                continue;
            }
        }

        const remainder = url[idx + marker.len ..];
        if (remainder.len == 0) return null;

        var digits_len: usize = 0;
        while (digits_len < remainder.len and std.ascii.isDigit(remainder[digits_len])) : (digits_len += 1) {}
        if (digits_len == 0) return null;

        return std.fmt.parseUnsigned(u32, remainder[0..digits_len], 10) catch return null;
    }

    return null;
}

fn parseLinkHeaderPage(link_header: ?[]const u8, relation: LinkRelation) ?u32 {
    const header = link_header orelse return null;

    var links = std.mem.splitScalar(u8, header, ',');
    while (links.next()) |link| {
        const trimmed = std.mem.trim(u8, link, " \t");
        if (!linkSegmentHasRelation(trimmed, relation)) continue;

        const open_bracket = std.mem.indexOfScalar(u8, trimmed, '<') orelse continue;
        const url_and_rest = trimmed[open_bracket + 1 ..];
        const close_bracket = std.mem.indexOfScalar(u8, url_and_rest, '>') orelse continue;

        return parsePageQueryParameter(url_and_rest[0..close_bracket]);
    }

    return null;
}

fn parseLastPageFromLinkHeader(link_header: ?[]const u8) ?u32 {
    return parseLinkHeaderPage(link_header, .last);
}

fn parsePaginationInfo(link_header: ?[]const u8) PaginationInfo {
    return .{
        .header_present = link_header != null,
        .has_next = linkHeaderHasRelation(link_header, .next),
        .last_page = parseLastPageFromLinkHeader(link_header),
    };
}

fn buildPaginationPlan(
    pagination: PaginationInfo,
    item_count: usize,
    degree_of_parallelism: u32,
) PaginationPlan {
    if (pagination.last_page) |last_page| {
        if (last_page <= 1) {
            return .{
                .strategy = .single_page,
                .total_pages = 1,
            };
        }

        if (degree_of_parallelism <= 1) {
            return .{
                .strategy = .sequential_fallback,
                .total_pages = last_page,
            };
        }

        return .{
            .strategy = .bounded_parallel,
            .total_pages = last_page,
            .worker_count = @min(last_page - 1, degree_of_parallelism),
        };
    }

    if (pagination.header_present) {
        if (!pagination.has_next) {
            return .{
                .strategy = .single_page,
                .total_pages = 1,
            };
        }

        return .{
            .strategy = .sequential_fallback,
        };
    }

    if (item_count < github_page_size_usize) {
        return .{
            .strategy = .single_page,
            .total_pages = 1,
        };
    }

    return .{
        .strategy = .sequential_fallback,
    };
}

fn mergeOrderedPages(
    comptime T: type,
    allocator: std.mem.Allocator,
    first_page_items: []const T,
    remaining_page_items: []const ?[]T,
) ![]T {
    var total_len = first_page_items.len;
    for (remaining_page_items) |page_items| {
        if (page_items) |items| {
            total_len += items.len;
        }
    }

    const merged = try allocator.alloc(T, total_len);

    var offset: usize = 0;
    if (first_page_items.len > 0) {
        @memcpy(merged[offset .. offset + first_page_items.len], first_page_items);
        offset += first_page_items.len;
    }

    for (remaining_page_items) |page_items| {
        if (page_items) |items| {
            if (items.len == 0) continue;
            @memcpy(merged[offset .. offset + items.len], items);
            offset += items.len;
        }
    }

    return merged;
}

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

fn PageResult(comptime T: type) type {
    return struct {
        items: []T,
        pagination: PaginationInfo,
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
        const first_page = try self.fetchReleasePage(1);
        const plan = buildPaginationPlan(
            first_page.pagination,
            first_page.items.len,
            degree_of_parallelism,
        );

        return switch (plan.strategy) {
            .single_page => first_page.items,
            .sequential_fallback => self.fetchRemainingReleasesSequential(
                first_page.items,
                plan.total_pages,
                2,
            ),
            .bounded_parallel => self.fetchRemainingReleasesParallel(
                first_page.items,
                plan.total_pages.?,
                plan.worker_count,
            ),
        };
    }

    fn getAllPullRequests(self: *GitHubApiClient, degree_of_parallelism: u32) ![]models.PullRequest {
        const first_page = try self.fetchPullRequestPage(1);
        const plan = buildPaginationPlan(
            first_page.pagination,
            first_page.items.len,
            degree_of_parallelism,
        );

        return switch (plan.strategy) {
            .single_page => first_page.items,
            .sequential_fallback => self.fetchRemainingPullRequestsSequential(
                first_page.items,
                plan.total_pages,
                2,
            ),
            .bounded_parallel => self.fetchRemainingPullRequestsParallel(
                first_page.items,
                plan.total_pages.?,
                plan.worker_count,
            ),
        };
    }

    fn getAllClosedIssues(self: *GitHubApiClient, degree_of_parallelism: u32) ![]models.Issue {
        const first_page = try self.fetchIssuePage(1);
        const plan = buildPaginationPlan(
            first_page.pagination,
            first_page.items.len,
            degree_of_parallelism,
        );

        return switch (plan.strategy) {
            .single_page => first_page.items,
            .sequential_fallback => self.fetchRemainingIssuesSequential(
                first_page.items,
                plan.total_pages,
                2,
            ),
            .bounded_parallel => self.fetchRemainingIssuesParallel(
                first_page.items,
                plan.total_pages.?,
                plan.worker_count,
            ),
        };
    }

    fn buildReleasesEndpoint(self: *GitHubApiClient, page: u32) ![]u8 {
        return std.fmt.allocPrint(
            self.allocator,
            "/repos/{s}/releases?page={d}&per_page={d}",
            .{ self.repo, page, github_page_size },
        );
    }

    fn buildPullRequestsEndpoint(self: *GitHubApiClient, page: u32) ![]u8 {
        return std.fmt.allocPrint(
            self.allocator,
            "/repos/{s}/pulls?state=closed&page={d}&per_page={d}&sort=updated&direction=desc",
            .{ self.repo, page, github_page_size },
        );
    }

    fn buildIssuesEndpoint(self: *GitHubApiClient, page: u32) ![]u8 {
        return std.fmt.allocPrint(
            self.allocator,
            "/repos/{s}/issues?state=closed&page={d}&per_page={d}&sort=updated&direction=desc",
            .{ self.repo, page, github_page_size },
        );
    }

    fn fetchReleasePage(self: *GitHubApiClient, page: u32) !PageResult(models.Release) {
        std.debug.print("  Fetching releases page {d}...\n", .{page});
        const endpoint = try self.buildReleasesEndpoint(page);
        defer self.allocator.free(endpoint);

        const response = try self.http_client.get(endpoint);
        defer response.deinit(self.allocator);

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

        var releases = try std.ArrayList(models.Release).initCapacity(
            self.allocator,
            parsed.value.len,
        );
        errdefer {
            for (releases.items) |release| {
                freeRelease(self.allocator, release);
            }
            releases.deinit(self.allocator);
        }

        for (parsed.value) |release| {
            releases.appendAssumeCapacity(try copyRelease(self.allocator, release));
        }

        return .{
            .items = try releases.toOwnedSlice(self.allocator),
            .pagination = parsePaginationInfo(response.link_header),
        };
    }

    fn fetchPullRequestPage(self: *GitHubApiClient, page: u32) !PageResult(models.PullRequest) {
        std.debug.print("  Fetching pull requests page {d}...\n", .{page});
        const endpoint = try self.buildPullRequestsEndpoint(page);
        defer self.allocator.free(endpoint);

        const response = try self.http_client.get(endpoint);
        defer response.deinit(self.allocator);

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
            .pagination = parsePaginationInfo(response.link_header),
        };
    }

    fn fetchIssuePage(self: *GitHubApiClient, page: u32) !PageResult(models.Issue) {
        std.debug.print("  Fetching closed issues page {d}...\n", .{page});
        const endpoint = try self.buildIssuesEndpoint(page);
        defer self.allocator.free(endpoint);

        const response = try self.http_client.get(endpoint);
        defer response.deinit(self.allocator);

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

        return .{
            .items = try copyClosedIssues(self.allocator, parsed.value),
            .pagination = parsePaginationInfo(response.link_header),
        };
    }

    fn appendMovedReleasePage(
        self: *GitHubApiClient,
        releases: *std.ArrayList(models.Release),
        page_items: []models.Release,
    ) !void {
        errdefer freeReleaseSlice(self.allocator, page_items);

        try releases.appendSlice(self.allocator, page_items);
        self.allocator.free(page_items);
    }

    fn appendMovedPullRequestPage(
        self: *GitHubApiClient,
        prs: *std.ArrayList(models.PullRequest),
        page_items: []models.PullRequest,
    ) !void {
        errdefer freePullRequestSlice(self.allocator, page_items);

        try prs.appendSlice(self.allocator, page_items);
        self.allocator.free(page_items);
    }

    fn appendMovedIssuePage(
        self: *GitHubApiClient,
        issues: *std.ArrayList(models.Issue),
        page_items: []models.Issue,
    ) !void {
        errdefer freeIssueSlice(self.allocator, page_items);

        try issues.appendSlice(self.allocator, page_items);
        self.allocator.free(page_items);
    }

    fn fetchRemainingReleasesSequential(
        self: *GitHubApiClient,
        first_page_items: []models.Release,
        initial_last_page: ?u32,
        start_page: u32,
    ) ![]models.Release {
        var releases = try std.ArrayList(models.Release).initCapacity(
            self.allocator,
            first_page_items.len,
        );
        errdefer {
            for (releases.items) |release| {
                freeRelease(self.allocator, release);
            }
            releases.deinit(self.allocator);
        }

        try self.appendMovedReleasePage(&releases, first_page_items);

        var last_page = initial_last_page;
        var page = start_page;
        while (true) : (page += 1) {
            if (last_page) |known_last| {
                if (page > known_last) break;
            }

            const page_result = try self.fetchReleasePage(page);
            const page_len = page_result.items.len;
            const pagination = page_result.pagination;

            if (pagination.last_page) |discovered_last_page| {
                last_page = discovered_last_page;
            }

            try self.appendMovedReleasePage(&releases, page_result.items);

            if (last_page) |known_last| {
                if (page >= known_last) break;
            } else if (pagination.header_present) {
                if (!pagination.has_next) break;
            } else if (page_len < github_page_size_usize) {
                break;
            }
        }

        return try releases.toOwnedSlice(self.allocator);
    }

    fn fetchRemainingPullRequestsSequential(
        self: *GitHubApiClient,
        first_page_items: []models.PullRequest,
        initial_last_page: ?u32,
        start_page: u32,
    ) ![]models.PullRequest {
        var prs = try std.ArrayList(models.PullRequest).initCapacity(
            self.allocator,
            first_page_items.len,
        );
        errdefer {
            for (prs.items) |pr| {
                freePullRequest(self.allocator, pr);
            }
            prs.deinit(self.allocator);
        }

        try self.appendMovedPullRequestPage(&prs, first_page_items);

        var last_page = initial_last_page;
        var page = start_page;
        while (true) : (page += 1) {
            if (last_page) |known_last| {
                if (page > known_last) break;
            }

            const page_result = try self.fetchPullRequestPage(page);
            const page_len = page_result.items.len;
            const pagination = page_result.pagination;

            if (pagination.last_page) |discovered_last_page| {
                last_page = discovered_last_page;
            }

            try self.appendMovedPullRequestPage(&prs, page_result.items);

            if (last_page) |known_last| {
                if (page >= known_last) break;
            } else if (pagination.header_present) {
                if (!pagination.has_next) break;
            } else if (page_len < github_page_size_usize) {
                break;
            }
        }

        return try prs.toOwnedSlice(self.allocator);
    }

    fn fetchRemainingIssuesSequential(
        self: *GitHubApiClient,
        first_page_items: []models.Issue,
        initial_last_page: ?u32,
        start_page: u32,
    ) ![]models.Issue {
        var issues = try std.ArrayList(models.Issue).initCapacity(
            self.allocator,
            first_page_items.len,
        );
        errdefer {
            for (issues.items) |issue| {
                freeIssue(self.allocator, issue);
            }
            issues.deinit(self.allocator);
        }

        try self.appendMovedIssuePage(&issues, first_page_items);

        var last_page = initial_last_page;
        var page = start_page;
        while (true) : (page += 1) {
            if (last_page) |known_last| {
                if (page > known_last) break;
            }

            const page_result = try self.fetchIssuePage(page);
            const page_len = page_result.items.len;
            const pagination = page_result.pagination;

            if (pagination.last_page) |discovered_last_page| {
                last_page = discovered_last_page;
            }

            try self.appendMovedIssuePage(&issues, page_result.items);

            if (last_page) |known_last| {
                if (page >= known_last) break;
            } else if (pagination.header_present) {
                if (!pagination.has_next) break;
            } else if (page_len < github_page_size_usize) {
                break;
            }
        }

        return try issues.toOwnedSlice(self.allocator);
    }

    fn fetchRemainingReleasesParallel(
        self: *GitHubApiClient,
        first_page_items: []models.Release,
        total_pages: u32,
        worker_count: u32,
    ) ![]models.Release {
        const remaining_pages: usize = @intCast(total_pages - 1);
        const page_slots = try self.allocator.alloc(?[]models.Release, remaining_pages);
        defer self.allocator.free(page_slots);
        @memset(page_slots, null);

        errdefer freeReleaseSlice(self.allocator, first_page_items);
        errdefer {
            for (page_slots) |page_items| {
                if (page_items) |items| {
                    freeReleaseSlice(self.allocator, items);
                }
            }
        }

        var state = WorkerPageState{ .total_pages = total_pages };
        var threads = try std.ArrayList(std.Thread).initCapacity(
            self.allocator,
            @intCast(worker_count),
        );
        defer threads.deinit(self.allocator);

        const worker_count_usize: usize = @intCast(worker_count);
        var worker_index: usize = 0;
        while (worker_index < worker_count_usize) : (worker_index += 1) {
            const ctx = ReleasesPaginationWorkerCtx{
                .allocator = self.allocator,
                .token = self.http_client.token,
                .repo = self.repo,
                .state = &state,
                .page_slots = page_slots,
            };
            const thread = std.Thread.spawn(.{}, releasesPaginationWorkerFn, .{ctx}) catch |err| {
                for (threads.items) |started_thread| {
                    started_thread.join();
                }
                return err;
            };
            threads.appendAssumeCapacity(thread);
        }

        for (threads.items) |thread| {
            thread.join();
        }

        if (state.err) |err| {
            return err;
        }

        for (page_slots) |page_items| {
            if (page_items == null) return error.IncompletePagination;
        }

        const merged = try mergeOrderedPages(
            models.Release,
            self.allocator,
            first_page_items,
            page_slots,
        );
        self.allocator.free(first_page_items);
        for (page_slots) |page_items| {
            self.allocator.free(page_items.?);
        }
        return merged;
    }

    fn fetchRemainingPullRequestsParallel(
        self: *GitHubApiClient,
        first_page_items: []models.PullRequest,
        total_pages: u32,
        worker_count: u32,
    ) ![]models.PullRequest {
        const remaining_pages: usize = @intCast(total_pages - 1);
        const page_slots = try self.allocator.alloc(?[]models.PullRequest, remaining_pages);
        defer self.allocator.free(page_slots);
        @memset(page_slots, null);

        errdefer freePullRequestSlice(self.allocator, first_page_items);
        errdefer {
            for (page_slots) |page_items| {
                if (page_items) |items| {
                    freePullRequestSlice(self.allocator, items);
                }
            }
        }

        var state = WorkerPageState{ .total_pages = total_pages };
        var threads = try std.ArrayList(std.Thread).initCapacity(
            self.allocator,
            @intCast(worker_count),
        );
        defer threads.deinit(self.allocator);

        const worker_count_usize: usize = @intCast(worker_count);
        var worker_index: usize = 0;
        while (worker_index < worker_count_usize) : (worker_index += 1) {
            const ctx = PullRequestsPaginationWorkerCtx{
                .allocator = self.allocator,
                .token = self.http_client.token,
                .repo = self.repo,
                .state = &state,
                .page_slots = page_slots,
            };
            const thread = std.Thread.spawn(.{}, pullRequestsPaginationWorkerFn, .{ctx}) catch |err| {
                for (threads.items) |started_thread| {
                    started_thread.join();
                }
                return err;
            };
            threads.appendAssumeCapacity(thread);
        }

        for (threads.items) |thread| {
            thread.join();
        }

        if (state.err) |err| {
            return err;
        }

        for (page_slots) |page_items| {
            if (page_items == null) return error.IncompletePagination;
        }

        const merged = try mergeOrderedPages(
            models.PullRequest,
            self.allocator,
            first_page_items,
            page_slots,
        );
        self.allocator.free(first_page_items);
        for (page_slots) |page_items| {
            self.allocator.free(page_items.?);
        }
        return merged;
    }

    fn fetchRemainingIssuesParallel(
        self: *GitHubApiClient,
        first_page_items: []models.Issue,
        total_pages: u32,
        worker_count: u32,
    ) ![]models.Issue {
        const remaining_pages: usize = @intCast(total_pages - 1);
        const page_slots = try self.allocator.alloc(?[]models.Issue, remaining_pages);
        defer self.allocator.free(page_slots);
        @memset(page_slots, null);

        errdefer freeIssueSlice(self.allocator, first_page_items);
        errdefer {
            for (page_slots) |page_items| {
                if (page_items) |items| {
                    freeIssueSlice(self.allocator, items);
                }
            }
        }

        var state = WorkerPageState{ .total_pages = total_pages };
        var threads = try std.ArrayList(std.Thread).initCapacity(
            self.allocator,
            @intCast(worker_count),
        );
        defer threads.deinit(self.allocator);

        const worker_count_usize: usize = @intCast(worker_count);
        var worker_index: usize = 0;
        while (worker_index < worker_count_usize) : (worker_index += 1) {
            const ctx = IssuesPaginationWorkerCtx{
                .allocator = self.allocator,
                .token = self.http_client.token,
                .repo = self.repo,
                .state = &state,
                .page_slots = page_slots,
            };
            const thread = std.Thread.spawn(.{}, issuesPaginationWorkerFn, .{ctx}) catch |err| {
                for (threads.items) |started_thread| {
                    started_thread.join();
                }
                return err;
            };
            threads.appendAssumeCapacity(thread);
        }

        for (threads.items) |thread| {
            thread.join();
        }

        if (state.err) |err| {
            return err;
        }

        for (page_slots) |page_items| {
            if (page_items == null) return error.IncompletePagination;
        }

        const merged = try mergeOrderedPages(
            models.Issue,
            self.allocator,
            first_page_items,
            page_slots,
        );
        self.allocator.free(first_page_items);
        for (page_slots) |page_items| {
            self.allocator.free(page_items.?);
        }
        return merged;
    }

    pub fn deinit(self: *GitHubApiClient) void {
        self.http_client.deinit();
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
    token: []const u8,
    repo: []const u8,
    degree_of_parallelism: u32,
    results: *ParallelFetchResults,
};

const PrsThreadCtx = struct {
    allocator: std.mem.Allocator,
    token: []const u8,
    repo: []const u8,
    degree_of_parallelism: u32,
    results: *ParallelFetchResults,
};

const IssuesThreadCtx = struct {
    allocator: std.mem.Allocator,
    token: []const u8,
    repo: []const u8,
    degree_of_parallelism: u32,
    results: *ParallelFetchResults,
};

const ReleasesPaginationWorkerCtx = struct {
    allocator: std.mem.Allocator,
    token: []const u8,
    repo: []const u8,
    state: *WorkerPageState,
    page_slots: []?[]models.Release,
};

const PullRequestsPaginationWorkerCtx = struct {
    allocator: std.mem.Allocator,
    token: []const u8,
    repo: []const u8,
    state: *WorkerPageState,
    page_slots: []?[]models.PullRequest,
};

const IssuesPaginationWorkerCtx = struct {
    allocator: std.mem.Allocator,
    token: []const u8,
    repo: []const u8,
    state: *WorkerPageState,
    page_slots: []?[]models.Issue,
};

fn releasesThreadFn(ctx: ReleasesThreadCtx) void {
    var client = GitHubApiClient.init(ctx.allocator, ctx.token, ctx.repo);
    defer client.deinit();
    ctx.results.releases = client.getAllReleases(ctx.degree_of_parallelism) catch |err| {
        ctx.results.releases_err = err;
        return;
    };
    ctx.results.releases_fetched = true;
}

fn prsThreadFn(ctx: PrsThreadCtx) void {
    var client = GitHubApiClient.init(ctx.allocator, ctx.token, ctx.repo);
    defer client.deinit();
    ctx.results.prs = client.getAllPullRequests(ctx.degree_of_parallelism) catch |err| {
        ctx.results.prs_err = err;
        return;
    };
    ctx.results.prs_fetched = true;
}

fn issuesThreadFn(ctx: IssuesThreadCtx) void {
    var client = GitHubApiClient.init(ctx.allocator, ctx.token, ctx.repo);
    defer client.deinit();
    ctx.results.issues = client.getAllClosedIssues(ctx.degree_of_parallelism) catch |err| {
        ctx.results.issues_err = err;
        return;
    };
    ctx.results.issues_fetched = true;
}

fn releasesPaginationWorkerFn(ctx: ReleasesPaginationWorkerCtx) void {
    var client = GitHubApiClient.init(ctx.allocator, ctx.token, ctx.repo);
    defer client.deinit();

    while (true) {
        const page = ctx.state.claimNextPage() orelse return;
        const page_result = client.fetchReleasePage(page) catch |err| {
            ctx.state.setError(err);
            return;
        };

        const slot_index: usize = @intCast(page - 2);
        ctx.page_slots[slot_index] = page_result.items;
    }
}

fn pullRequestsPaginationWorkerFn(ctx: PullRequestsPaginationWorkerCtx) void {
    var client = GitHubApiClient.init(ctx.allocator, ctx.token, ctx.repo);
    defer client.deinit();

    while (true) {
        const page = ctx.state.claimNextPage() orelse return;
        const page_result = client.fetchPullRequestPage(page) catch |err| {
            ctx.state.setError(err);
            return;
        };

        const slot_index: usize = @intCast(page - 2);
        ctx.page_slots[slot_index] = page_result.items;
    }
}

fn issuesPaginationWorkerFn(ctx: IssuesPaginationWorkerCtx) void {
    var client = GitHubApiClient.init(ctx.allocator, ctx.token, ctx.repo);
    defer client.deinit();

    while (true) {
        const page = ctx.state.claimNextPage() orelse return;
        const page_result = client.fetchIssuePage(page) catch |err| {
            ctx.state.setError(err);
            return;
        };

        const slot_index: usize = @intCast(page - 2);
        ctx.page_slots[slot_index] = page_result.items;
    }
}

pub const ParallelFetcher = struct {
    allocator: std.mem.Allocator,
    token: []const u8,
    repo: []const u8,
    degree_of_parallelism: u32,

    pub fn init(
        allocator: std.mem.Allocator,
        token: []const u8,
        repo: []const u8,
        degree_of_parallelism: u32,
    ) ParallelFetcher {
        return .{
            .allocator = allocator,
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
            .token = self.token,
            .repo = self.repo,
            .degree_of_parallelism = self.degree_of_parallelism,
            .results = &results,
        };
        const prs_ctx = PrsThreadCtx{
            .allocator = self.allocator,
            .token = self.token,
            .repo = self.repo,
            .degree_of_parallelism = self.degree_of_parallelism,
            .results = &results,
        };
        const issues_ctx = IssuesThreadCtx{
            .allocator = self.allocator,
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

test "parseLastPageFromLinkHeader extracts last PR page" {
    const td = @import("test_data.zig");

    try std.testing.expectEqual(@as(?u32, 4), parseLastPageFromLinkHeader(td.test_prs_link_header_last_page));
}

test "parseLastPageFromLinkHeader returns null when last relation is missing" {
    const td = @import("test_data.zig");

    try std.testing.expectEqual(@as(?u32, null), parseLastPageFromLinkHeader(td.test_prs_link_header_next_only));
}

test "parseLastPageFromLinkHeader returns null for malformed last page" {
    const td = @import("test_data.zig");

    try std.testing.expectEqual(@as(?u32, null), parseLastPageFromLinkHeader(td.test_prs_link_header_malformed_last));
}

test "parseLastPageFromLinkHeader handles multiple release relations" {
    const td = @import("test_data.zig");

    try std.testing.expectEqual(@as(?u32, 3), parseLastPageFromLinkHeader(td.test_releases_link_header_multiple_relations));
}

test "buildPaginationPlan bounds PR workers and avoids speculative pages" {
    const td = @import("test_data.zig");
    const plan = buildPaginationPlan(
        parsePaginationInfo(td.test_prs_link_header_last_page),
        github_page_size_usize,
        8,
    );

    try std.testing.expectEqual(PaginationStrategy.bounded_parallel, plan.strategy);
    try std.testing.expectEqual(@as(?u32, 4), plan.total_pages);
    try std.testing.expectEqual(@as(u32, 3), plan.worker_count);
}

test "buildPaginationPlan falls back sequentially without last page metadata" {
    const td = @import("test_data.zig");
    const plan = buildPaginationPlan(
        parsePaginationInfo(td.test_prs_link_header_next_only),
        github_page_size_usize,
        4,
    );

    try std.testing.expectEqual(PaginationStrategy.sequential_fallback, plan.strategy);
    try std.testing.expectEqual(@as(?u32, null), plan.total_pages);
    try std.testing.expectEqual(@as(u32, 0), plan.worker_count);
}

test "buildPaginationPlan keeps releases single-page without pagination links" {
    const plan = buildPaginationPlan(.{}, 42, 4);

    try std.testing.expectEqual(PaginationStrategy.single_page, plan.strategy);
    try std.testing.expectEqual(@as(?u32, 1), plan.total_pages);
    try std.testing.expectEqual(@as(u32, 0), plan.worker_count);
}

test "buildPaginationPlan falls back when a full page has no link metadata" {
    const plan = buildPaginationPlan(.{}, github_page_size_usize, 4);

    try std.testing.expectEqual(PaginationStrategy.sequential_fallback, plan.strategy);
    try std.testing.expectEqual(@as(?u32, null), plan.total_pages);
    try std.testing.expectEqual(@as(u32, 0), plan.worker_count);
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

test "mergeOrderedPages preserves PR ordering across page slots" {
    const allocator = std.testing.allocator;
    var first_page_items = [_]u32{ 101, 102 };
    var second_page_items = [_]u32{ 201, 202 };
    var third_page_items = [_]u32{301};
    const remaining_page_items = [_]?[]u32{
        second_page_items[0..],
        third_page_items[0..],
    };

    const merged = try mergeOrderedPages(
        u32,
        allocator,
        first_page_items[0..],
        &remaining_page_items,
    );
    defer allocator.free(merged);

    try std.testing.expectEqualSlices(u32, &[_]u32{ 101, 102, 201, 202, 301 }, merged);
}

test "mergeOrderedPages preserves release ordering across page slots" {
    const allocator = std.testing.allocator;
    var first_page_items = [_]u32{1};
    var second_page_items = [_]u32{2};
    var third_page_items = [_]u32{3};
    const remaining_page_items = [_]?[]u32{
        second_page_items[0..],
        third_page_items[0..],
    };

    const merged = try mergeOrderedPages(
        u32,
        allocator,
        first_page_items[0..],
        &remaining_page_items,
    );
    defer allocator.free(merged);

    try std.testing.expectEqualSlices(u32, &[_]u32{ 1, 2, 3 }, merged);
}

test "mergeOrderedPages cleans up on allocation failure" {
    var first_page_items = [_]u32{ 1, 2 };
    var second_page_items = [_]u32{ 3, 4 };
    var third_page_items = [_]u32{5};
    const remaining_page_items = [_]?[]u32{
        second_page_items[0..],
        third_page_items[0..],
    };

    var fa = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(
        error.OutOfMemory,
        mergeOrderedPages(u32, fa.allocator(), first_page_items[0..], &remaining_page_items),
    );
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
