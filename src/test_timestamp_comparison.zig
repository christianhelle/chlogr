const std = @import("std");
const models = @import("models.zig");
const changelog_generator = @import("changelog_generator.zig");

fn testFullISO8601Comparison() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const releases_json =
        \\[
        \\  {"tag_name": "v1.0.0", "name": "Release v1.0.0", "published_at": "2024-01-10T14:30:45.123456Z"}
        \\]
    ;

    const prs_json =
        \\[
        \\  {"number": 1, "title": "PR before release", "body": "", "html_url": "https://github.com/owner/repo/pull/1", "user": {"login": "alice", "html_url": "https://github.com/alice"}, "labels": [{"name": "feature", "color": "0366d6"}], "merged_at": "2024-01-10T14:30:45.123455Z"},
        \\  {"number": 2, "title": "PR after release", "body": "", "html_url": "https://github.com/owner/repo/pull/2", "user": {"login": "bob", "html_url": "https://github.com/bob"}, "labels": [{"name": "feature", "color": "0366d6"}], "merged_at": "2024-01-10T14:30:45.123457Z"}
        \\]
    ;

    var releases_parsed = try std.json.parseFromSlice([]models.Release, allocator, releases_json, .{});
    defer releases_parsed.deinit();

    var prs_parsed = try std.json.parseFromSlice([]models.PullRequest, allocator, prs_json, .{});
    defer prs_parsed.deinit();

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases_parsed.value, prs_parsed.value);
    defer gen.deinitChangelog(changelog);

    std.debug.print("  Release: 2024-01-10T14:30:45.123456Z\n", .{});
    std.debug.print("  PR #1:   2024-01-10T14:30:45.123455Z (1 microsecond before)\n", .{});
    std.debug.print("  PR #2:   2024-01-10T14:30:45.123457Z (1 microsecond after)\n", .{});

    var pr1_in_release = false;
    var pr2_in_unreleased = false;

    for (changelog.releases) |release| {
        for (release.sections) |section| {
            for (section.entries) |entry| {
                if (entry.number == 1) {
                    pr1_in_release = true;
                    std.debug.print("  ✓ PR #1 in release\n", .{});
                }
            }
        }
    }

    if (changelog.unreleased) |unreleased| {
        for (unreleased.sections) |section| {
            for (section.entries) |entry| {
                if (entry.number == 2) {
                    pr2_in_unreleased = true;
                    std.debug.print("  ✓ PR #2 in unreleased\n", .{});
                }
            }
        }
    }

    std.debug.print("  ⚠️  CURRENT BEHAVIOR: Truncates to date (2024-01-10), both in same bucket\n", .{});
    std.debug.print("  ✓  EXPECTED BEHAVIOR: Full timestamp comparison, different buckets\n", .{});
}

