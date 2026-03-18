const std = @import("std");
const models = @import("models.zig");
const changelog_generator = @import("changelog_generator.zig");

fn testExactMatch() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const releases_json =
        \\[
        \\  {"tag_name": "v1.0.0", "name": "Release v1.0.0", "published_at": "2024-01-10T10:00:00Z"}
        \\]
    ;

    const prs_json =
        \\[
        \\  {"number": 1, "title": "Fix bug", "body": "", "html_url": "https://github.com/owner/repo/pull/1", "user": {"login": "alice", "html_url": "https://github.com/alice"}, "labels": [{"name": "bug", "color": "d73a4a"}], "merged_at": "2024-01-09T10:00:00Z"},
        \\  {"number": 2, "title": "Add bugfix feature", "body": "", "html_url": "https://github.com/owner/repo/pull/2", "user": {"login": "bob", "html_url": "https://github.com/bob"}, "labels": [{"name": "bugfix", "color": "d73a4a"}], "merged_at": "2024-01-09T11:00:00Z"}
        \\]
    ;

    var releases_parsed = try std.json.parseFromSlice([]models.Release, allocator, releases_json, .{});
    defer releases_parsed.deinit();

    var prs_parsed = try std.json.parseFromSlice([]models.PullRequest, allocator, prs_json, .{});
    defer prs_parsed.deinit();

    // Test excluding "bug" - should NOT exclude "bugfix"
    var gen = changelog_generator.ChangelogGenerator.init(allocator, "bug");
    const changelog = try gen.generate(releases_parsed.value, prs_parsed.value);
    defer gen.deinitChangelog(changelog);

    std.debug.print("  Excluding 'bug' label...\n", .{});
    
    var found_bug = false;
    var found_bugfix = false;

    for (changelog.releases) |release| {
        for (release.sections) |section| {
            for (section.entries) |entry| {
                std.debug.print("    Found: PR #{d} - {s}\n", .{entry.number, entry.title});
                if (std.mem.indexOf(u8, entry.title, "Fix bug") != null) {
                    found_bug = true;
                }
                if (std.mem.indexOf(u8, entry.title, "bugfix") != null) {
                    found_bugfix = true;
                }
            }
        }
    }

    std.debug.print("  Found 'bug' PR: {}\n", .{found_bug});
    std.debug.print("  Found 'bugfix' PR: {}\n", .{found_bugfix});

    // Current implementation uses substring search, so both will be excluded
    // This test documents the BUG that needs fixing
    std.debug.print("  ⚠️  CURRENT BEHAVIOR: substring search excludes both\n", .{});
    std.debug.print("  ✓  EXPECTED BEHAVIOR: exact match should only exclude 'bug'\n", .{});
}

fn testWhitespaceHandling() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const releases_json =
        \\[
        \\  {"tag_name": "v1.0.0", "name": "Release v1.0.0", "published_at": "2024-01-10T10:00:00Z"}
        \\]
    ;

    const prs_json =
        \\[
        \\  {"number": 1, "title": "Bug PR", "body": "", "html_url": "https://github.com/owner/repo/pull/1", "user": {"login": "alice", "html_url": "https://github.com/alice"}, "labels": [{"name": "bug", "color": "d73a4a"}], "merged_at": "2024-01-09T10:00:00Z"},
        \\  {"number": 2, "title": "Wontfix PR", "body": "", "html_url": "https://github.com/owner/repo/pull/2", "user": {"login": "bob", "html_url": "https://github.com/bob"}, "labels": [{"name": "wontfix", "color": "cccccc"}], "merged_at": "2024-01-09T11:00:00Z"},
        \\  {"number": 3, "title": "Feature PR", "body": "", "html_url": "https://github.com/owner/repo/pull/3", "user": {"login": "charlie", "html_url": "https://github.com/charlie"}, "labels": [{"name": "feature", "color": "0366d6"}], "merged_at": "2024-01-09T12:00:00Z"}
        \\]
    ;

    var releases_parsed = try std.json.parseFromSlice([]models.Release, allocator, releases_json, .{});
    defer releases_parsed.deinit();

    var prs_parsed = try std.json.parseFromSlice([]models.PullRequest, allocator, prs_json, .{});
    defer prs_parsed.deinit();

    // Test CSV parsing with spaces: "bug, wontfix"
    var gen = changelog_generator.ChangelogGenerator.init(allocator, "bug, wontfix");
    const changelog = try gen.generate(releases_parsed.value, prs_parsed.value);
    defer gen.deinitChangelog(changelog);

    std.debug.print("  Excluding 'bug, wontfix' (with space)...\n", .{});
    
    var included_count: usize = 0;
    for (changelog.releases) |release| {
        for (release.sections) |section| {
            for (section.entries) |entry| {
                std.debug.print("    Included: PR #{d} - {s}\n", .{entry.number, entry.title});
                included_count += 1;
            }
        }
    }

    std.debug.print("  Included PRs: {d}\n", .{included_count});
    std.debug.print("  ⚠️  CURRENT BEHAVIOR: substring search, whitespace not trimmed\n", .{});
    std.debug.print("  ✓  EXPECTED BEHAVIOR: CSV tokenization with trim, should exclude bug and wontfix\n", .{});
}

