const std = @import("std");
const models = @import("models.zig");

pub const ChangelogEntry = struct {
    title: []const u8,
    url: []const u8,
    author: []const u8,
    number: u32,
};

pub const ChangelogSection = struct {
    name: []const u8,
    entries: []ChangelogEntry,
};

pub const ChangelogRelease = struct {
    version: []const u8,
    date: []const u8,
    sections: []ChangelogSection,
};

pub const UnreleasedChanges = struct {
    sections: []ChangelogSection,
};

pub const Changelog = struct {
    releases: []ChangelogRelease,
    unreleased: ?UnreleasedChanges,
};

const closed_issues_section_name = "Closed Issues";
const section_order = [_][]const u8{
    "Merged Pull Requests",
    "Features",
    "Bug Fixes",
    closed_issues_section_name,
};

pub const ChangelogGenerator = struct {
    allocator: std.mem.Allocator,
    exclude_labels: ?[]const u8 = null,
    since_tag: ?[]const u8 = null,
    until_tag: ?[]const u8 = null,

    pub fn init(allocator: std.mem.Allocator, exclude_labels: ?[]const u8) ChangelogGenerator {
        return ChangelogGenerator{
            .allocator = allocator,
            .exclude_labels = exclude_labels,
        };
    }

    /// Filter releases to the inclusive range [since_tag, until_tag].
    /// Releases are assumed to be ordered newest-first (as returned by the GitHub API).
    /// Returns error.SinceTagNotFound or error.UntilTagNotFound when a requested tag
    /// does not exist in the provided releases slice.
    fn filterReleasesByTagRange(self: ChangelogGenerator, releases: []models.Release) ![]models.Release {
        const want_since = self.since_tag != null;
        const want_until = self.until_tag != null;
        if (!want_since and !want_until) return releases;

        var since_idx: ?usize = null;
        var until_idx: ?usize = null;

        for (releases, 0..) |release, i| {
            if (want_since and since_idx == null) {
                if (std.mem.eql(u8, release.tag_name, self.since_tag.?)) {
                    since_idx = i;
                }
            }
            if (want_until and until_idx == null) {
                if (std.mem.eql(u8, release.tag_name, self.until_tag.?)) {
                    until_idx = i;
                }
            }
        }

        if (want_since and since_idx == null) return error.SinceTagNotFound;
        if (want_until and until_idx == null) return error.UntilTagNotFound;

        const lo = blk: {
            if (since_idx != null and until_idx != null) {
                break :blk @min(since_idx.?, until_idx.?);
            } else if (until_idx != null) {
                break :blk @as(usize, 0);
            } else {
                break :blk since_idx.?;
            }
        };

        const hi = blk: {
            if (since_idx != null and until_idx != null) {
                break :blk @max(since_idx.?, until_idx.?) + 1;
            } else if (since_idx != null) {
                break :blk releases.len;
            } else {
                break :blk until_idx.? + 1;
            }
        };

        return releases[lo..hi];
    }

    /// Check if an entry should be excluded based on labels.
    /// The exclude_labels string is a comma-separated list of tokens; each token is
    /// trimmed of whitespace and compared against entry label names using exact equality.
    fn shouldExclude(self: ChangelogGenerator, labels: []models.Label) bool {
        if (self.exclude_labels == null) return false;

        const exclude = self.exclude_labels.?;
        var token_it = std.mem.splitScalar(u8, exclude, ',');
        while (token_it.next()) |raw_token| {
            const token = std.mem.trim(u8, raw_token, " \t");
            if (token.len == 0) continue;
            for (labels) |label| {
                if (std.mem.eql(u8, label.name, token)) {
                    return true;
                }
            }
        }
        return false;
    }

    /// Categorize pull requests based on labels.
    fn categorizeEntry(_: ChangelogGenerator, labels: []models.Label) []const u8 {
        for (labels) |label| {
            if (std.mem.eql(u8, label.name, "feature") or std.mem.eql(u8, label.name, "enhancement")) {
                return "Features";
            } else if (std.mem.eql(u8, label.name, "bug") or std.mem.eql(u8, label.name, "bugfix")) {
                return "Bug Fixes";
            }
        }
        return "Merged Pull Requests";
    }

    fn releaseOldestFirst(_: void, a: models.Release, b: models.Release) bool {
        return std.mem.lessThan(u8, a.published_at, b.published_at);
    }

    fn appendSectionEntry(
        self: ChangelogGenerator,
        sections_map: *std.StringHashMap(std.ArrayListUnmanaged(ChangelogEntry)),
        section_name: []const u8,
        entry: ChangelogEntry,
    ) !void {
        var gop = try sections_map.getOrPut(section_name);
        if (!gop.found_existing) {
            gop.value_ptr.* = .empty;
        }

        try gop.value_ptr.append(self.allocator, entry);
    }

    fn buildSections(
        self: ChangelogGenerator,
        sections_map: *std.StringHashMap(std.ArrayListUnmanaged(ChangelogEntry)),
    ) ![]ChangelogSection {
        var sections_array = try std.ArrayList(ChangelogSection).initCapacity(
            self.allocator,
            sections_map.count(),
        );
        errdefer {
            for (sections_array.items) |section| {
                self.allocator.free(section.entries);
            }
            sections_array.deinit(self.allocator);
        }

        inline for (section_order) |section_name| {
            if (sections_map.getPtr(section_name)) |entries| {
                sections_array.appendAssumeCapacity(.{
                    .name = section_name,
                    .entries = try entries.toOwnedSlice(self.allocator),
                });
            }
        }

        return try sections_array.toOwnedSlice(self.allocator);
    }

    fn shouldSkipIssue(self: ChangelogGenerator, issue: models.Issue) bool {
        return self.shouldExclude(issue.labels) or issue.pull_request != null;
    }

    /// Generate changelog from releases and PRs.
    /// Each PR is assigned to exactly one release: the earliest release whose
    /// published_at >= pr.merged_at (full ISO 8601 lexicographic comparison).
    /// PRs with no qualifying release go to unreleased.
    pub fn generate(
        self: ChangelogGenerator,
        releases: []models.Release,
        prs: []models.PullRequest,
    ) !Changelog {
        return self.generateWithIssues(releases, prs, &[_]models.Issue{});
    }

    /// Generate changelog from releases, pull requests, and closed issues.
    /// Issues are assigned to the earliest release whose published_at >= issue.closed_at.
    /// Issues without a qualifying release are omitted so unreleased output remains PR-only.
    pub fn generateWithIssues(
        self: ChangelogGenerator,
        releases: []models.Release,
        prs: []models.PullRequest,
        issues: []models.Issue,
    ) !Changelog {
        // Apply tag-range filter before assignment so --since-tag/--until-tag
        // restrict which releases are considered.
        const filtered = try self.filterReleasesByTagRange(releases);

        // Sort releases oldest-first so a greedy single pass assigns each PR/issue to
        // the earliest qualifying release. The result is reversed at the end so
        // releases appear newest-first in the output.
        const sorted = try self.allocator.dupe(models.Release, filtered);
        defer self.allocator.free(sorted);
        std.mem.sort(models.Release, sorted, {}, releaseOldestFirst);

        const assigned_prs = try self.allocator.alloc(bool, prs.len);
        defer self.allocator.free(assigned_prs);
        @memset(assigned_prs, false);

        const assigned_issues = try self.allocator.alloc(bool, issues.len);
        defer self.allocator.free(assigned_issues);
        @memset(assigned_issues, false);

        var result = try std.ArrayList(ChangelogRelease).initCapacity(self.allocator, sorted.len);
        errdefer {
            for (result.items) |release| {
                for (release.sections) |section| {
                    self.allocator.free(section.entries);
                }
                self.allocator.free(release.sections);
            }
            result.deinit(self.allocator);
        }

        for (sorted) |release| {
            var sections_map = std.StringHashMap(std.ArrayListUnmanaged(ChangelogEntry)).init(self.allocator);
            try sections_map.ensureTotalCapacity(4);
            defer {
                var it = sections_map.iterator();
                while (it.next()) |entry| {
                    entry.value_ptr.deinit(self.allocator);
                }
                sections_map.deinit();
            }

            for (prs, 0..) |pr, i| {
                if (assigned_prs[i]) continue;
                if (self.shouldExclude(pr.labels)) continue;
                const merged_at = pr.merged_at orelse continue;
                if (std.mem.order(u8, merged_at, release.published_at) == .gt) continue;

                assigned_prs[i] = true;
                try self.appendSectionEntry(&sections_map, self.categorizeEntry(pr.labels), .{
                    .title = pr.title,
                    .url = pr.html_url,
                    .author = pr.user.login,
                    .number = pr.number,
                });
            }

            for (issues, 0..) |issue, i| {
                if (assigned_issues[i]) continue;
                if (self.shouldSkipIssue(issue)) continue;
                const closed_at = issue.closed_at orelse continue;
                if (std.mem.order(u8, closed_at, release.published_at) == .gt) continue;

                assigned_issues[i] = true;
                try self.appendSectionEntry(&sections_map, closed_issues_section_name, .{
                    .title = issue.title,
                    .url = issue.html_url,
                    .author = issue.user.login,
                    .number = issue.number,
                });
            }

            result.appendAssumeCapacity(.{
                .version = release.tag_name,
                .date = release.published_at,
                .sections = try self.buildSections(&sections_map),
            });
        }

        std.mem.reverse(ChangelogRelease, result.items);

        var unreleased_sections_map = std.StringHashMap(std.ArrayListUnmanaged(ChangelogEntry)).init(self.allocator);
        try unreleased_sections_map.ensureTotalCapacity(3);
        defer {
            var it = unreleased_sections_map.iterator();
            while (it.next()) |entry| {
                entry.value_ptr.deinit(self.allocator);
            }
            unreleased_sections_map.deinit();
        }

        var has_unreleased = false;
        for (prs, 0..) |pr, i| {
            if (assigned_prs[i]) continue;
            if (self.shouldExclude(pr.labels)) continue;
            if (pr.merged_at == null) continue;

            has_unreleased = true;
            try self.appendSectionEntry(&unreleased_sections_map, self.categorizeEntry(pr.labels), .{
                .title = pr.title,
                .url = pr.html_url,
                .author = pr.user.login,
                .number = pr.number,
            });
        }

        var unreleased: ?UnreleasedChanges = null;
        errdefer if (unreleased) |un| {
            for (un.sections) |section| {
                self.allocator.free(section.entries);
            }
            self.allocator.free(un.sections);
        };
        if (has_unreleased) {
            unreleased = UnreleasedChanges{
                .sections = try self.buildSections(&unreleased_sections_map),
            };
        }

        return Changelog{
            .releases = try result.toOwnedSlice(self.allocator),
            .unreleased = unreleased,
        };
    }

    pub fn deinitChangelog(self: ChangelogGenerator, changelog: Changelog) void {
        for (changelog.releases) |release| {
            for (release.sections) |section| {
                self.allocator.free(section.entries);
            }
            self.allocator.free(release.sections);
        }
        self.allocator.free(changelog.releases);
        if (changelog.unreleased) |un| {
            for (un.sections) |section| {
                self.allocator.free(section.entries);
            }
            self.allocator.free(un.sections);
        }
    }

    pub fn deinitLegacy(self: ChangelogGenerator, releases: []ChangelogRelease) void {
        for (releases) |release| {
            for (release.sections) |section| {
                self.allocator.free(section.entries);
            }
            self.allocator.free(release.sections);
        }
        self.allocator.free(releases);
    }
};
