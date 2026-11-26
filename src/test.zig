const std = @import("std");
const models = @import("models.zig");
const changelog_generator = @import("changelog_generator.zig");
const markdown_formatter = @import("markdown_formatter.zig");
const test_data = @import("test_data.zig");

fn parseIssues(
    allocator: std.mem.Allocator,
    source: []const u8,
) !std.json.Parsed([]models.Issue) {
    return std.json.parseFromSlice([]models.Issue, allocator, source, .{ .ignore_unknown_fields = true });
}

fn findRelease(
    releases: []const changelog_generator.ChangelogRelease,
    version: []const u8,
) ?*const changelog_generator.ChangelogRelease {
    for (releases) |*release| {
        if (std.mem.eql(u8, release.version, version)) {
            return release;
        }
    }
    return null;
}

fn findSection(
    sections: []const changelog_generator.ChangelogSection,
    name: []const u8,
) ?*const changelog_generator.ChangelogSection {
    for (sections) |*section| {
        if (std.mem.eql(u8, section.name, name)) {
            return section;
        }
    }
    return null;
}

fn sectionContainsEntry(
    section: changelog_generator.ChangelogSection,
    number: u32,
) bool {
    for (section.entries) |entry| {
        if (entry.number == number) return true;
    }
    return false;
}

fn changelogContainsEntry(
    changelog: changelog_generator.Changelog,
    number: u32,
) bool {
    for (changelog.releases) |release| {
        for (release.sections) |section| {
            if (sectionContainsEntry(section, number)) return true;
        }
    }

    if (changelog.unreleased) |unreleased| {
        for (unreleased.sections) |section| {
            if (sectionContainsEntry(section, number)) return true;
        }
    }

    return false;
}

test "basic changelog generation groups releases and reports unreleased" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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
    const issues = &[_]models.Issue{};

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs, issues);
    defer gen.deinitChangelog(changelog);

    try std.testing.expect(changelog.releases.len == 2);
    try std.testing.expect(changelog.unreleased != null);

    if (changelog.unreleased) |un| {
        try std.testing.expect(un.sections.len == 2);
    }
}

test "unreleased-only run keeps releases and reports unreleased" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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
    const issues = &[_]models.Issue{};

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs, issues);
    defer gen.deinitChangelog(changelog);

    try std.testing.expect(changelog.releases.len == 1);
    try std.testing.expect(changelog.unreleased != null);

    if (changelog.unreleased) |un| {
        try std.testing.expect(un.sections.len == 2);
    }
}

test "no unreleased section when every pr merges before a release" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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
    const issues = &[_]models.Issue{};

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs, issues);
    defer gen.deinitChangelog(changelog);

    try std.testing.expect(changelog.releases.len == 1);
    try std.testing.expect(changelog.unreleased == null);
}

test "exclude-labels removes matching pull requests" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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
    const issues = &[_]models.Issue{};

    var gen = changelog_generator.ChangelogGenerator.init(allocator, "wontfix");
    const changelog = try gen.generate(releases, prs, issues);
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

test "pull requests without merged at are ignored" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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
    const issues = &[_]models.Issue{};

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs, issues);
    defer gen.deinitChangelog(changelog);

    try std.testing.expect(changelog.releases.len == 2);
    try std.testing.expect(changelog.unreleased == null);
}

test "empty releases yields unreleased changes only" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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
    const issues = &[_]models.Issue{};

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs, issues);
    defer gen.deinitChangelog(changelog);

    try std.testing.expect(changelog.releases.len == 0);
    try std.testing.expect(changelog.unreleased != null);
}

test "empty pull requests yields no unreleased section" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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
    const issues = &[_]models.Issue{};

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs, issues);
    defer gen.deinitChangelog(changelog);

    try std.testing.expect(changelog.releases.len == 2);
    try std.testing.expect(changelog.unreleased == null);
}