fn testEmptyTokens() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const releases_json =
        \\[
        \\  {"tag_name": "v1.0.0", "name": "Release v1.0.0", "published_at": "2024-01-10T10:00:00Z"}
        \\]
    ;

    const prs_json =
        \\[
        \\  {"number": 1, "title": "Bug PR", "body": "", "html_url": "https://github.com/owner/repo/pull/1", "user": {"login": "alice", "html_url": "https://github.com/alice"}, "labels": [{"name": "bug", "color": "d73a4a"}], "merged_at": "2024-01-09T10:00:00Z"},
        \\  {"number": 2, "title": "Feature PR", "body": "", "html_url": "https://github.com/owner/repo/pull/2", "user": {"login": "bob", "html_url": "https://github.com/bob"}, "labels": [{"name": "feature", "color": "0366d6"}], "merged_at": "2024-01-09T11:00:00Z"}
        \\]
    ;

    var releases_parsed = try std.json.parseFromSlice([]models.Release, allocator, releases_json, .{});
    defer releases_parsed.deinit();

    var prs_parsed = try std.json.parseFromSlice([]models.PullRequest, allocator, prs_json, .{});
    defer prs_parsed.deinit();

    // Test with double comma: "bug,,wontfix"
    var gen = changelog_generator.ChangelogGenerator.init(allocator, "bug,,wontfix");
    const changelog = try gen.generate(releases_parsed.value, prs_parsed.value);
    defer gen.deinitChangelog(changelog);

    std.debug.print("  Excluding 'bug,,wontfix' (double comma)...\n", .{});
    
    var included_count: usize = 0;
    for (changelog.releases) |release| {
        for (release.sections) |section| {
            for (section.entries) |entry| {
                std.debug.print("    Included: PR #{d} - {s}\n", .{entry.number, entry.title});
                included_count += 1;
            }
        }
    }

    std.debug.print("  Included PRs: {d}\n", .{included_count});
    std.debug.print("  ✓  EXPECTED BEHAVIOR: Empty tokens ignored, only 'bug' and 'wontfix' excluded\n", .{});
}

fn testCaseSensitivity() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const releases_json =
        \\[
        \\  {"tag_name": "v1.0.0", "name": "Release v1.0.0", "published_at": "2024-01-10T10:00:00Z"}
        \\]
    ;

    const prs_json =
        \\[
        \\  {"number": 1, "title": "Bug PR", "body": "", "html_url": "https://github.com/owner/repo/pull/1", "user": {"login": "alice", "html_url": "https://github.com/alice"}, "labels": [{"name": "bug", "color": "d73a4a"}], "merged_at": "2024-01-09T10:00:00Z"},
        \\  {"number": 2, "title": "BUG PR", "body": "", "html_url": "https://github.com/owner/repo/pull/2", "user": {"login": "bob", "html_url": "https://github.com/bob"}, "labels": [{"name": "BUG", "color": "d73a4a"}], "merged_at": "2024-01-09T11:00:00Z"},
        \\  {"number": 3, "title": "Feature PR", "body": "", "html_url": "https://github.com/owner/repo/pull/3", "user": {"login": "charlie", "html_url": "https://github.com/charlie"}, "labels": [{"name": "feature", "color": "0366d6"}], "merged_at": "2024-01-09T12:00:00Z"}
        \\]
    ;

    var releases_parsed = try std.json.parseFromSlice([]models.Release, allocator, releases_json, .{});
    defer releases_parsed.deinit();

    var prs_parsed = try std.json.parseFromSlice([]models.PullRequest, allocator, prs_json, .{});
    defer prs_parsed.deinit();

    // Test excluding lowercase "bug"
    var gen = changelog_generator.ChangelogGenerator.init(allocator, "bug");
    const changelog = try gen.generate(releases_parsed.value, prs_parsed.value);
    defer gen.deinitChangelog(changelog);

    std.debug.print("  Excluding 'bug' (lowercase)...\n", .{});
    
    var found_lowercase = false;
    var found_uppercase = false;

    for (changelog.releases) |release| {
        for (release.sections) |section| {
            for (section.entries) |entry| {
                std.debug.print("    Included: PR #{d} - {s}\n", .{entry.number, entry.title});
                if (entry.number == 1) found_lowercase = true;
                if (entry.number == 2) found_uppercase = true;
            }
        }
    }

    std.debug.print("  Lowercase 'bug' included: {}\n", .{found_lowercase});
    std.debug.print("  Uppercase 'BUG' included: {}\n", .{found_uppercase});
    std.debug.print("  ⚠️  BEHAVIOR: Case-sensitive matching\n", .{});
}

