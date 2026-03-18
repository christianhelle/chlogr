const std = @import("std");
const models = @import("models.zig");
const changelog_generator = @import("changelog_generator.zig");
const markdown_formatter = @import("markdown_formatter.zig");
const test_data = @import("test_data.zig");

fn testBasicChangelogGeneration() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var releases_parsed = try std.json.parseFromSlice(
        []models.Release,
        allocator,
        test_data.test_releases,
        .{},
    );
    defer releases_parsed.deinit();
    const releases = releases_parsed.value;

    var prs_parsed = try std.json.parseFromSlice(
        []models.PullRequest,
        allocator,
        test_data.test_pull_requests,
        .{},
    );
    defer prs_parsed.deinit();
    const prs = prs_parsed.value;

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs);
    defer gen.deinitChangelog(changelog);

    try std.testing.expect(changelog.releases.len == 2);
    try std.testing.expect(changelog.unreleased != null);

    if (changelog.unreleased) |un| {
        try std.testing.expect(un.sections.len == 2);
    }
}

fn testUnreleasedChangesOnly() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var releases_parsed = try std.json.parseFromSlice(
        []models.Release,
        allocator,
        test_data.test_releases_with_unreleased,
        .{},
    );
    defer releases_parsed.deinit();
    const releases = releases_parsed.value;

    var prs_parsed = try std.json.parseFromSlice(
        []models.PullRequest,
        allocator,
        test_data.test_pull_requests_all_unreleased,
        .{},
    );
    defer prs_parsed.deinit();
    const prs = prs_parsed.value;

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs);
    defer gen.deinitChangelog(changelog);

    try std.testing.expect(changelog.releases.len == 1);
    try std.testing.expect(changelog.unreleased != null);

    if (changelog.unreleased) |un| {
        try std.testing.expect(un.sections.len == 2);
    }
}

fn testNoUnreleasedChanges() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var releases_parsed = try std.json.parseFromSlice(
        []models.Release,
        allocator,
        test_data.test_releases_with_unreleased,
        .{},
    );
    defer releases_parsed.deinit();
    const releases = releases_parsed.value;

    var prs_parsed = try std.json.parseFromSlice(
        []models.PullRequest,
        allocator,
        test_data.test_pull_requests_all_merged_before_release,
        .{},
    );
    defer prs_parsed.deinit();
    const prs = prs_parsed.value;

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs);
    defer gen.deinitChangelog(changelog);

    try std.testing.expect(changelog.releases.len == 1);
    try std.testing.expect(changelog.unreleased == null);
}

fn testExcludeLabels() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var releases_parsed = try std.json.parseFromSlice(
        []models.Release,
        allocator,
        test_data.test_releases,
        .{},
    );
    defer releases_parsed.deinit();
    const releases = releases_parsed.value;

    var prs_parsed = try std.json.parseFromSlice(
        []models.PullRequest,
        allocator,
        test_data.test_pull_requests_with_excluded_labels,
        .{},
    );
    defer prs_parsed.deinit();
    const prs = prs_parsed.value;

    var gen = changelog_generator.ChangelogGenerator.init(allocator, "wontfix");
    const changelog = try gen.generate(releases, prs);
    defer gen.deinitChangelog(changelog);

    try std.testing.expect(changelog.releases.len == 2);

    var found_excluded = false;
    for (changelog.releases) |release| {
        for (release.sections) |section| {
            for (section.entries) |entry| {
                if (std.mem.eql(u8, entry.title, "Should be excluded") or
                    std.mem.eql(u8, entry.title, "Should also be excluded"))
                {
                    found_excluded = true;
                }
            }
        }
    }
    try std.testing.expect(!found_excluded);
}

fn testNoMergedAt() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var releases_parsed = try std.json.parseFromSlice(
        []models.Release,
        allocator,
        test_data.test_releases,
        .{},
    );
    defer releases_parsed.deinit();
    const releases = releases_parsed.value;

    var prs_parsed = try std.json.parseFromSlice(
        []models.PullRequest,
        allocator,
        test_data.test_pull_requests_no_merged_at,
        .{},
    );
    defer prs_parsed.deinit();
    const prs = prs_parsed.value;

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs);
    defer gen.deinitChangelog(changelog);

    try std.testing.expect(changelog.releases.len == 2);
    try std.testing.expect(changelog.unreleased == null);
}

