# Mr. White — History

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

## Learnings

## P1 Wave 2 Review — PRs #21 and #18

### PR #21 — Pagination loop in `github_api.zig` (`fix/7-pagination`)

**Review verdict:** Approved. Implementation is correct and safe.  
**Key observations:**
- Both `getReleases` and `getMergedPullRequests` converted to `?page=N&per_page=100` loops with break-on-partial-page termination.
- `errdefer` on the outer `ArrayList` correctly covers partial accumulation — if any page fails, all previously accumulated items are freed.
- `initCapacity(allocator, 0)` is the correct empty-ArrayList idiom in Zig 0.15.2 (`.init(allocator)` does not exist).
- Per-page URL strings (`allocPrint`) are freed via `defer` immediately after the HTTP call — no unbounded memory growth.
- `per_page` removed from public function signatures — callers no longer manage limits.
- 13 tests; all pass.

### PR #18 — `--since-tag`/`--until-tag` filtering (`fix/8-since-until-tags`)

**Review verdict:** Approved after rebase onto main (conflict with PR #19 timestamp precision fix).  
**Key observations:**
- `filterReleasesByTagRange` is called first in `generate()`, before the sort/assign loop from PR #19 — correct ordering.
- Returns a sub-slice of the original slice; no allocation required.
- `SinceTagNotFound`/`UntilTagNotFound` typed errors give callers (and end users) precise diagnostics.
- Rebase required: `test_data.zig` and `test.zig` both had non-overlapping additions from PR #19; resolved cleanly with `git worktree` isolation.
- Tag-filter test expectations updated to reflect oldest-first ordering in `changelog.releases[]` (a consequence of PR #19's sort approach).
- 17 tests; all pass.