test "markdown includes unreleased changes" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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
    const issues = &[_]models.Issue{};

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs, issues);
    defer gen.deinitChangelog(changelog);

    var formatter = markdown_formatter.MarkdownFormatter.init(allocator, std.Io.Threaded.global_single_threaded.io(), "testowner/testrepo");
    const markdown = try formatter.formatWithUnreleased(changelog.releases, changelog.unreleased);
    defer formatter.deinit(markdown);

    try std.testing.expect(std.mem.indexOf(u8, markdown, "Unreleased Changes") != null);
    try std.testing.expect(std.mem.indexOf(u8, markdown, "New unreleased feature Y") != null);
    try std.testing.expect(std.mem.indexOf(u8, markdown, "Unreleased bug fix") != null);
}

test "exclude-labels applies to closed issues" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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

    var issues_parsed = try std.json.parseFromSlice(
        []models.Issue,
        allocator,
        test_data.test_closed_issues_with_excluded_labels,
        .{},
    );
    defer issues_parsed.deinit();
    const issues = issues_parsed.value;

    var gen = changelog_generator.ChangelogGenerator.init(allocator, "wontfix");
    const changelog = try gen.generate(releases, prs, issues);
    defer gen.deinitChangelog(changelog);

    var found_visible = false;
    var found_hidden = false;
    for (changelog.releases) |release| {
        for (release.sections) |section| {
            for (section.entries) |entry| {
                if (entry.number == 920) found_visible = true;
                if (entry.number == 921) found_hidden = true;
            }
        }
    }

    try std.testing.expect(found_visible);
    try std.testing.expect(!found_hidden);
}

test "markdown omits unreleased heading when there are none" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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
    const issues = &[_]models.Issue{};

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs, issues);
    defer gen.deinitChangelog(changelog);

    var formatter = markdown_formatter.MarkdownFormatter.init(allocator, std.Io.Threaded.global_single_threaded.io(), "testowner/testrepo");
    const markdown = try formatter.formatWithUnreleased(changelog.releases, changelog.unreleased);
    defer formatter.deinit(markdown);

    try std.testing.expect(std.mem.indexOf(u8, markdown, "Unreleased Changes") == null);
}

test "closed issues attach to the earliest release after closing" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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

    var issues_parsed = try parseIssues(allocator, test_data.test_closed_issues);
    defer issues_parsed.deinit();
    const issues = issues_parsed.value;

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, &[_]models.PullRequest{}, issues);
    defer gen.deinitChangelog(changelog);

    const v1_2_0 = findRelease(changelog.releases, "v1.2.0") orelse return error.MissingRelease;
    const v1_2_0_closed = findSection(v1_2_0.sections, "Closed Issues") orelse return error.MissingClosedIssuesSection;
    try std.testing.expect(sectionContainsEntry(v1_2_0_closed.*, 910));
    try std.testing.expect(!sectionContainsEntry(v1_2_0_closed.*, 911));
    try std.testing.expect(findSection(v1_2_0.sections, "Bug Fixes") == null);

    const v1_1_0 = findRelease(changelog.releases, "v1.1.0") orelse return error.MissingRelease;
    const v1_1_0_closed = findSection(v1_1_0.sections, "Closed Issues") orelse return error.MissingClosedIssuesSection;
    try std.testing.expect(sectionContainsEntry(v1_1_0_closed.*, 911));
    try std.testing.expect(!sectionContainsEntry(v1_1_0_closed.*, 910));
    try std.testing.expect(findSection(v1_1_0.sections, "Features") == null);

    try std.testing.expect(changelog.unreleased == null);
    try std.testing.expect(!changelogContainsEntry(changelog, 912));
}

test "markdown includes the closed issues section" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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

    var issues_parsed = try parseIssues(allocator, test_data.test_closed_issues);
    defer issues_parsed.deinit();
    const issues = issues_parsed.value;

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs, issues);
    defer gen.deinitChangelog(changelog);

    var formatter = markdown_formatter.MarkdownFormatter.init(allocator, std.Io.Threaded.global_single_threaded.io(), "testowner/testrepo");
    const markdown = try formatter.formatWithUnreleased(changelog.releases, changelog.unreleased);
    defer formatter.deinit(markdown);

    try std.testing.expect(std.mem.indexOf(u8, markdown, "### Closed Issues") != null);
    try std.testing.expect(std.mem.indexOf(u8, markdown, "Close onboarding issue") != null);
    try std.testing.expect(std.mem.indexOf(u8, markdown, "Close docs issue") != null);
    try std.testing.expect(std.mem.indexOf(u8, markdown, "Close unreleased issue") == null);
}