fn testEmptyReleases() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var releases_parsed = try std.json.parseFromSlice(
        []models.Release,
        allocator,
        test_data.test_empty_releases,
        .{},
    );
    defer releases_parsed.deinit();
    const releases = releases_parsed.value;

    var prs_parsed = try std.json.parseFromSlice(
        []models.PullRequest,
        allocator,
        test_data.test_pull_requests_all_unreleased,
        .{},
    );
    defer prs_parsed.deinit();
    const prs = prs_parsed.value;

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs);
    defer gen.deinitChangelog(changelog);

    try std.testing.expect(changelog.releases.len == 0);
    try std.testing.expect(changelog.unreleased != null);
}

fn testEmptyPullRequests() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var releases_parsed = try std.json.parseFromSlice(
        []models.Release,
        allocator,
        test_data.test_releases,
        .{},
    );
    defer releases_parsed.deinit();
    const releases = releases_parsed.value;

    var prs_parsed = try std.json.parseFromSlice(
        []models.PullRequest,
        allocator,
        test_data.test_empty_prs,
        .{},
    );
    defer prs_parsed.deinit();
    const prs = prs_parsed.value;

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs);
    defer gen.deinitChangelog(changelog);

    try std.testing.expect(changelog.releases.len == 2);
    try std.testing.expect(changelog.unreleased == null);
}

fn testMarkdownFormatterWithUnreleased() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var releases_parsed = try std.json.parseFromSlice(
        []models.Release,
        allocator,
        test_data.test_releases,
        .{},
    );
    defer releases_parsed.deinit();
    const releases = releases_parsed.value;

    var prs_parsed = try std.json.parseFromSlice(
        []models.PullRequest,
        allocator,
        test_data.test_pull_requests,
        .{},
    );
    defer prs_parsed.deinit();
    const prs = prs_parsed.value;

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs);
    defer gen.deinitChangelog(changelog);

    var formatter = markdown_formatter.MarkdownFormatter.init(allocator, "testowner/testrepo");
    const markdown = try formatter.formatWithUnreleased(changelog.releases, changelog.unreleased);
    defer formatter.deinit(markdown);

    try std.testing.expect(std.mem.indexOf(u8, markdown, "Unreleased Changes") != null);
    try std.testing.expect(std.mem.indexOf(u8, markdown, "New unreleased feature Y") != null);
    try std.testing.expect(std.mem.indexOf(u8, markdown, "Unreleased bug fix") != null);
}

fn testMarkdownFormatterWithoutUnreleased() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var releases_parsed = try std.json.parseFromSlice(
        []models.Release,
        allocator,
        test_data.test_releases_with_unreleased,
        .{},
    );
    defer releases_parsed.deinit();
    const releases = releases_parsed.value;

    var prs_parsed = try std.json.parseFromSlice(
        []models.PullRequest,
        allocator,
        test_data.test_pull_requests_all_merged_before_release,
        .{},
    );
    defer prs_parsed.deinit();
    const prs = prs_parsed.value;

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs);
    defer gen.deinitChangelog(changelog);

    var formatter = markdown_formatter.MarkdownFormatter.init(allocator, "testowner/testrepo");
    const markdown = try formatter.formatWithUnreleased(changelog.releases, changelog.unreleased);
    defer formatter.deinit(markdown);

    try std.testing.expect(std.mem.indexOf(u8, markdown, "Unreleased Changes") == null);
}

fn testCategorization() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var releases_parsed = try std.json.parseFromSlice(
        []models.Release,
        allocator,
        test_data.test_releases,
        .{},
    );
    defer releases_parsed.deinit();
    const releases = releases_parsed.value;

    var prs_parsed = try std.json.parseFromSlice(
        []models.PullRequest,
        allocator,
        test_data.test_pull_requests,
        .{},
    );
    defer prs_parsed.deinit();
    const prs = prs_parsed.value;

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs);
    defer gen.deinitChangelog(changelog);

    for (changelog.releases) |release| {
        for (release.sections) |section| {
            for (section.entries) |entry| {
                if (std.mem.indexOf(u8, entry.title, "feature") != null or
                    std.mem.indexOf(u8, entry.title, "enhancement") != null)
                {
                    try std.testing.expect(std.mem.eql(u8, section.name, "Features"));
                } else if (std.mem.indexOf(u8, entry.title, "bug") != null or
                    std.mem.indexOf(u8, entry.title, "fix") != null)
                {
                    try std.testing.expect(std.mem.eql(u8, section.name, "Bug Fixes"));
                } else {
                    try std.testing.expect(std.mem.eql(u8, section.name, "Merged Pull Requests"));
                }
            }
        }
    }

    if (changelog.unreleased) |un| {
        for (un.sections) |section| {
            for (section.entries) |entry| {
                if (std.mem.indexOf(u8, entry.title, "feature") != null or
                    std.mem.indexOf(u8, entry.title, "enhancement") != null)
                {
                    try std.testing.expect(std.mem.eql(u8, section.name, "Features"));
                } else if (std.mem.indexOf(u8, entry.title, "bug") != null or
                    std.mem.indexOf(u8, entry.title, "fix") != null)
                {
                    try std.testing.expect(std.mem.eql(u8, section.name, "Bug Fixes"));
                } else {
                    try std.testing.expect(std.mem.eql(u8, section.name, "Merged Pull Requests"));
                }
            }
        }
    }
}

