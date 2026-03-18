# Mr. Orange — History

## Project Context

**Project:** chlogr  
**Description:** A fast, efficient, native CLI tool to automatically generate changelogs from GitHub tags, pull requests, and issues. Written in Zig v0.15.2.  
**User:** Christian Helle  
**Stack:** Pure Zig stdlib, zero runtime dependencies. CLI binary targeting multiple platforms.  
**Build:** `zig build` | Tests: `zig build test`

## Source Layout

```
src/
  main.zig                 # Main orchestration logic
  cli.zig                  # CLI argument parsing
  token_resolver.zig       # GitHub token resolution (flag → env → gh CLI)
  models.zig               # Data structures
  http_client.zig          # HTTP client wrapper
  github_api.zig           # GitHub API integration
  changelog_generator.zig  # Core changelog logic
  markdown_formatter.zig   # Markdown output formatting
  test_data.zig            # Mock test data
  test.zig                 # Integration tests
```

### Issue #8 — Rebase PR #18 (`fix/8-since-until-tags`) onto main after PR #19 merged

**Context:** PR #19 (timestamp precision fix) was merged to main before PR #18 (since/until tag filtering). Both PRs modified `changelog_generator.zig`, `test.zig`, and `test_data.zig`, causing merge conflicts.

**Integration approach:**
- `filterReleasesByTagRange` from PR #18 is called **first** in `generate()`, before the PR #19 sort/assign logic. The filtered slice is then duped and sorted oldest-first for the greedy single-pass assignment.
- `assigned[]` tracking from PR #19 is preserved unchanged.
- Test data from both PRs is kept (`test_releases_same_day`, `test_releases_two_versions`, `test_pull_requests_pre_first_release` from PR #19; `test_releases_four_versions`, `test_prs_for_four_versions` from PR #18).
- PR #18's tag-filter test expectations (`testSinceTagFilter`, `testUntilTagFilter`, `testBothTagsFilter`) were updated to reflect oldest-first ordering in `changelog.releases[]` — a consequence of PR #19's sort approach.
- All 17 tests pass after rebase.

**Git technique:** Used `git worktree` to create an isolated working directory (`C:\temp\chlogr-rebase`) so a concurrent agent switching branches in the main worktree could not interrupt the in-progress rebase.


**Approach used:**
Both `getReleases` and `getMergedPullRequests` were converted from single-request functions to pagination loops. Each iteration appends `?page=N&per_page=100` to the endpoint URL, copies items into a persistent `ArrayList`, and breaks when the page returns fewer items than `per_page` (signalling the last page). The `per_page` parameter was removed from both public function signatures — callers no longer need to manage limits.

**Key decisions:**
- `initCapacity(allocator, 0)` is the correct idiom for an empty `ArrayList` in Zig 0.15.2 (`.init(allocator)` does not exist).
- `append(allocator, item)` must be used inside the loop (not `appendAssumeCapacity`) because capacity may need to grow.
- `errdefer` on the outer `ArrayList` covers partial accumulation across pages — if any page fetch, parse, or copy fails, all previously copied items are freed correctly.
- URL strings built with `std.fmt.allocPrint` are freed via `defer` immediately after the HTTP call, keeping per-page memory transient.
- `toOwnedSlice(allocator)` is called once at the end to transfer ownership to the caller.