test "closed issues skip entries carrying a pull request marker" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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

    var issues_parsed = try parseIssues(allocator, test_data.test_closed_issues_with_pull_request_marker);
    defer issues_parsed.deinit();
    const issues = issues_parsed.value;

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, &[_]models.PullRequest{}, issues);
    defer gen.deinitChangelog(changelog);

    try std.testing.expect(changelogContainsEntry(changelog, 910));
    try std.testing.expect(changelogContainsEntry(changelog, 912));
    try std.testing.expect(!changelogContainsEntry(changelog, 911));
}

test "label categorization picks features bug fixes and default" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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
    const issues = &[_]models.Issue{};

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs, issues);
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

test "legacy format entry point still renders" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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
    const issues = &[_]models.Issue{};

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs, issues);
    defer gen.deinitChangelog(changelog);

    var formatter = markdown_formatter.MarkdownFormatter.init(allocator, std.Io.Threaded.global_single_threaded.io(), "testowner/testrepo");
    const markdown = try formatter.format(changelog.releases);
    defer formatter.deinit(markdown);

    try std.testing.expect(markdown.len > 0);
}

// Regression: a PR whose merged_at equals the release's published_at must appear in
// that release (boundary is inclusive), not in unreleased.
test "same-day merge belongs to that release" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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
    const issues = &[_]models.Issue{};

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs, issues);
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

test "since-tag keeps releases from that tag onward" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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
    const issues = &[_]models.Issue{};

    // since_tag = v1.2.0 → includes v1.2.0, v1.1.0, v1.0.0; sorted newest-first in result
    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    gen.since_tag = "v1.2.0";
    const changelog = try gen.generate(releases, prs, issues);
    defer gen.deinitChangelog(changelog);

    try std.testing.expect(changelog.releases.len == 3);
    try std.testing.expectEqualStrings("v1.2.0", changelog.releases[0].version);
    try std.testing.expectEqualStrings("v1.0.0", changelog.releases[2].version);
}

// Regression: a PR that qualifies for multiple releases must appear in exactly one
// (the earliest qualifying release), never duplicated.
test "a pull request appears in exactly one release" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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
    const issues = &[_]models.Issue{};

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs, issues);
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

test "until-tag keeps releases up to that tag" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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
    const issues = &[_]models.Issue{};

    // until_tag = v1.2.0 → includes v1.3.0, v1.2.0; sorted newest-first in result
    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    gen.until_tag = "v1.2.0";
    const changelog = try gen.generate(releases, prs, issues);
    defer gen.deinitChangelog(changelog);

    try std.testing.expect(changelog.releases.len == 2);
    try std.testing.expectEqualStrings("v1.3.0", changelog.releases[0].version);
    try std.testing.expectEqualStrings("v1.2.0", changelog.releases[1].version);
}

test "both tags bound the release range" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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
    const issues = &[_]models.Issue{};

    // since_tag = v1.1.0, until_tag = v1.3.0 → includes v1.3.0, v1.2.0, v1.1.0; sorted newest-first
    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    gen.since_tag = "v1.1.0";
    gen.until_tag = "v1.3.0";
    const changelog = try gen.generate(releases, prs, issues);
    defer gen.deinitChangelog(changelog);

    try std.testing.expect(changelog.releases.len == 3);
    try std.testing.expectEqualStrings("v1.3.0", changelog.releases[0].version);
    try std.testing.expectEqualStrings("v1.1.0", changelog.releases[2].version);
}

test "exclude-labels matches label names exactly" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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
    const issues = &[_]models.Issue{};

    // Only "bug" should be excluded; "bug-fix" and "debug" must survive.
    var gen = changelog_generator.ChangelogGenerator.init(allocator, "bug");
    const changelog = try gen.generate(releases, prs, issues);
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

test "exclude-labels accepts a comma separated list" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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
    const issues = &[_]models.Issue{};

    // Both "bug" and "enhancement" are excluded; "feature" must survive.
    var gen = changelog_generator.ChangelogGenerator.init(allocator, "bug,enhancement");
    const changelog = try gen.generate(releases, prs, issues);
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