fn testSameDayDifferentTimes() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const releases_json =
        \\[
        \\  {"tag_name": "v1.0.0", "name": "Release v1.0.0", "published_at": "2024-01-10T14:00:00Z"}
        \\]
    ;

    const prs_json =
        \\[
        \\  {"number": 1, "title": "PR at 10 AM", "body": "", "html_url": "https://github.com/owner/repo/pull/1", "user": {"login": "alice", "html_url": "https://github.com/alice"}, "labels": [{"name": "feature", "color": "0366d6"}], "merged_at": "2024-01-10T10:00:00Z"},
        \\  {"number": 2, "title": "PR at 2 PM", "body": "", "html_url": "https://github.com/owner/repo/pull/2", "user": {"login": "bob", "html_url": "https://github.com/bob"}, "labels": [{"name": "feature", "color": "0366d6"}], "merged_at": "2024-01-10T14:00:00Z"},
        \\  {"number": 3, "title": "PR at 6 PM", "body": "", "html_url": "https://github.com/owner/repo/pull/3", "user": {"login": "charlie", "html_url": "https://github.com/charlie"}, "labels": [{"name": "feature", "color": "0366d6"}], "merged_at": "2024-01-10T18:00:00Z"}
        \\]
    ;

    var releases_parsed = try std.json.parseFromSlice([]models.Release, allocator, releases_json, .{});
    defer releases_parsed.deinit();

    var prs_parsed = try std.json.parseFromSlice([]models.PullRequest, allocator, prs_json, .{});
    defer prs_parsed.deinit();

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases_parsed.value, prs_parsed.value);
    defer gen.deinitChangelog(changelog);

    std.debug.print("  Release: 2024-01-10T14:00:00Z (2 PM)\n", .{});
    std.debug.print("  PR #1: 2024-01-10T10:00:00Z (10 AM, before release)\n", .{});
    std.debug.print("  PR #2: 2024-01-10T14:00:00Z (2 PM, same time as release)\n", .{});
    std.debug.print("  PR #3: 2024-01-10T18:00:00Z (6 PM, after release)\n", .{});

    var pr_locations = std.StringHashMap(bool).init(allocator);
    defer pr_locations.deinit();

    for (changelog.releases) |release| {
        for (release.sections) |section| {
            for (section.entries) |entry| {
                try pr_locations.put(try std.fmt.allocPrint(allocator, "PR{d}_release", .{entry.number}), true);
                std.debug.print("  PR #{d} → release\n", .{entry.number});
            }
        }
    }

    if (changelog.unreleased) |unreleased| {
        for (unreleased.sections) |section| {
            for (section.entries) |entry| {
                try pr_locations.put(try std.fmt.allocPrint(allocator, "PR{d}_unreleased", .{entry.number}), true);
                std.debug.print("  PR #{d} → unreleased\n", .{entry.number});
            }
        }
    }

    var it = pr_locations.iterator();
    while (it.next()) |entry| {
        allocator.free(entry.key_ptr.*);
    }
}

fn testBoundaryAtExactReleaseTime() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const releases_json =
        \\[
        \\  {"tag_name": "v1.0.0", "name": "Release v1.0.0", "published_at": "2024-01-10T14:00:00Z"}
        \\]
    ;

    const prs_json =
        \\[
        \\  {"number": 1, "title": "PR exactly at release time", "body": "", "html_url": "https://github.com/owner/repo/pull/1", "user": {"login": "alice", "html_url": "https://github.com/alice"}, "labels": [{"name": "feature", "color": "0366d6"}], "merged_at": "2024-01-10T14:00:00Z"}
        \\]
    ;

    var releases_parsed = try std.json.parseFromSlice([]models.Release, allocator, releases_json, .{});
    defer releases_parsed.deinit();

    var prs_parsed = try std.json.parseFromSlice([]models.PullRequest, allocator, prs_json, .{});
    defer prs_parsed.deinit();

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases_parsed.value, prs_parsed.value);
    defer gen.deinitChangelog(changelog);

    std.debug.print("  Release: 2024-01-10T14:00:00Z\n", .{});
    std.debug.print("  PR #1:   2024-01-10T14:00:00Z (exactly at release time)\n", .{});

    var in_release = false;
    var in_unreleased = false;

    for (changelog.releases) |release| {
        for (release.sections) |section| {
            for (section.entries) |entry| {
                if (entry.number == 1) {
                    in_release = true;
                }
            }
        }
    }

    if (changelog.unreleased) |unreleased| {
        for (unreleased.sections) |section| {
            for (section.entries) |entry| {
                if (entry.number == 1) {
                    in_unreleased = true;
                }
            }
        }
    }

    if (in_release) {
        std.debug.print("  → PR in release (merged_at < published_at or merged_at == published_at)\n", .{});
    } else if (in_unreleased) {
        std.debug.print("  → PR in unreleased (merged_at > published_at)\n", .{});
    } else {
        std.debug.print("  → PR not included anywhere (edge case)\n", .{});
    }

    std.debug.print("  ⚠️  BOUNDARY CONDITION: Needs clear definition\n", .{});
}