fn testLegacyFormatMethod() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var releases_parsed = try std.json.parseFromSlice(
        []models.Release,
        allocator,
        test_data.test_releases,
        .{},
    );
    defer releases_parsed.deinit();
    const releases = releases_parsed.value;

    var prs_parsed = try std.json.parseFromSlice(
        []models.PullRequest,
        allocator,
        test_data.test_pull_requests,
        .{},
    );
    defer prs_parsed.deinit();
    const prs = prs_parsed.value;

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs);
    defer gen.deinitChangelog(changelog);

    var formatter = markdown_formatter.MarkdownFormatter.init(allocator, "testowner/testrepo");
    const markdown = try formatter.format(changelog.releases);
    defer formatter.deinit(markdown);

    try std.testing.expect(markdown.len > 0);
}

// Regression: a PR whose merged_at equals the release's published_at must appear in
// that release (boundary is inclusive), not in unreleased.
fn testSameDayMergeHandling() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var releases_parsed = try std.json.parseFromSlice(
        []models.Release,
        allocator,
        test_data.test_releases_same_day,
        .{},
    );
    defer releases_parsed.deinit();
    const releases = releases_parsed.value;

    var prs_parsed = try std.json.parseFromSlice(
        []models.PullRequest,
        allocator,
        test_data.test_pull_requests_same_day_as_release,
        .{},
    );
    defer prs_parsed.deinit();
    const prs = prs_parsed.value;

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs);
    defer gen.deinitChangelog(changelog);

    try std.testing.expect(changelog.releases.len == 1);
    try std.testing.expect(changelog.unreleased == null);

    var found_pr = false;
    for (changelog.releases) |release| {
        for (release.sections) |section| {
            for (section.entries) |entry| {
                if (entry.number == 500) found_pr = true;
            }
        }
    }
    try std.testing.expect(found_pr);
}

fn testSinceTagFilter() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var releases_parsed = try std.json.parseFromSlice(
        []models.Release,
        allocator,
        test_data.test_releases_four_versions,
        .{},
    );
    defer releases_parsed.deinit();
    const releases = releases_parsed.value;

    var prs_parsed = try std.json.parseFromSlice(
        []models.PullRequest,
        allocator,
        test_data.test_prs_for_four_versions,
        .{},
    );
    defer prs_parsed.deinit();
    const prs = prs_parsed.value;

    // since_tag = v1.2.0 → includes v1.2.0, v1.1.0, v1.0.0; sorted newest-first in result
    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    gen.since_tag = "v1.2.0";
    const changelog = try gen.generate(releases, prs);
    defer gen.deinitChangelog(changelog);

    try std.testing.expect(changelog.releases.len == 3);
    try std.testing.expectEqualStrings("v1.2.0", changelog.releases[0].version);
    try std.testing.expectEqualStrings("v1.0.0", changelog.releases[2].version);
}

// Regression: a PR that qualifies for multiple releases must appear in exactly one
// (the earliest qualifying release), never duplicated.
fn testNoDuplicateAssignment() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var releases_parsed = try std.json.parseFromSlice(
        []models.Release,
        allocator,
        test_data.test_releases_two_versions,
        .{},
    );
    defer releases_parsed.deinit();
    const releases = releases_parsed.value;

    var prs_parsed = try std.json.parseFromSlice(
        []models.PullRequest,
        allocator,
        test_data.test_pull_requests_pre_first_release,
        .{},
    );
    defer prs_parsed.deinit();
    const prs = prs_parsed.value;

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs);
    defer gen.deinitChangelog(changelog);

    var total_count: usize = 0;
    for (changelog.releases) |release| {
        for (release.sections) |section| {
            for (section.entries) |entry| {
                if (entry.number == 600) total_count += 1;
            }
        }
    }
    try std.testing.expect(total_count == 1);
    try std.testing.expect(changelog.unreleased == null);
}

