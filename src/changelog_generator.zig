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

    /// Compare full ISO-8601 timestamps (preserves time precision)
    fn compareDates(date1: []const u8, date2: []const u8) i32 {
        if (date1.len == 0 or date2.len == 0) return 0;
        // Direct lexicographic comparison works for ISO-8601 format
        return switch (std.mem.order(u8, date1, date2)) {
            .lt => -1,
            .eq => 0,
            .gt => 1,
        };
    }

    fn isAfter(date_to_check: []const u8, reference_date: []const u8) bool {
        if (reference_date.len == 0) return true;
        return compareDates(date_to_check, reference_date) > 0;
    }

    fn isBeforeOrEqual(date_to_check: []const u8, reference_date: []const u8) bool {
        return compareDates(date_to_check, reference_date) <= 0;
    }

    /// Generate changelog from releases and PRs
    pub fn generate(
        self: ChangelogGenerator,
        releases: []models.Release,
        prs: []models.PullRequest,
    ) !Changelog {
        // Sort releases by published_at (newest first) for correct assignment
        const sorted_releases = try self.allocator.alloc(models.Release, releases.len);
        defer self.allocator.free(sorted_releases);
        @memcpy(sorted_releases, releases);
        
        // Bubble sort (simple and correct for small arrays)
        for (0..sorted_releases.len) |i| {
            for (i + 1..sorted_releases.len) |j| {
                if (compareDates(sorted_releases[i].published_at, sorted_releases[j].published_at) < 0) {
                    const tmp = sorted_releases[i];
                    sorted_releases[i] = sorted_releases[j];
                    sorted_releases[j] = tmp;
                }
            }
        }

        var result = try std.ArrayList(ChangelogRelease).initCapacity(self.allocator, sorted_releases.len);

        var last_release_date: []const u8 = "";
        if (sorted_releases.len > 0) {
            last_release_date = sorted_releases[0].published_at;
        }

        // Process each release in sorted order (newest to oldest)
        for (sorted_releases) |release| {
            var sections_map = std.StringHashMap(std.ArrayList(ChangelogEntry)).init(self.allocator);
            defer {
                var it = sections_map.iterator();
                while (it.next()) |entry| {
                    entry.value_ptr.deinit(self.allocator);
                }
                sections_map.deinit();
            }

            for (prs) |pr| {
                if (self.shouldExclude(pr.labels)) continue;
                if (pr.merged_at) |merged_at| {
                    // PR belongs to this release if merged_at <= published_at
                    // Use <= to include PRs merged at exact release time
                    if (!isBeforeOrEqual(merged_at, release.published_at)) continue;
                } else {
                    continue;
                }

                const category = self.categorizeEntry(pr.labels);

                var section_list = try sections_map.getOrPut(category);
                if (!section_list.found_existing) {
                    section_list.value_ptr.* = std.ArrayList(ChangelogEntry).empty;
                }

                const entry = ChangelogEntry{
                    .title = pr.title,
                    .url = pr.html_url,
                    .author = pr.user.login,
                    .number = pr.number,
                };

                try section_list.value_ptr.append(self.allocator, entry);
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

        var unreleased_sections_map = std.StringHashMap(std.ArrayList(ChangelogEntry)).init(self.allocator);
        defer {
            var it = unreleased_sections_map.iterator();
            while (it.next()) |entry| {
                entry.value_ptr.deinit(self.allocator);
            }
            unreleased_sections_map.deinit();
        }

        var has_unreleased = false;
        for (prs) |pr| {
            if (self.shouldExclude(pr.labels)) continue;
            if (pr.merged_at) |merged_at| {
                // PRs merged after the latest release go to unreleased
                if (!isAfter(merged_at, last_release_date)) continue;
            } else {
                continue;
            }

            has_unreleased = true;
            const category = self.categorizeEntry(pr.labels);

            var section_list = try unreleased_sections_map.getOrPut(category);
            if (!section_list.found_existing) {
                section_list.value_ptr.* = std.ArrayList(ChangelogEntry).empty;
            }

            const entry = ChangelogEntry{
                .title = pr.title,
                .url = pr.html_url,
                .author = pr.user.login,
                .number = pr.number,
            };

            try section_list.value_ptr.append(self.allocator, entry);
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