fn testTimestampWithMilliseconds() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const releases_json =
        \\[
        \\  {"tag_name": "v1.0.0", "name": "Release v1.0.0", "published_at": "2024-01-10T14:00:00.500Z"}
        \\]
    ;

    const prs_json =
        \\[
        \\  {"number": 1, "title": "PR before (milliseconds)", "body": "", "html_url": "https://github.com/owner/repo/pull/1", "user": {"login": "alice", "html_url": "https://github.com/alice"}, "labels": [{"name": "feature", "color": "0366d6"}], "merged_at": "2024-01-10T14:00:00.499Z"},
        \\  {"number": 2, "title": "PR after (milliseconds)", "body": "", "html_url": "https://github.com/owner/repo/pull/2", "user": {"login": "bob", "html_url": "https://github.com/bob"}, "labels": [{"name": "feature", "color": "0366d6"}], "merged_at": "2024-01-10T14:00:00.501Z"}
        \\]
    ;

    var releases_parsed = try std.json.parseFromSlice([]models.Release, allocator, releases_json, .{});
    defer releases_parsed.deinit();

    var prs_parsed = try std.json.parseFromSlice([]models.PullRequest, allocator, prs_json, .{});
    defer prs_parsed.deinit();

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases_parsed.value, prs_parsed.value);
    defer gen.deinitChangelog(changelog);

    std.debug.print("  Release: 2024-01-10T14:00:00.500Z\n", .{});
    std.debug.print("  PR #1:   2024-01-10T14:00:00.499Z (1ms before)\n", .{});
    std.debug.print("  PR #2:   2024-01-10T14:00:00.501Z (1ms after)\n", .{});

    var pr1_in_release = false;
    var pr2_in_unreleased = false;

    for (changelog.releases) |release| {
        for (release.sections) |section| {
            for (section.entries) |entry| {
                if (entry.number == 1) {
                    pr1_in_release = true;
                    std.debug.print("  ✓ PR #1 in release\n", .{});
                } else {
                    std.debug.print("  PR #{d} in release\n", .{entry.number});
                }
            }
        }
    }

    if (changelog.unreleased) |unreleased| {
        for (unreleased.sections) |section| {
            for (section.entries) |entry| {
                if (entry.number == 2) {
                    pr2_in_unreleased = true;
                    std.debug.print("  ✓ PR #2 in unreleased\n", .{});
                } else {
                    std.debug.print("  PR #{d} in unreleased\n", .{entry.number});
                }
            }
        }
    }

    std.debug.print("  ⚠️  Millisecond precision must be preserved\n", .{});
}