fn testUntilTagFilter() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var releases_parsed = try std.json.parseFromSlice(
        []models.Release,
        allocator,
        test_data.test_releases_four_versions,
        .{},
    );
    defer releases_parsed.deinit();
    const releases = releases_parsed.value;

    var prs_parsed = try std.json.parseFromSlice(
        []models.PullRequest,
        allocator,
        test_data.test_prs_for_four_versions,
        .{},
    );
    defer prs_parsed.deinit();
    const prs = prs_parsed.value;

    // until_tag = v1.2.0 → includes v1.3.0, v1.2.0; sorted newest-first in result
    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    gen.until_tag = "v1.2.0";
    const changelog = try gen.generate(releases, prs);
    defer gen.deinitChangelog(changelog);

    try std.testing.expect(changelog.releases.len == 2);
    try std.testing.expectEqualStrings("v1.3.0", changelog.releases[0].version);
    try std.testing.expectEqualStrings("v1.2.0", changelog.releases[1].version);
}

fn testBothTagsFilter() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var releases_parsed = try std.json.parseFromSlice(
        []models.Release,
        allocator,
        test_data.test_releases_four_versions,
        .{},
    );
    defer releases_parsed.deinit();
    const releases = releases_parsed.value;

    var prs_parsed = try std.json.parseFromSlice(
        []models.PullRequest,
        allocator,
        test_data.test_prs_for_four_versions,
        .{},
    );
    defer prs_parsed.deinit();
    const prs = prs_parsed.value;

    // since_tag = v1.1.0, until_tag = v1.3.0 → includes v1.3.0, v1.2.0, v1.1.0; sorted newest-first
    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    gen.since_tag = "v1.1.0";
    gen.until_tag = "v1.3.0";
    const changelog = try gen.generate(releases, prs);
    defer gen.deinitChangelog(changelog);

    try std.testing.expect(changelog.releases.len == 3);
    try std.testing.expectEqualStrings("v1.3.0", changelog.releases[0].version);
    try std.testing.expectEqualStrings("v1.1.0", changelog.releases[2].version);
}

fn testExcludeLabelsExactMatch() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Reuse the two-release fixture; all test PRs merge before v1.1.0 (2024-01-10).
    var releases_parsed = try std.json.parseFromSlice(
        []models.Release,
        allocator,
        test_data.test_releases,
        .{},
    );
    defer releases_parsed.deinit();
    const releases = releases_parsed.value;

    var prs_parsed = try std.json.parseFromSlice(
        []models.PullRequest,
        allocator,
        test_data.test_prs_exact_label_match,
        .{},
    );
    defer prs_parsed.deinit();
    const prs = prs_parsed.value;

    // Only "bug" should be excluded; "bug-fix" and "debug" must survive.
    var gen = changelog_generator.ChangelogGenerator.init(allocator, "bug");
    const changelog = try gen.generate(releases, prs);
    defer gen.deinitChangelog(changelog);

    var found_bug: bool = false;
    var found_bug_fix: bool = false;
    var found_debug: bool = false;
    for (changelog.releases) |release| {
        for (release.sections) |section| {
            for (section.entries) |entry| {
                if (entry.number == 700) found_bug = true;
                if (entry.number == 701) found_bug_fix = true;
                if (entry.number == 702) found_debug = true;
            }
        }
    }
    // PR with exact "bug" label must be excluded.
    try std.testing.expect(!found_bug);
    // PRs with "bug-fix" and "debug" labels must NOT be excluded.
    try std.testing.expect(found_bug_fix);
    try std.testing.expect(found_debug);
}

fn testExcludeLabelsCSV() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var releases_parsed = try std.json.parseFromSlice(
        []models.Release,
        allocator,
        test_data.test_releases,
        .{},
    );
    defer releases_parsed.deinit();
    const releases = releases_parsed.value;

    var prs_parsed = try std.json.parseFromSlice(
        []models.PullRequest,
        allocator,
        test_data.test_prs_csv_labels,
        .{},
    );
    defer prs_parsed.deinit();
    const prs = prs_parsed.value;

    // Both "bug" and "enhancement" are excluded; "feature" must survive.
    var gen = changelog_generator.ChangelogGenerator.init(allocator, "bug,enhancement");
    const changelog = try gen.generate(releases, prs);
    defer gen.deinitChangelog(changelog);

    var found_bug: bool = false;
    var found_enhancement: bool = false;
    var found_feature: bool = false;
    for (changelog.releases) |release| {
        for (release.sections) |section| {
            for (section.entries) |entry| {
                if (entry.number == 800) found_bug = true;
                if (entry.number == 801) found_enhancement = true;
                if (entry.number == 802) found_feature = true;
            }
        }
    }
    try std.testing.expect(!found_bug);
    try std.testing.expect(!found_enhancement);
    try std.testing.expect(found_feature);
}

