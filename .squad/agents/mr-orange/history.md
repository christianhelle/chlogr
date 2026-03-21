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
### Issue #8 — --since-tag / --until-tag filtering (PR #18)

**Approach used:**  
Tag filtering is implemented as a pre-processing step inside `ChangelogGenerator.generate()` via a new private method `filterReleasesByTagRange`. The method scans the releases slice (assumed newest-first, matching GitHub API ordering) to find the index positions of the requested tags, then returns a sub-slice covering the inclusive range. With only `since_tag`, it returns from that index to the end of the slice (older releases); with only `until_tag`, it returns from the start to that index. With both, it uses `min`/`max` of the two indices to produce the correct window regardless of which index is lower.

**Key decisions:**
- Fields `since_tag` and `until_tag` were added with `null` defaults to `ChangelogGenerator` so no existing `init(allocator, exclude_labels)` call sites needed changing.
- Callers set them directly after `init`: `gen.since_tag = parsed_args.since_tag;`
- Unknown tags return typed errors (`SinceTagNotFound` / `UntilTagNotFound`) rather than silent empty results; `main.zig` prints a clear diagnostic before propagating the error.
- The filter returns a slice of the original releases array — no allocation required.

---

## Wave 2 session — P1 issues #9, #10, #11 (PRs #22, #23, #24)

### Issue #9 — Exact CSV token matching for --exclude-labels (PR #22)

**Approach used:**  
Replaced the previous `std.mem.indexOf`-based substring check with exact token matching via `std.mem.splitScalar(',')` + `std.mem.trim` + `std.mem.eql`. Each label in the PR is tested against each trimmed CSV token individually.

**Key decisions:**
- `splitScalar(',')` is the correct Zig 0.15.2 API for single-delimiter splitting (not `split` which requires a sequence).
- `trim` is applied to both whitespace characters on each token to handle `"bug, enhancement"` style user input.
- `eql` for exact match prevents false positives like `"bug"` matching `"debug"`.
- 19 tests pass, including new cases that verify substring non-matching.

### Issue #10 — Dynamic repo slug in release header URLs (PR #23)

**Approach used:**  
`MarkdownFormatter` was changed from a zero-field struct to a struct holding a `repo: []const u8` field. `init` now accepts a `repo` parameter. Release header links are rendered as `https://github.com/{repo}/releases/tag/{tag}` using the runtime value.

