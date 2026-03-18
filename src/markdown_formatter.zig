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

    /// Format changelog releases and unreleased changes to Markdown string
    pub fn formatWithUnreleased(
        self: MarkdownFormatter,
        releases: []changelog_generator.ChangelogRelease,
        unreleased: ?changelog_generator.UnreleasedChanges,
    ) ![]u8 {
        var total_items: usize = 1;
        if (unreleased) |un| {
            total_items += 1;
            for (un.sections) |section| {
                total_items += 1;
                total_items += section.entries.len;
                total_items += 1;
            }
            total_items += 1;
        }
        for (releases) |release| {
            total_items += 1;
            for (release.sections) |section| {
                total_items += 1;
                total_items += section.entries.len;
                total_items += 1;
            }
            total_items += 1;
        }

        var parts = try std.ArrayList([]u8).initCapacity(self.allocator, total_items + 20);
        defer parts.deinit(self.allocator);

        try parts.append(self.allocator, try self.allocator.dupe(u8, "# Changelog\n\n"));

        if (unreleased) |un| {
            try parts.append(self.allocator, try self.allocator.dupe(u8, "## [Unreleased Changes]\n\n"));

            for (un.sections) |section| {
                const section_header = try std.fmt.allocPrint(self.allocator, "### {s}\n", .{section.name});
                try parts.append(self.allocator, section_header);

                for (section.entries) |entry| {
                    const entry_line = try std.fmt.allocPrint(self.allocator, "- {s} ([#{d}]({s})) (@{s})\n", .{
                        entry.title,
                        entry.number,
                        entry.url,
                        entry.author,
                    });
                    try parts.append(self.allocator, entry_line);
                }

                try parts.append(self.allocator, try self.allocator.dupe(u8, "\n"));
            }

            try parts.append(self.allocator, try self.allocator.dupe(u8, "\n"));
        }

        for (releases) |release| {
            const date_only = parseDateToSlice(release.date);
            const header = try std.fmt.allocPrint(self.allocator, "## [{s}](https://github.com/{s}/releases/tag/{s}) ({s})\n\n", .{
                release.version,
                self.repo,
                release.version,
                date_only,
            });
            try parts.append(self.allocator, header);

            for (release.sections) |section| {
                const section_header = try std.fmt.allocPrint(self.allocator, "### {s}\n", .{section.name});
                try parts.append(self.allocator, section_header);

                for (section.entries) |entry| {
                    const entry_line = try std.fmt.allocPrint(self.allocator, "- {s} ([#{d}]({s})) (@{s})\n", .{
                        entry.title,
                        entry.number,
                        entry.url,
                        entry.author,
                    });
                    try parts.append(self.allocator, entry_line);
                }

                try parts.append(self.allocator, try self.allocator.dupe(u8, "\n"));
            }

            try parts.append(self.allocator, try self.allocator.dupe(u8, "\n"));
        }

        // Calculate total length
        var total_len: usize = 0;
        for (parts.items) |part| {
            total_len += part.len;
        }

        // Allocate result and concatenate
        var result = try self.allocator.alloc(u8, total_len);
        var offset: usize = 0;
        for (parts.items) |part| {
            @memcpy(result[offset .. offset + part.len], part);
            offset += part.len;
            self.allocator.free(part);
        }

        return result;
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