fn testTagNotFound() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var releases_parsed = try std.json.parseFromSlice(
        []models.Release,
        allocator,
        test_data.test_releases_four_versions,
        .{},
    );
    defer releases_parsed.deinit();
    const releases = releases_parsed.value;

    var prs_parsed = try std.json.parseFromSlice(
        []models.PullRequest,
        allocator,
        test_data.test_prs_for_four_versions,
        .{},
    );
    defer prs_parsed.deinit();
    const prs = prs_parsed.value;

    // since_tag that doesn't exist → error.SinceTagNotFound
    var gen_since = changelog_generator.ChangelogGenerator.init(allocator, null);
    gen_since.since_tag = "v9.9.9";
    const result_since = gen_since.generate(releases, prs);
    try std.testing.expectError(error.SinceTagNotFound, result_since);

    // until_tag that doesn't exist → error.UntilTagNotFound
    var gen_until = changelog_generator.ChangelogGenerator.init(allocator, null);
    gen_until.until_tag = "v9.9.9";
    const result_until = gen_until.generate(releases, prs);
    try std.testing.expectError(error.UntilTagNotFound, result_until);
}

fn testRepoSlugInReleaseLinks() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var releases_parsed = try std.json.parseFromSlice(
        []models.Release,
        allocator,
        test_data.test_releases,
        .{},
    );
    defer releases_parsed.deinit();
    const releases = releases_parsed.value;

    var prs_parsed = try std.json.parseFromSlice(
        []models.PullRequest,
        allocator,
        test_data.test_pull_requests,
        .{},
    );
    defer prs_parsed.deinit();
    const prs = prs_parsed.value;

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs);
    defer gen.deinitChangelog(changelog);

    const repo_slug = "myorg/myrepo";
    var formatter = markdown_formatter.MarkdownFormatter.init(allocator, repo_slug);
    const markdown = try formatter.formatWithUnreleased(changelog.releases, changelog.unreleased);
    defer formatter.deinit(markdown);

    // Release links must contain the provided repo slug
    try std.testing.expect(std.mem.indexOf(u8, markdown, "https://github.com/myorg/myrepo/releases/tag/") != null);
    // Hardcoded placeholder must not appear in release header links
    try std.testing.expect(std.mem.indexOf(u8, markdown, "https://github.com/owner/repo/releases/tag/") == null);
}

