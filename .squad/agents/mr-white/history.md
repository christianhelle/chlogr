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

## PR #35 Review — Wire `--parallel` into `main.zig` (`feature/30-wire-parallel-main`)

**Review verdict:** Approved and merged (squash). Closes #30.  
**Key observations:**
- Only `src/main.zig` modified (+35/−16) — correct scope.
- Labeled block pattern (`blk:` + `break :blk`) assigns `FetchedData` struct from either the parallel or sequential path. Idiomatic Zig for if/else expressions producing a value.
- `--parallel` true → `ParallelFetcher.init()` + `fetch()` called; false (default) → existing sequential `getReleases()` + `getMergedPullRequests()`.
- Memory ownership is clean: `freeReleases()` and `freePullRequests()` only use `self.allocator` (not the HTTP client), so they're safe to call on data fetched by `ParallelFetcher` since both paths share the same GPA allocator.
- Single `defer` per free call after the if/else block — no double-free risk.
- Error handling on parallel path mirrors the sequential style (descriptive messages + return err).
- CI green on all 3 platforms (ubuntu, macOS, windows); local build passes; all 20 tests pass.
- #31 (parallel progress polish) remains as the final step.

## PR #36 Review — Per-fetcher progress in parallel mode (`feature/31-parallel-progress`)

**Review verdict:** Approved and merged (squash). Closes #31.  
**Key observations:**
- Only `src/github_api.zig` modified (+2/−4) — minimal, correct scope.
- `\r` replaced with `\n` in per-page progress prints in both `getReleases()` and `getMergedPullRequests()` pagination loops.
- Trailing cleanup `std.debug.print("\n", .{})` after each loop correctly removed — no longer needed since each line self-terminates with `\n`.
- `\n` is safe for concurrent writers (no garbled output) and works in CI/CD environments where `\r` may not render.
- Trade-off: slightly more verbose sequential output (each page on its own line). Acceptable.
- Build passes; all 20 tests pass.

## Parallel Fetch Series — Complete ✅

All 5 issues (#27–#31) shipped via PRs #32–#36:

| PR | Issue | Summary |
|----|-------|---------|
| #32 | #27 | `ParallelFetcher` struct with thread-based concurrent fetching |
| #33 | #28 | Thread-safe error handling in `ParallelFetcher` |
| #34 | #29 | `--parallel` CLI flag in `cli.zig` |
| #35 | #30 | Wire `--parallel` into `main.zig` orchestration |
| #36 | #31 | Fix progress output for parallel mode (`\r` → `\n`) |

chlogr now supports `--parallel` for concurrent GitHub API data fetching. Sequential mode (default) unchanged. Series complete.

## PR #38 — README Hygiene Rule (`docs/readme-hygiene-instructions`)

**Review verdict:** Created for approval.  
**Key observations:**
- Added "README Hygiene" section to `.github/copilot-instructions.md` before Summary.
- Defines what triggers a README update: new CLI flags, changed defaults, new output, removed features, updated options.
- Specifies two acceptable workflows: update README in the same PR as the feature, OR in a dedicated docs/ branch immediately after feature PR merges.
- Lists specific README sections to maintain: Features, Options, Usage examples, Development → Running Tests.
- Updated Summary section with new bullet: "**README:** Update README.md for any user-facing feature change".
- Commit message includes co-author trailer per squad standards.

## Post-Sprint: PR #37 & #38 Merged to Main

**Date:** 2026-03-19  
**Status:** ✅ Both MERGED (squash merges)

### PR #37: README parallel fetch documentation
- Features, Options, Usage, Development sections updated
- `--parallel` flag fully documented

### PR #38: README hygiene governance
- New maintainability rule in copilot-instructions
- Defines triggers and workflows for README updates
- Establishes team standard for documentation accuracy

Full documentation and governance series complete. chlogr now has shipping parallel fetch feature + documented maintenance process.
