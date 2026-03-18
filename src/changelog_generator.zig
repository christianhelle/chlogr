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

pub const ChangelogGenerator = struct {
    allocator: std.mem.Allocator,
    exclude_labels: ?[]const u8 = null,

    pub fn init(allocator: std.mem.Allocator, exclude_labels: ?[]const u8) ChangelogGenerator {
        return ChangelogGenerator{
            .allocator = allocator,
            .exclude_labels = exclude_labels,
        };
    }

    /// Check if an entry should be excluded based on labels
    fn shouldExclude(self: ChangelogGenerator, labels: []models.Label) bool {
        if (self.exclude_labels == null) return false;

        const exclude = self.exclude_labels.?;
        for (labels) |label| {
            if (std.mem.indexOf(u8, exclude, label.name) != null) {
                return true;
            }
        }
        return false;
    }

    /// Categorize PR/issue based on labels
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

    /// Generate changelog from releases and PRs.
    /// Each PR is assigned to exactly one release: the earliest release whose
    /// published_at >= pr.merged_at (full ISO 8601 lexicographic comparison).
    /// PRs with no qualifying release go to unreleased.
    pub fn generate(
        self: ChangelogGenerator,
        releases: []models.Release,
        prs: []models.PullRequest,
    ) !Changelog {
        // Sort releases oldest-first so a greedy single pass assigns each PR to the
        // earliest qualifying release, guaranteeing exactly one assignment per PR.
        const sorted = try self.allocator.dupe(models.Release, releases);
        defer self.allocator.free(sorted);
        std.mem.sort(models.Release, sorted, {}, releaseOldestFirst);

        // Track which PRs have been assigned to prevent duplicate entries.
        const assigned = try self.allocator.alloc(bool, prs.len);
        defer self.allocator.free(assigned);
        @memset(assigned, false);

        var result = try std.ArrayList(ChangelogRelease).initCapacity(self.allocator, sorted.len);

        for (sorted) |release| {
            var sections_map = std.StringHashMap(std.ArrayListUnmanaged(ChangelogEntry)).init(self.allocator);
            defer {
                var it = sections_map.iterator();
                while (it.next()) |entry| {
                    entry.value_ptr.deinit(self.allocator);
                }
                sections_map.deinit();
            }

            for (prs, 0..) |pr, i| {
                if (assigned[i]) continue;
                if (self.shouldExclude(pr.labels)) continue;
                const merged_at = pr.merged_at orelse continue;
                // Assign to this release if merged_at <= release.published_at.
                if (std.mem.order(u8, merged_at, release.published_at) == .gt) continue;

                assigned[i] = true;
                const category = self.categorizeEntry(pr.labels);

                var gop = try sections_map.getOrPut(category);
                if (!gop.found_existing) {
                    gop.value_ptr.* = .empty;
                }

                const entry = ChangelogEntry{
                    .title = pr.title,
                    .url = pr.html_url,
                    .author = pr.user.login,
                    .number = pr.number,
                };

                try gop.value_ptr.append(self.allocator, entry);
            }

            var sections_array = try std.ArrayList(ChangelogSection).initCapacity(self.allocator, sections_map.count());

            var it = sections_map.iterator();
            while (it.next()) |entry| {
                const changelog_section = ChangelogSection{
                    .name = entry.key_ptr.*,
                    .entries = try entry.value_ptr.toOwnedSlice(self.allocator),
                };
                sections_array.appendAssumeCapacity(changelog_section);
            }

            const release_entry = ChangelogRelease{
                .version = release.tag_name,
                .date = release.published_at,
                .sections = try sections_array.toOwnedSlice(self.allocator),
            };

            result.appendAssumeCapacity(release_entry);
        }

        // Collect any PRs not yet assigned to a release into unreleased.
        var unreleased_sections_map = std.StringHashMap(std.ArrayListUnmanaged(ChangelogEntry)).init(self.allocator);
        defer {
            var it = unreleased_sections_map.iterator();
            while (it.next()) |entry| {
                entry.value_ptr.deinit(self.allocator);
            }
            unreleased_sections_map.deinit();
        }

        var has_unreleased = false;
        for (prs, 0..) |pr, i| {
            if (assigned[i]) continue;
            if (self.shouldExclude(pr.labels)) continue;
            if (pr.merged_at == null) continue;

            has_unreleased = true;
            const category = self.categorizeEntry(pr.labels);

            var gop = try unreleased_sections_map.getOrPut(category);
            if (!gop.found_existing) {
                gop.value_ptr.* = .empty;
            }

            const entry = ChangelogEntry{
                .title = pr.title,
                .url = pr.html_url,
                .author = pr.user.login,
                .number = pr.number,
            };

            try gop.value_ptr.append(self.allocator, entry);
        }

        var unreleased: ?UnreleasedChanges = null;
        if (has_unreleased) {
            var unreleased_sections_array = try std.ArrayList(ChangelogSection).initCapacity(self.allocator, unreleased_sections_map.count());

            var it = unreleased_sections_map.iterator();
            while (it.next()) |entry| {
                const changelog_section = ChangelogSection{
                    .name = entry.key_ptr.*,
                    .entries = try entry.value_ptr.toOwnedSlice(self.allocator),
                };
                unreleased_sections_array.appendAssumeCapacity(changelog_section);
            }

            unreleased = UnreleasedChanges{
                .sections = try unreleased_sections_array.toOwnedSlice(self.allocator),
            };
        }

        return Changelog{ .releases = try result.toOwnedSlice(self.allocator), .unreleased = unreleased };
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
