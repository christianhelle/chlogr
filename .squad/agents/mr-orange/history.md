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
