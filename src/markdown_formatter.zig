const std = @import("std");
const changelog_generator = @import("changelog_generator.zig");

fn parseDateToSlice(date_str: []const u8) []const u8 {
    for (date_str, 0..) |c, i| {
        if (c == 'T') {
            return date_str[0..i];
        }
    }
    return date_str;
}

pub const MarkdownFormatter = struct {
    allocator: std.mem.Allocator,
    repo: []const u8,

    pub fn init(allocator: std.mem.Allocator, repo: []const u8) MarkdownFormatter {
        return MarkdownFormatter{
            .allocator = allocator,
            .repo = repo,
        };
    }

    /// Format changelog releases to Markdown string (legacy version for backward compat)
    pub fn format(self: MarkdownFormatter, releases: []changelog_generator.ChangelogRelease) ![]u8 {
        return self.formatWithUnreleased(releases, null);
    }

    /// Format changelog releases and unreleased changes to Markdown string.
    /// Writes all output directly into a single growing buffer, eliminating the
    /// per-fragment heap allocations that the previous parts-list approach required.
    pub fn formatWithUnreleased(
        self: MarkdownFormatter,
        releases: []changelog_generator.ChangelogRelease,
        unreleased: ?changelog_generator.UnreleasedChanges,
    ) ![]u8 {
        // Estimate final byte size so the buffer rarely needs to grow.
        // "## [<ver>](https://github.com/<repo>/releases/tag/<ver>) (<date>)\n\n"
        // has 52 fixed bytes + version*2 + repo + date.
        // Entry lines: "- <title> ([#<num>](<url>)) (@<author>)\n" ≈ 15 + variable parts.
        var est: usize = 16; // "# Changelog\n\n"
        if (unreleased) |un| {
            est += 26; // "## [Unreleased Changes]\n\n"
            for (un.sections) |section| {
                est += 5 + section.name.len + 1;
                for (section.entries) |entry| {
                    est += 15 + entry.title.len + entry.url.len + entry.author.len;
                }
                est += 1;
            }
            est += 1;
        }
        for (releases) |release| {
            est += 52 + release.version.len * 2 + self.repo.len + parseDateToSlice(release.date).len;
            for (release.sections) |section| {
                est += 5 + section.name.len + 1;
                for (section.entries) |entry| {
                    est += 15 + entry.title.len + entry.url.len + entry.author.len;
                }
                est += 1;
            }
            est += 1;
        }

        var buf = try std.ArrayList(u8).initCapacity(self.allocator, est);
        errdefer buf.deinit(self.allocator);
        const writer = buf.writer(self.allocator);

        try writer.writeAll("# Changelog\n\n");

        if (unreleased) |un| {
            try writer.writeAll("## [Unreleased Changes]\n\n");
            for (un.sections) |section| {
                try writer.print("### {s}\n", .{section.name});
                for (section.entries) |entry| {
                    try writer.print("- {s} ([#{d}]({s})) (@{s})\n", .{
                        entry.title, entry.number, entry.url, entry.author,
                    });
                }
                try writer.writeByte('\n');
            }
            try writer.writeByte('\n');
        }

        for (releases) |release| {
            const date_only = parseDateToSlice(release.date);
            try writer.print("## [{s}](https://github.com/{s}/releases/tag/{s}) ({s})\n\n", .{
                release.version, self.repo, release.version, date_only,
            });
            for (release.sections) |section| {
                try writer.print("### {s}\n", .{section.name});
                for (section.entries) |entry| {
                    try writer.print("- {s} ([#{d}]({s})) (@{s})\n", .{
                        entry.title, entry.number, entry.url, entry.author,
                    });
                }
                try writer.writeByte('\n');
            }
            try writer.writeByte('\n');
        }

        return buf.toOwnedSlice(self.allocator);
    }

    /// Write Markdown to file
    pub fn writeToFile(_: MarkdownFormatter, file_path: []const u8, content: []const u8) !void {
        const file = try std.fs.cwd().createFile(file_path, .{});
        defer file.close();

        try file.writeAll(content);
    }

    pub fn deinit(self: MarkdownFormatter, content: []u8) void {
        self.allocator.free(content);
    }
};