test "unknown tag reports a not-found error" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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
    const issues = &[_]models.Issue{};

    // since_tag that doesn't exist → error.SinceTagNotFound
    var gen_since = changelog_generator.ChangelogGenerator.init(allocator, null);
    gen_since.since_tag = "v9.9.9";
    const result_since = gen_since.generate(releases, prs, issues);
    try std.testing.expectError(error.SinceTagNotFound, result_since);

    // until_tag that doesn't exist → error.UntilTagNotFound
    var gen_until = changelog_generator.ChangelogGenerator.init(allocator, null);
    gen_until.until_tag = "v9.9.9";
    const result_until = gen_until.generate(releases, prs, issues);
    try std.testing.expectError(error.UntilTagNotFound, result_until);
}

test "release links use the configured repo slug" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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
    const issues = &[_]models.Issue{};

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs, issues);
    defer gen.deinitChangelog(changelog);

    const repo_slug = "myorg/myrepo";
    var formatter = markdown_formatter.MarkdownFormatter.init(allocator, std.Io.Threaded.global_single_threaded.io(), repo_slug);
    const markdown = try formatter.formatWithUnreleased(changelog.releases, changelog.unreleased);
    defer formatter.deinit(markdown);

    // Release links must contain the provided repo slug
    try std.testing.expect(std.mem.indexOf(u8, markdown, "https://github.com/myorg/myrepo/releases/tag/") != null);
    // Hardcoded placeholder must not appear in release header links
    try std.testing.expect(std.mem.indexOf(u8, markdown, "https://github.com/owner/repo/releases/tag/") == null);
}

// Regression: PRs labelled "security" or "vulnerability" must land in the
// "Security Vulnerability Fixes" section, while "bug" labels stay in "Bug Fixes".
test "security and vulnerability labels get their own section" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
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
        test_data.test_prs_security_labels,
        .{},
    );
    defer prs_parsed.deinit();
    const prs = prs_parsed.value;
    const issues = &[_]models.Issue{};

    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs, issues);
    defer gen.deinitChangelog(changelog);

    const v1_1_0 = findRelease(changelog.releases, "v1.1.0") orelse return error.MissingRelease;
    const security = findSection(v1_1_0.sections, "Security Vulnerability Fixes") orelse
        return error.MissingSecuritySection;

    try std.testing.expect(sectionContainsEntry(security.*, 900));
    try std.testing.expect(sectionContainsEntry(security.*, 901));
    try std.testing.expect(!sectionContainsEntry(security.*, 902));

    const bug_fixes = findSection(v1_1_0.sections, "Bug Fixes") orelse return error.MissingBugFixesSection;
    try std.testing.expect(sectionContainsEntry(bug_fixes.*, 902));
    try std.testing.expect(!sectionContainsEntry(bug_fixes.*, 900));
}

pub fn main() !void {
    std.debug.print("=== Changelog Generator Demo ===\n\n", .{});
    std.debug.print("\n=== Integration Test with Output ===\n\n", .{});

    var gpa: std.heap.DebugAllocator(.{}) = .init;
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
        std.debug.print("  - {s} ({s})\n", .{ release.tag_name.?, release.published_at.? });
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

    std.debug.print("\nParsing mock closed issues...\n", .{});
    var issues_parsed = try parseIssues(allocator, test_data.test_closed_issues);
    defer issues_parsed.deinit();
    const issues = issues_parsed.value;

    std.debug.print("Found {d} closed issues\n", .{issues.len});
    for (issues) |issue| {
        std.debug.print("  - #{d}: {s} by @{s}\n", .{ issue.number, issue.title, issue.user.login });
        for (issue.labels) |label| {
            std.debug.print("      Label: {s}\n", .{label.name});
        }
    }

    std.debug.print("\nGenerating changelog...\n", .{});
    var gen = changelog_generator.ChangelogGenerator.init(allocator, null);
    const changelog = try gen.generate(releases, prs, issues);
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
    var formatter = markdown_formatter.MarkdownFormatter.init(allocator, std.Io.Threaded.global_single_threaded.io(), "testowner/testrepo");
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
