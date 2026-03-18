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

    fn compareDates(date1: []const u8, date2: []const u8) i32 {
        const d1 = parseDateToSlice(date1);
        const d2 = parseDateToSlice(date2);
        if (d1.len == 0 or d2.len == 0) return 0;
        return switch (std.mem.order(u8, d1, d2)) {
            .lt => -1,
            .eq => 0,
            .gt => 1,
        };
    }

    fn parseDateToSlice(date_str: []const u8) []const u8 {
        for (date_str, 0..) |c, i| {
            if (c == 'T') {
                return date_str[0..i];
            }
        }
        return date_str;
    }

    fn isAfter(date_to_check: []const u8, reference_date: []const u8) bool {
        if (reference_date.len == 0) return true;
        return compareDates(date_to_check, reference_date) > 0;
    }

    fn isBefore(date_to_check: []const u8, reference_date: []const u8) bool {
        return compareDates(date_to_check, reference_date) < 0;
    }

    /// Generate changelog from releases and PRs
    pub fn generate(
        self: ChangelogGenerator,
        releases: []models.Release,
        prs: []models.PullRequest,
    ) !Changelog {
        var result = try std.ArrayList(ChangelogRelease).initCapacity(self.allocator, releases.len);

        var last_release_date: []const u8 = "";
        if (releases.len > 0) {
            last_release_date = releases[0].published_at;
        }

        for (releases) |release| {
            var sections_map = std.StringHashMap(std.ArrayListUnmanaged(ChangelogEntry)).init(self.allocator);
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
                    if (!isBefore(merged_at, release.published_at)) continue;
                } else {
                    continue;
                }

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

            if (compareDates(release.published_at, last_release_date) > 0) {
                last_release_date = release.published_at;
            }
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
                if (!isAfter(merged_at, last_release_date)) continue;
            } else {
                continue;
            }

            has_unreleased = true;
            const category = self.categorizeEntry(pr.labels);

            var section_list = unreleased_sections_map.getOrPut(category) catch continue;
            if (!section_list.found_existing) {
                const arr = try std.ArrayList(ChangelogEntry).initCapacity(self.allocator, prs.len);
                section_list.value_ptr.* = arr;
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