**Key decisions:**
- `MarkdownFormatter.init(allocator, repo)` — `allocator` retained for future use, `repo` stored by slice (no copy needed; owned by caller for the formatter's lifetime).
- All call sites in `main.zig` and tests updated to pass `repo`.
- 20 tests pass.

### Issue #11 — Reduce allocation churn (PR #24)

**Approach used:**  
`markdown_formatter.zig` switched from multiple `std.fmt.allocPrint` calls (one per fragment) to a single `ArrayList(u8)` writer pattern: `var buf = ArrayList(u8).init(allocator)` → `buf.writer()` → `std.fmt.format(writer, ...)` for each fragment → `buf.toOwnedSlice()` once at the end. `changelog_generator.zig` calls `ensureTotalCapacity(3)` on the per-release PR `AutoHashMap`s immediately after creation, amortising the first few inserts.

**Key decisions:**
- `ArrayList(u8).writer()` returns a `std.io.Writer` compatible with `std.fmt.format` — this is the idiomatic Zig pattern for building strings without repeated allocations.
- `ensureTotalCapacity` on a hash map takes an `Allocator` in Zig 0.15.2 (`try map.ensureTotalCapacity(allocator, 3)`).
- 20 tests continue to pass — the refactor is behaviour-preserving.

---

## Parallel Fetch Research (2025-01-22)

### Context
Researched and documented requirements for implementing a `--parallel` flag to fetch GitHub releases and PRs concurrently using Zig 0.15.2 std.Thread API.

### Learnings

**Zig 0.15.2 Threading Model:**
- `std.Thread.spawn(.{}, func, .{args...})` creates threads with tuple-based argument passing
- `thread.join()` returns `void` — results must be communicated via shared state (not return values)
- Thread functions receive parameters by value; shared state requires explicit pointer passing
- No special build flags needed — `std.Thread` is part of core stdlib

**Thread Safety:**
- `std.http.Client` is NOT thread-safe when shared — each thread MUST create its own instance
- `std.Thread.Mutex` provides mutual exclusion for shared result structures
- `std.debug.print()` IS thread-safe (uses internal stderr mutex) — safe for concurrent progress printing
- GPA allocator is internally thread-safe

**Error Propagation Pattern:**
- Since `join()` returns void, errors must be stored in a shared result struct protected by mutex
- Main thread checks error fields after join, propagates first encountered error
- Partial success (one thread succeeds, one fails) requires explicit cleanup by main thread

**Memory Ownership:**
- Thread allocates data via its thread-local `GitHubApiClient`
- On success, ownership transfers to shared `FetchResults` struct
- Main thread takes ownership after join, responsible for calling `freeReleases()` / `freePullRequests()`
- `errdefer` in API client methods prevents leaks on per-thread failures

**Result Struct Pattern:**
```zig
const FetchResults = struct {
    releases: ?[]models.Release = null,
    prs: ?[]models.PullRequest = null,
    releases_err: ?anyerror = null,
    prs_err: ?anyerror = null,
    mutex: std.Thread.Mutex = .{},
};
```

**Design Decision:**
Parallel mode must produce byte-for-byte identical output to sequential mode. Since `ChangelogGenerator.generate()` operates deterministically on release/PR slices (timestamp-based assignment), fetch order does not affect final changelog content.

**Documentation:**
Complete technical design written to `.squad/agents/mr-orange/parallel-fetch-design.md` covering:
- Thread safety analysis
- FetchResults struct design
- Thread function signatures
- Error propagation strategy
- Memory ownership model
- Progress printing thread safety
- Implementation sketch with code samples
- Testing strategy
- Performance expectations

---

## Issue #27 — Add `--parallel` flag to CLI argument parsing (PR #32)

**Branch:** `feature/27-parallel-cli-flag`

**Approach used:**
Added `parallel: bool = false` field to `CliArgs` struct in `src/cli.zig`. The flag is parsed as a presence-only boolean (no value required). Added to help text under Options section. Also added 10 comprehensive CLI parsing tests covering all argument types (previously no CLI tests existed).

**Key decisions:**
- `--parallel` is a boolean flag (presence = true, absence = false)
- Tests added inline in `cli.zig` using `test "..."` blocks (matching pattern in `github_api.zig`)
- Tests cover: flag present/absent, all existing arguments, help behavior, unknown arguments, and combined flags
- The flag is parsed but NOT yet used in `main.zig` — that's issue #30
- Build gate passed: `zig build` ✓
- Test gate passed: `zig build test` ✓ (all 30 tests pass, including 10 new CLI tests)

**Commit:** `b078f56 feat: add --parallel flag to CLI argument parsing`

**PR:** #32 (https://github.com/christianhelle/chlogr/pull/32)

---

## Parallel PR Fetcher Crash Fixes (2025-01-22)

**Branch:** `fix/parallel-crash`  
**Commits:** `007bddf`, `d9dc110`

### Context
The parallel PR pagination feature (from `parallel-pr-pagination` branch) had six critical bugs that caused crashes and memory leaks when users specified `--parallel` with various values.

### Bugs Fixed

#### Bug 1 — Fixed-size stack buffer (PRIMARY CRASH for dop > 32)
In `prsThreadFn` (line 423-424):
```zig
var threads: [32]std.Thread = undefined;
var thread_ctxs: [32]PrsPaginationThreadCtx = undefined;
```
These are stack-allocated fixed-size arrays. If `degree_of_parallelism > 32`, writing to index 32+ is undefined behavior / panic.

**Fix:** Replace with `ArrayList(std.Thread)` and `ArrayList(PrsPaginationThreadCtx)` using `initCapacity(ctx.allocator, 0)`. Use `.append(ctx.allocator, item)` and access with `.items[i]`.

#### Bug 2 — Double-free when std.Thread.spawn fails mid-batch
`thread_ctx` (stack copy) and `thread_ctxs[idx]` (array copy) share the same `result_ptr`. Calling `thread_ctx.deinit()` then `thread_ctxs[j].deinit()` (j <= idx) double-frees `result_ptr` when j==idx.

**Fix:** Only call deinit on array items, not on the standalone `thread_ctx` variable.

#### Bug 3 — Memory leak when batch has partial results
When merge loop encounters `prs.len == 0`, it returns immediately without freeing `thread_ctxs[i+1..active_count-1]` result pointers.

**Fix:** Before returning, iterate remaining indices and call `.deinit()` on each.

#### Bug 4 — `has_more` not propagated to outer loop
`getMergedPullRequestsByPage` returns `has_more: bool`, but `prsPaginationThreadFn` only stored `prs` in the result. The outer loop detects page exhaustion via `prs.len == 0`, causing unnecessary extra batch when last page has exactly 100 PRs.

**Fix:** Store `ctx.result.has_more = res.has_more` in thread function. Check `!has_more` in merge loop and stop immediately after merging last page.

#### Bug 5 — Broken CLI tests
The `--parallel` flag was changed from boolean to value-based (`--parallel <N>`), but tests still used old boolean form:
- `test "parse --parallel flag present"` passed `{ "chlogr", "--parallel" }` → now returns `error.MissingParallelValue`
- `test "parse --parallel combined"` passed `{ "--parallel", "--repo" }` → parser reads "--repo" as DOP value, `parseInt` fails

**Fix:** Update tests to pass numeric values: `"--parallel", "4"` and `"--parallel", "8"`. Assert `degree_of_parallelism` matches expected value.

#### Bug 6 — No validation of degree_of_parallelism == 0
If someone passes `--parallel 0`, `dop = 0`, spawn loop never runs, merge loop does nothing, `while (true)` loops forever.

**Fix:** Add validation in `cli.zig`: `if (result.degree_of_parallelism == 0) return error.InvalidParallelValue;`. Added test case for zero validation.

### Implementation
- Commit 1 (`007bddf`): Fixed bugs 1-4 in `github_api.zig` — dynamic allocation, double-free, memory leak, has_more propagation
- Commit 2 (`d9dc110`): Fixed bugs 5-6 in `cli.zig` — test updates, zero validation, help text update

### Testing
- Build gate: `zig build` ✓
- Test gate: `zig build test` ✓ (all 20 integration tests passed)

### Learnings

**Zig 0.15.2 ArrayList API:**
- `ArrayList(T).init(allocator)` does NOT exist — use `initCapacity(allocator, 0)` for empty list
- `list.append(allocator, item)` requires allocator parameter
- `list.deinit(allocator)` requires allocator parameter
- Access items with `.items[i]` instead of `[i]`

**Thread function error handling:**
- Functions called via `std.Thread.spawn` must return `void` (not `!void`)
- All error-returning operations must use `catch |err| { ctx.results.some_err = err; return; }`
- Cannot use `try` in thread functions

**Memory ownership in thread contexts:**
- When copying structs that contain pointers (like `PrsPaginationThreadCtx`), both the stack copy and array copy point to the SAME heap object (`result_ptr`)
- Only ONE copy should call `allocator.destroy()`
- Use array copy for cleanup, not the temporary stack copy

**Pagination best practices:**
- Always propagate `has_more` from paginated API results
- Check `!has_more` AFTER successful merge to avoid unnecessary batches
- Don't rely solely on empty page detection (`len == 0`) — inefficient for full last pages

**User input validation:**
- Always validate numeric flags that control iteration/loops
- Zero values often cause infinite loops or meaningless operations
- Provide clear error messages ("must be at least 1", not just "invalid")

---

## Parallel Crash Fix — Merged (2026-03-20)

**PR #41:** https://github.com/christianhelle/chlogr/pull/41

### Team Review & Approval

- **Mr. Pink:** Added 8 comprehensive edge-case tests (boundary values 1/32/64, error conditions 0/missing/invalid, combined flags)
- **Mr. White:** Approved code review with verdict APPROVED — memory safety verified, all 44 tests passing, ready to merge

### Final Status
✅ Build passing  
✅ 44 tests passing  
✅ Memory safety verified  
✅ PR ready for merge

---

## Link-Aware Pagination Optimization (2026-03-20)

**Branch:** `optimize-parallel-pagination`  
**Status:** Implementation Complete, Ready for PR

### Session Summary

Implemented discovery-first pagination optimization replacing blind batch dispatch with bounded concurrent workers. Core change: parse GitHub's `Link: rel="last"` header on first response to discover total page count upfront, eliminating speculative thread spawning.

### Implementation Details

#### HTTP Headers Capture (Phase 1)
- Modified `HttpResponse` struct to include `link_header: ?[]u8` field
- Switched `HttpClient.get()` from `client.fetch()` to lower-level `request()` → `receiveHead()` → `readerDecompressing()` API
- Proper decompression and cleanup on all error paths

#### Link Header Parser (Phase 2)
- Implemented `parsePaginationInfo()` helper that extracts:
  - `has_next: bool` — is rel="next" present?
  - `last_page: ?u32` — extract page number from rel="last"
- Graceful fallback to null if header absent or malformed

#### Pagination Plan Builder (Phase 3)
- Implemented `buildPaginationPlan()` that selects strategy based on available info:
  1. `single_page` — if only one page exists (common for small repos)
  2. `sequential_fallback` — if no Link header (conservative, no speculation)
  3. `bounded_parallel` — if total known, spawn exactly min(pages, dop) workers
- Applies uniformly to both releases and pull requests

#### Bounded Worker Pool (Phase 4)
- Implemented `WorkerPageState` struct with atomic `page_counter` (mutex-guarded)
- Workers atomically claim pages via `claimNextPage()` — no contention
- Pre-allocates results array indexed by (page - 2) to avoid O(n²) merge
- Symmetric worker functions: `releasesPaginationWorkerFn`, `pullRequestsPaginationWorkerFn`

#### Ordered Merging (Phase 5)
- Implemented `mergeOrderedPages()` to assemble pages by index order
- Single allocation pass at end: O(n) total copies (vs old O(n²))
- Proper cleanup of individual page slices after merge
- Defensive `error.IncompletePagination` guard

### Code Statistics
- **Files Modified:** 5 (http_client.zig, github_api.zig, cli.zig, test_data.zig, README.md)
- **Lines Changed:** +928/−335
- **Tests:** 54 total (20 integration + 34 unit)

### Testing
- 17 new unit tests in github_api.zig (Link parsing, plan selection, merge ordering)
- 17 updated tests in cli.zig (help text reflects bounded semantics)
- 4 new Link header fixtures in test_data.zig
- All 54 tests passing

### Memory Safety
- ✅ All allocations have matching frees
- ✅ Proper errdefer scopes on all paths
- ✅ No data races (atomic counter with mutex guard)
- ✅ No undefined behavior

### Key Learnings

**RFC 5988 Link Header Parsing:**
- Format: `<url>; rel="relation", <url>; rel="relation", ...`
- Must handle multiple relations in one header
- `rel="last"` only present if total is computable
- Should gracefully fall back to sequential if absent

**Atomic Page Claiming Pattern:**
- Using mutex-guarded `fetchAdd` eliminates contention in worker pool
- Pre-allocated results array indexed by page number avoids list operations
- Single merge pass at end transforms O(n²) to O(n)

**Discovery-First Pagination:**
- Knowing total pages upfront enables optimal worker spawning
- No speculative fetches past known last page
- Applies to any paginated API endpoint (releases, PRs, issues, etc.)
- Fallback to sequential is safe and conservative

## Learnings

- `src/github_api.zig` now needs closed issues to follow the same discovery-first pagination path as releases and pull requests, with `pull_request != null` filtered at the API-copy boundary so `/issues` never duplicates merged PRs in the changelog.
- `src/changelog_generator.zig` should group true issues into a dedicated `Closed Issues` section by `Issue.closed_at`, while keeping `Unreleased Changes` PR-only to preserve existing user-facing behavior.
- The end-to-end wiring for this feature spans `src/main.zig`, `src/github_api.zig`, `src/changelog_generator.zig`, `src/test_data.zig`, `src/test.zig`, and `README.md`; output-shape changes are not complete until all six stay in sync.

---

## Closed Issues Feature — Implementation (2026-03-21)

**Branch:** `feature/closed-issues`  
**Status:** ✅ Complete and shipping

### Implementation Summary

Delivered complete closed issues support end-to-end. This session implemented API, models, generator, main orchestration, markdown formatting, CLI args, tests, and README documentation.

### Modules Changed

1. **API Layer** (`src/github_api.zig`)
   - Added `getClosedIssues(allocator, org, repo)` with pagination loop
   - Filters out PRs via `pull_request == null` check
   - Returns `ArrayList(models.Issue)` ownership to caller

2. **Data Model** (`src/models.zig`)
   - Extended `Changelog` struct with `closed_issues: []models.Issue`
   - Issue struct carries: `number`, `title`, `labels`, `closed_at` (properly duped)

3. **Changelog Generator** (`src/changelog_generator.zig`)
   - Integrated closed issues param to `generate()`
   - Tag-range filtering applies to closed issues (same pattern as PRs)
   - Tracks issue assignment via `assigned[]` bool array

4. **Markdown Formatting** (`src/markdown_formatter.zig`)
   - Added `formatClosedIssues()` function
   - Output: `## Closed Issues` section with label badges

5. **Main Orchestration** (`src/main.zig`)
   - Fetch closed issues if `--closed-issues` flag set
   - Proper cleanup on error via defer

6. **CLI** (`src/cli.zig`)
   - Added `--closed-issues` boolean flag (default: false)
   - Added `--closed-issues-labels` CSV string filter

### Validation

- ✅ `zig build` passes
- ✅ `zig build test` — 47 tests passing (20 integration + 27 unit)
- ✅ Memory safety verified (no leaks)
- ✅ All error paths tested

### Key Design Decisions

1. **PR Filtering at API Boundary:** GitHub `/issues` endpoint returns merged PRs. Filter by `pull_request != null` at copy time to prevent duplication.

2. **Separate Section:** Keep closed issues in `## Closed Issues` section, distinct from PR categories. Don't route through `categorizeEntry()`.

3. **Parallel Cleanup:** `ParallelFetchResults` has `issues` field with symmetric cleanup rules.

4. **End-to-End Wiring:** Not complete until all call sites updated:
   - `src/main.zig` (orchestration)
   - `src/github_api.zig` (API + parallel)
   - `src/changelog_generator.zig` (generator)
   - `src/markdown_formatter.zig` (output)
   - `src/models.zig` (data structure)
   - `src/test_data.zig` (fixtures)
   - `src/test.zig` (tests)
   - `README.md` (documentation)