pub fn main() !void {
    std.debug.print("=== Changelog Generator Integration Test ===\n\n", .{});

    std.debug.print("Running testBasicChangelogGeneration...\n", .{});
    try testBasicChangelogGeneration();
    std.debug.print("  PASSED\n", .{});

    std.debug.print("Running testUnreleasedChangesOnly...\n", .{});
    try testUnreleasedChangesOnly();
    std.debug.print("  PASSED\n", .{});

    std.debug.print("Running testNoUnreleasedChanges...\n", .{});
    try testNoUnreleasedChanges();
    std.debug.print("  PASSED\n", .{});

    std.debug.print("Running testExcludeLabels...\n", .{});
    try testExcludeLabels();
    std.debug.print("  PASSED\n", .{});

    std.debug.print("Running testNoMergedAt...\n", .{});
    try testNoMergedAt();
    std.debug.print("  PASSED\n", .{});

    std.debug.print("Running testEmptyReleases...\n", .{});
    try testEmptyReleases();
    std.debug.print("  PASSED\n", .{});

    std.debug.print("Running testEmptyPullRequests...\n", .{});
    try testEmptyPullRequests();
    std.debug.print("  PASSED\n", .{});

    std.debug.print("Running testMarkdownFormatterWithUnreleased...\n", .{});
    try testMarkdownFormatterWithUnreleased();
    std.debug.print("  PASSED\n", .{});

    std.debug.print("Running testMarkdownFormatterWithoutUnreleased...\n", .{});
    try testMarkdownFormatterWithoutUnreleased();
    std.debug.print("  PASSED\n", .{});

    std.debug.print("Running testCategorization...\n", .{});
    try testCategorization();
    std.debug.print("  PASSED\n", .{});

    std.debug.print("Running testLegacyFormatMethod...\n", .{});
    try testLegacyFormatMethod();
    std.debug.print("  PASSED\n", .{});

    std.debug.print("Running testSameDayMergeHandling...\n", .{});
    try testSameDayMergeHandling();
    std.debug.print("  PASSED\n", .{});

    std.debug.print("Running testNoDuplicateAssignment...\n", .{});
    try testNoDuplicateAssignment();
    std.debug.print("  PASSED\n", .{});

    std.debug.print("Running testSinceTagFilter...\n", .{});
    try testSinceTagFilter();
    std.debug.print("  PASSED\n", .{});

    std.debug.print("Running testUntilTagFilter...\n", .{});
    try testUntilTagFilter();
    std.debug.print("  PASSED\n", .{});

    std.debug.print("Running testBothTagsFilter...\n", .{});
    try testBothTagsFilter();
    std.debug.print("  PASSED\n", .{});

    std.debug.print("Running testTagNotFound...\n", .{});
    try testTagNotFound();
    std.debug.print("  PASSED\n", .{});

    std.debug.print("Running testExcludeLabelsExactMatch...\n", .{});
    try testExcludeLabelsExactMatch();
    std.debug.print("  PASSED\n", .{});

    std.debug.print("Running testExcludeLabelsCSV...\n", .{});
    try testExcludeLabelsCSV();
    std.debug.print("  PASSED\n", .{});

    std.debug.print("Running testRepoSlugInReleaseLinks...\n", .{});
    try testRepoSlugInReleaseLinks();
    std.debug.print("  PASSED\n", .{});

    std.debug.print("\n=== Integration Test with Output ===\n\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Parsing mock releases...\n", .{});
    var releases_parsed = try std.json.parseFromSlice(
        []models.Release,
        allocator,
        test_data.test_releases,
        .{},
    );
    defer releases_parsed.deinit();
    const releases = releases_parsed.value;

    std.debug.print("Found {d} releases\n", .{releases.len});
    for (releases) |release| {
        std.debug.print("  - {s} ({s})\n", .{ release.tag_name, release.published_at });
    }

    std.debug.print("\nParsing mock pull requests...\n", .{});
    var prs_parsed = try std.json.parseFromSlice(
        []models.PullRequest,
        allocator,
        test_data.test_pull_requests,
        .{},
    );
    defer prs_parsed.deinit();
    const prs = prs_parsed.value;

    std.debug.print("Found {d} pull requests\n", .{prs.len});
    for (prs) |pr| {
        std.debug.print("  - #{d}: {s} by @{s}\n", .{ pr.number, pr.title, pr.user.login });
        for (pr.labels) |label| {
            std.debug.print("      Label: {s}\n", .{label.name});
        }
    }

    std.debug.print("\nGenerating changelog...\n", .{});
    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs);
    defer gen.deinitChangelog(changelog);

    std.debug.print("Generated {d} releases in changelog\n", .{changelog.releases.len});
    for (changelog.releases) |rel| {
        std.debug.print("  Release {s}: {d} sections\n", .{ rel.version, rel.sections.len });
        for (rel.sections) |sec| {
            std.debug.print("    - {s}: {d} entries\n", .{ sec.name, sec.entries.len });
        }
    }

    if (changelog.unreleased) |un| {
        std.debug.print("Unreleased changes: {d} sections\n", .{un.sections.len});
        for (un.sections) |sec| {
            std.debug.print("    - {s}: {d} entries\n", .{ sec.name, sec.entries.len });
        }
    }

    std.debug.print("\nFormatting to Markdown...\n", .{});
    var formatter = markdown_formatter.MarkdownFormatter.init(allocator, "testowner/testrepo");
    const markdown = try formatter.formatWithUnreleased(changelog.releases, changelog.unreleased);
    defer formatter.deinit(markdown);

    const output_path = "CHANGELOG_TEST.md";
    try formatter.writeToFile(output_path, markdown);
    std.debug.print("Wrote changelog to {s}\n\n", .{output_path});

    std.debug.print("=== Sample Output (first 700 chars) ===\n", .{});
    const sample_len = @min(700, markdown.len);
    std.debug.print("{s}\n", .{markdown[0..sample_len]});
    if (markdown.len > sample_len) {
        std.debug.print("... (truncated, total {d} bytes)\n", .{markdown.len});
    }

    std.debug.print("\n✅ Integration test completed successfully!\n", .{});
}
