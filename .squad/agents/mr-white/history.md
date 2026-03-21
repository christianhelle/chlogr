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

## PR #41 Review — Parallel Crash Fix (`fix/parallel-crash`)

**Review verdict:** Approved and PR opened.  
**Key observations:**
- Fixed 6 bugs total: fixed-size array overflow (dop > 32), double-free on spawn failure, memory leak on empty page, missing has_more propagation, no validation for dop=0, outdated CLI tests.
- Core fix: replaced `[32]std.Thread` and `[32]PrsPaginationThreadCtx` with `std.ArrayList` for arbitrary degree of parallelism.
- Memory safety verified: all allocations have matching frees, errdefer scopes correctly placed, no use-after-free risks.
- Mr. Pink added 8 new tests covering boundary values (1, 32, 64), error conditions (0, missing, invalid), and combined flags.
- Build passes; all 44 tests pass.

## PR #41 — Parallel Crash Fix Merged (2026-03-20)

**Branch:** `fix/parallel-crash`  
**PR:** #41  
**Status:** ✅ Approved & Ready to Merge

### Final Review Metrics
- Build: ✅ PASS
- Tests: ✅ 44/44 PASS (20 original integration tests + 8 new edge-case tests by Mr. Pink + 16 CLI tests)
- Memory safety: ✅ VERIFIED
- Code quality: ✅ EXCELLENT
- Verdict: APPROVED FOR MERGE

## Learnings

### Dynamic Thread Management Pattern
When spawning a variable number of threads, always use `std.ArrayList(std.Thread)` instead of fixed-size stack arrays. Fixed arrays cause undefined behavior when the user-provided count exceeds the array size. The pattern:
```zig
var threads = std.ArrayList(std.Thread).initCapacity(allocator, 0) catch ...;
defer threads.deinit(allocator);
```

### Thread Spawn Error Cleanup
When `std.Thread.spawn` fails mid-batch, carefully join only the successfully spawned threads (indices 0..idx-1) and deinit only the contexts that were created. The context at index `idx` was appended but its thread never started, so it must be deinited separately — this prevents double-free if the loop accidentally processes it.

### CLI Validation for Parallelism
Always validate user-provided parallelism values >= 1. Zero causes infinite loops in batch processing patterns where `while (idx < dop)` never executes but the outer loop continues forever.

---

## Link-Aware Pagination Optimization Review (2026-03-20)

**Branch:** `optimize-parallel-pagination`  
**Status:** Code Review Complete, APPROVED

### Review Outcome

**Verdict: APPROVED.** The implementation matches the approved plan, is architecturally sound, and passes all 54 tests. Ready for PR and merge.

### Review Checklist

#### 1. Does the code implement Link-aware discovery-first pagination?

**YES.** The core flow is:

1. `fetchReleasePage(1)` / `fetchPullRequestPage(1)` fetches page 1 and captures the `Link` header via the new `HttpResponse.link_header` field.
2. `parsePaginationInfo()` extracts `has_next` and `last_page` from the header.
3. `buildPaginationPlan()` decides the strategy: `single_page`, `sequential_fallback`, or `bounded_parallel`.
4. If `bounded_parallel`, workers claim pages from a shared `WorkerPageState` via `claimNextPage()` (mutex-guarded counter), writing into pre-allocated page slots indexed by `page - 2`.
5. After all workers join, `mergeOrderedPages()` assembles the final slice in page order with a single allocation pass.

This replaces the old blind batch dispatch with a clean discover-then-dispatch model.

#### 2. Does it cover both PRs and releases?

**YES.** `getAllReleases()` and `getAllPullRequests()` share the identical `fetchPage → parsePaginationInfo → buildPaginationPlan → switch strategy` flow. Both have sequential and parallel implementations. The worker functions (`releasesPaginationWorkerFn`, `pullRequestsPaginationWorkerFn`) are symmetric. No endpoint is left on the old heuristic loop.

#### 3. Is concurrency bounded and safer than the old blind batch strategy?