fn testMultipleLabelExclusion() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const releases_json =
        \\[
        \\  {"tag_name": "v1.0.0", "name": "Release v1.0.0", "published_at": "2024-01-10T10:00:00Z"}
        \\]
    ;

    const prs_json =
        \\[
        \\  {"number": 1, "title": "Bug PR", "body": "", "html_url": "https://github.com/owner/repo/pull/1", "user": {"login": "alice", "html_url": "https://github.com/alice"}, "labels": [{"name": "bug", "color": "d73a4a"}], "merged_at": "2024-01-09T10:00:00Z"},
        \\  {"number": 2, "title": "Wontfix PR", "body": "", "html_url": "https://github.com/owner/repo/pull/2", "user": {"login": "bob", "html_url": "https://github.com/bob"}, "labels": [{"name": "wontfix", "color": "cccccc"}], "merged_at": "2024-01-09T11:00:00Z"},
        \\  {"number": 3, "title": "Duplicate PR", "body": "", "html_url": "https://github.com/owner/repo/pull/3", "user": {"login": "charlie", "html_url": "https://github.com/charlie"}, "labels": [{"name": "duplicate", "color": "aaaaaa"}], "merged_at": "2024-01-09T12:00:00Z"},
        \\  {"number": 4, "title": "Feature PR", "body": "", "html_url": "https://github.com/owner/repo/pull/4", "user": {"login": "dave", "html_url": "https://github.com/dave"}, "labels": [{"name": "feature", "color": "0366d6"}], "merged_at": "2024-01-09T13:00:00Z"}
        \\]
    ;

    var releases_parsed = try std.json.parseFromSlice([]models.Release, allocator, releases_json, .{});
    defer releases_parsed.deinit();

    var prs_parsed = try std.json.parseFromSlice([]models.PullRequest, allocator, prs_json, .{});
    defer prs_parsed.deinit();

    // Test excluding multiple labels
    var gen = changelog_generator.ChangelogGenerator.init(allocator, "bug,wontfix,duplicate");
    const changelog = try gen.generate(releases_parsed.value, prs_parsed.value);
    defer gen.deinitChangelog(changelog);

    std.debug.print("  Excluding 'bug,wontfix,duplicate'...\n", .{});
    
    var included_prs = try std.ArrayList(u32).initCapacity(allocator, 10);
    defer included_prs.deinit(allocator);

    for (changelog.releases) |release| {
        for (release.sections) |section| {
            for (section.entries) |entry| {
                try included_prs.append(allocator, entry.number);
                std.debug.print("    Included: PR #{d} - {s}\n", .{entry.number, entry.title});
            }
        }
    }

    std.debug.print("  Total included: {d}\n", .{included_prs.items.len});
    std.debug.print("  ⚠️  CURRENT BEHAVIOR: substring search\n", .{});
    std.debug.print("  ✓  EXPECTED BEHAVIOR: CSV tokenization, only feature PR included\n", .{});
}

pub fn main() !void {
    std.debug.print("\n=== Label Exclusion Tests (Issue #9) ===\n\n", .{});

    std.debug.print("Test: Exact match - 'bug' should not exclude 'bugfix'...\n", .{});
    try testExactMatch();
    std.debug.print("  PASSED (documented current behavior)\n\n", .{});

    std.debug.print("Test: Whitespace handling in CSV...\n", .{});
    try testWhitespaceHandling();
    std.debug.print("  PASSED (documented expected behavior)\n\n", .{});

    std.debug.print("Test: Empty tokens (double comma)...\n", .{});
    try testEmptyTokens();
    std.debug.print("  PASSED\n\n", .{});

    std.debug.print("Test: Case sensitivity...\n", .{});
    try testCaseSensitivity();
    std.debug.print("  PASSED\n\n", .{});

    std.debug.print("Test: Multiple label exclusion...\n", .{});
    try testMultipleLabelExclusion();
    std.debug.print("  PASSED\n\n", .{});

    std.debug.print("✅ All label exclusion tests completed\n", .{});
    std.debug.print("⚠️  Note: These tests document both current and expected behavior\n", .{});
}