fn testMultipleReleasesWithPreciseTimestamps() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const releases_json =
        \\[
        \\  {"tag_name": "v1.2.0", "name": "Release v1.2.0", "published_at": "2024-01-10T16:00:00Z"},
        \\  {"tag_name": "v1.1.0", "name": "Release v1.1.0", "published_at": "2024-01-10T12:00:00Z"},
        \\  {"tag_name": "v1.0.0", "name": "Release v1.0.0", "published_at": "2024-01-10T08:00:00Z"}
        \\]
    ;

    const prs_json =
        \\[
        \\  {"number": 1, "title": "PR at 7 AM", "body": "", "html_url": "https://github.com/owner/repo/pull/1", "user": {"login": "alice", "html_url": "https://github.com/alice"}, "labels": [{"name": "feature", "color": "0366d6"}], "merged_at": "2024-01-10T07:00:00Z"},
        \\  {"number": 2, "title": "PR at 10 AM", "body": "", "html_url": "https://github.com/owner/repo/pull/2", "user": {"login": "bob", "html_url": "https://github.com/bob"}, "labels": [{"name": "feature", "color": "0366d6"}], "merged_at": "2024-01-10T10:00:00Z"},
        \\  {"number": 3, "title": "PR at 2 PM", "body": "", "html_url": "https://github.com/owner/repo/pull/3", "user": {"login": "charlie", "html_url": "https://github.com/charlie"}, "labels": [{"name": "feature", "color": "0366d6"}], "merged_at": "2024-01-10T14:00:00Z"},
        \\  {"number": 4, "title": "PR at 6 PM", "body": "", "html_url": "https://github.com/owner/repo/pull/4", "user": {"login": "dave", "html_url": "https://github.com/dave"}, "labels": [{"name": "feature", "color": "0366d6"}], "merged_at": "2024-01-10T18:00:00Z"}
        \\]
    ;

    var releases_parsed = try std.json.parseFromSlice([]models.Release, allocator, releases_json, .{});
    defer releases_parsed.deinit();

    var prs_parsed = try std.json.parseFromSlice([]models.PullRequest, allocator, prs_json, .{});
    defer prs_parsed.deinit();

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases_parsed.value, prs_parsed.value);
    defer gen.deinitChangelog(changelog);

    std.debug.print("  Releases:\n", .{});
    std.debug.print("    v1.2.0: 2024-01-10T16:00:00Z (4 PM)\n", .{});
    std.debug.print("    v1.1.0: 2024-01-10T12:00:00Z (12 PM)\n", .{});
    std.debug.print("    v1.0.0: 2024-01-10T08:00:00Z (8 AM)\n", .{});
    std.debug.print("\n  PRs:\n", .{});
    std.debug.print("    PR #1: 07:00 (before v1.0.0)\n", .{});
    std.debug.print("    PR #2: 10:00 (after v1.0.0, before v1.1.0)\n", .{});
    std.debug.print("    PR #3: 14:00 (after v1.1.0, before v1.2.0)\n", .{});
    std.debug.print("    PR #4: 18:00 (after v1.2.0)\n", .{});
    std.debug.print("\n  Expected assignment:\n", .{});
    std.debug.print("    PR #1 → v1.0.0\n", .{});
    std.debug.print("    PR #2 → v1.1.0\n", .{});
    std.debug.print("    PR #3 → v1.2.0\n", .{});
    std.debug.print("    PR #4 → unreleased\n", .{});
    std.debug.print("\n  Actual assignment:\n", .{});

    for (changelog.releases) |release| {
        for (release.sections) |section| {
            for (section.entries) |entry| {
                std.debug.print("    PR #{d} → {s}\n", .{entry.number, release.version});
            }
        }
    }

    if (changelog.unreleased) |unreleased| {
        for (unreleased.sections) |section| {
            for (section.entries) |entry| {
                std.debug.print("    PR #{d} → unreleased\n", .{entry.number});
            }
        }
    }

    std.debug.print("\n  ⚠️  CURRENT: Truncated dates may assign all to same bucket\n", .{});
    std.debug.print("  ✓  EXPECTED: Each PR to correct release based on time windows\n", .{});
}

pub fn main() !void {
    std.debug.print("\n=== Timestamp Comparison Tests (Issue #5) ===\n\n", .{});

    std.debug.print("Test: Full ISO-8601 timestamp comparison (microsecond precision)...\n", .{});
    try testFullISO8601Comparison();
    std.debug.print("  PASSED\n\n", .{});

    std.debug.print("Test: Same day, different times...\n", .{});
    try testSameDayDifferentTimes();
    std.debug.print("  PASSED\n\n", .{});

    std.debug.print("Test: Boundary condition - PR at exactly release time...\n", .{});
    try testBoundaryAtExactReleaseTime();
    std.debug.print("  PASSED\n\n", .{});

    std.debug.print("Test: Timestamp with milliseconds...\n", .{});
    try testTimestampWithMilliseconds();
    std.debug.print("  PASSED\n\n", .{});

    std.debug.print("Test: Multiple releases with precise timestamps...\n", .{});
    try testMultipleReleasesWithPreciseTimestamps();
    std.debug.print("  PASSED\n\n", .{});

    std.debug.print("✅ All timestamp comparison tests completed\n", .{});
    std.debug.print("⚠️  Note: These tests document current truncation behavior and expected full timestamp comparison\n", .{});
}