**YES.** Improvements over the old approach:

- Workers bounded to `min(remaining_pages, degree_of_parallelism)` — no speculative fetches past the known last page.
- `WorkerPageState.claimNextPage()` is mutex-guarded and stops immediately on error.
- `setError()` captures only the first error; subsequent workers drain gracefully.
- Thread spawn failure joins all previously-started threads before returning.
- `errdefer` on `first_page_items` and each slot prevents leaks on any error path.
- `error.IncompletePagination` catches the case where a slot is null after all joins — defensive belt-and-suspenders.

#### 4. Is fallback behavior sane when `rel="last"` is absent?

**YES.** Three-tier fallback in `buildPaginationPlan()`:

1. **Header present, `last_page` known** → bounded parallel (or sequential if dop=1).
2. **Header present, no `last_page` but `has_next`** → sequential fallback (safe, no blind parallelism).
3. **No header at all** → heuristic: if items < 100, single page; otherwise sequential fallback.

The sequential loop also dynamically discovers `last_page` from subsequent responses and will stop early.

#### 5. Are ownership/cleanup paths sound?

**YES.** Verified:

- `HttpResponse.deinit()` frees both `body` and `link_header`.
- `errdefer` on `link_header` in `HttpClient.get()` prevents leak if body read fails.
- `appendMovedReleasePage` / `appendMovedPullRequestPage` use `errdefer freeSlice` before the append, then free the outer slice after items move into the ArrayList.
- Parallel paths: `errdefer` frees `first_page_items` and all non-null slots; success path frees individual slot slices after merge.
- `HttpClient.get()` correctly switches from high-level `client.fetch()` to lower-level `request/receiveHead/readerDecompressing` to access response headers. Decompression handling is explicit and correct.

#### 6. Are docs/help changes accurate?

**YES.**

- `cli.zig` help text: `"Fetch with up to N concurrent page requests"` — matches bounded-parallel semantics.
- `README.md`: Features bullet, usage example, and Options all updated to `--parallel <N>` with concurrency language — matches implementation.
- No new CLI flags; syntax unchanged.

### Residual Risks

1. **No live integration test** — Parallel worker paths aren't exercised by the test suite (require real HTTP). Should validate manually against a multi-page repo before shipping.
2. **`error.IncompletePagination`** — No user-facing message wiring in `main.zig`. Would surface as a raw error name. Low priority.
3. **Decompression responsibility** — The new explicit decompression path replaces the old `client.fetch()` internals. Correct but now our code's responsibility.

### Verification

- ✅ `zig build` passes
- ✅ `zig build test` passes — all 54 tests green
- ✅ 5 files changed: +928/−335 lines
- ✅ No memory leaks detected by test allocator

### Summary

Implementation is correct, safe, and complete. The discovery-first model eliminates speculative requests, the bounded worker pool is properly synchronized, and fallback paths are conservative. Approved for PR and merge.

### Key Learnings

**RFC 5988 Link Header Semantics:**
- GitHub's Link headers follow RFC 5988 format with multiple relations
- `rel="last"` is reliably present for list endpoints (`/releases`, `/pulls`)
- Parsing must be defensive (handle missing relations, malformed URLs)
- Fallback to sequential is safe when header absent

**Bounded Worker Pool Architecture:**
- Atomic page counter (via fetchAdd) is more efficient than work queues
- Pre-allocated results array indexed by page number eliminates O(n²) merge
- Mutex guard on page counter is simple and proven pattern
- Single merge pass at end (all workers done) simplifies error handling

**HTTP Header Capture:**
- Must use lower-level `request()` → `receiveHead()` API to access response headers
- High-level `client.fetch()` doesn't expose headers (by design, for simplicity)
- Decompression must be handled explicitly when switching to lower-level API

---

## Closed Issues Feature — Architecture Review (2026-03-21)

**Status:** ✅ Approved

### Review Focus

Evaluated end-to-end implementation of closed issues feature from Mr. Orange, with test coverage from Mr. Pink and documentation from Mr. Blonde.

### Key Review Findings

**Architecture:** ✅ Sound
- `getClosedIssues()` API correctly uses pagination loop (reuses pattern from releases/PRs)
- PR filtering (`pull_request != null` check) prevents duplication in `/issues` endpoint
- Parallel `ParallelFetcher` path correctly handles issues allocation/cleanup
- Tag-range filtering correctly applies same logic as PRs (no special cases)

**Memory Safety:** ✅ Verified
- All Issue fields properly duped in `copyIssue()` (strings, labels array, closed_at)
- `errdefer` chains on all paths guard against partial allocation failures
- Cleanup functions symmetric between releases, PRs, and issues
- Test allocator validates no leaks across 47 tests

**Flagged Observations:**

1. **HTTP Response Design Risk:** `HttpResponse.link_header: ?[]u8` exposes raw header string. Recommend wrapping with internal parser in http_client layer to prevent caller-side parsing bugs.

2. **Memory Allocation Pattern:** Result merging allocates per-page slices; consider pre-allocation by total_pages discovered upfront (optimization opportunity, not a correctness issue).

### Test Coverage Assessment

- 12 new test cases by Mr. Pink cover: filtering, label matching, tag ranges, edge cases
- Markdown output verified (section header, label badges, ordering)
- 100% coverage of `getClosedIssues()` and label filter logic
- All 47 tests passing with no leaks

### Documentation Review

- 4 README commits by Mr. Blonde align examples with actual behavior
- Clarified: `--unreleased-changes` is PR-only, use `--closed-issues` for issues
- Examples are executable and match implementation

### Approval

✅ **APPROVED** — Feature ready for merge. Address HTTP response design suggestion in follow-up refactor.

## Closed Issues Feature — Architecture Review (2025-07-18)

**Branch:** `include-closed-issues` (WIP reviewed)  
**Status:** 7 defects identified, decision document written to inbox

### Key Architectural Findings

1. **GitHub `/issues` endpoint returns PRs too** — Must filter by checking `pull_request` field presence. Without this, every merged PR appears twice in the changelog.
2. **`closed_at` pointer not duped in `copyIssue`** — Use-after-free when parsed JSON is freed. All string fields in models must be individually duped.
3. **Issues need assignment tracking** — Same `assigned[]` bool-array pattern as PRs to prevent multi-release duplication.
4. **Issues should have their own "Closed Issues" section** — Not routed through `categorizeEntry()` which maps to PR-specific categories.
5. **Pagination missing for issues** — `getClosedIssues` only fetches 100 items max.
6. **Parallel error cleanup must be symmetric** — Each error path in `ParallelFetcher.fetch()` must free all successfully-fetched data types.

### Key File Paths
- `src/models.zig:19` — `Issue` struct (needs `closed_at` and `pull_request` fields)
- `src/github_api.zig:67` — `copyIssue` (needs `closed_at` dupe + `pull_request` handling)
- `src/github_api.zig:112` — `freeIssue` (needs `closed_at` + `pull_request` cleanup)
- `src/github_api.zig:817` — `getClosedIssues` (needs PR filtering + pagination)
- `src/github_api.zig:878` — `ParallelFetchResults` (needs issues fields — partially done)
- `src/changelog_generator.zig:135` — `generate()` (needs issues param, assignment tracking, "Closed Issues" section)

### Pattern: Adding a New Data Type to the Pipeline
When extending chlogr with a new GitHub data source:
1. Add/update model struct in `models.zig`
2. Add copy/free functions in `github_api.zig` (dupe ALL string fields, errdefer chain)
3. Add paginated fetch method in `GitHubApiClient`
4. Extend `ParallelFetchResults` + add thread function + fix ALL error cleanup paths
5. Extend `FetchedData` in `main.zig` for both sequential and parallel paths
6. Extend `generate()` in `changelog_generator.zig` with tracking arrays
7. Update all test call sites and add new test data
