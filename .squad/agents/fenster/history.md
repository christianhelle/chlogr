# Fenster — History

## Project Context (Day 1)

**Project:** chlogr — Zig CLI tool for GitHub release changelog generation  
**Language:** Zig v0.15.2  
**User:** Christian Helle  
**Date Initialized:** 2026-03-18  

**What we're building:** A command-line tool that ingests GitHub repository data (releases, merged PRs, closed issues) and generates structured changelogs. Users can filter by release, date range, and category.

**Team:** Keaton (Lead), Fenster (CLI Dev), Hockney (Tester), McManus (DevRel), Scribe (Logger), Ralph (Monitor)

**Key Files to Know:**
- `src/` — Zig source code (check current structure)
- `build.zig` — Build configuration
- `.github/` — GitHub Actions and workflows (if any)
- `docs/` — Documentation directory

## Learnings

(None yet — check the repo structure first.)

---

## Sprint 1 (P0 Safety — Assigned 2026-03-18)

**Assigned Issues:** #3, #4 (P0); #6, #9 (P1, queued)

**P0 Sprint Sequence:**
1. Fix #4: Token resolution resilience (stderr drain, Term variant checking) — 3h
2. Fix #3: Section-map ArrayList initialization (pre-init, errdefer) — 4h
3. Add failing-allocator regression tests — 2h
4. Validate P0 completion with Hockney extended test suite

**P1 Queue (after P0 complete):**
1. Fix #6: Add errdefer to deep-copy loops (copyRelease, copyPullRequest, copyIssue) — 5h
2. Fix #9: CSV token parsing for --exclude-labels — 2h

**Unblocks:** Hockney (#7 pagination testing), McManus (#5 release assignment testing)

### Key Code Patterns to Address

**#3 Issue (Section-Map ArrayList):**
```zig
// Current: unsafe, may panic mid-append
var sectionMap = try std.StringHashMap(std.ArrayList(PullRequest)).init(allocator);
defer sectionMap.deinit(allocator);
for (prs) |pr| {
    var section_list = sectionMap.get(pr.release) orelse blk: {
        break :blk try std.ArrayList(PullRequest).init(allocator);
    };
    try section_list.append(pr);  // May fail; defer still runs
}

// Solution: Pre-initialize or use errdefer at append point
```

**#4 Issue (Token Resolution):**
- `gh auth token` call doesn't drain stderr; can deadlock if stderr pipe fills
- Direct union field access on `child.term` without variant check; undefined behavior
- Need: stderr drain loop, Term variant checking, fallback error handling

**#6 Issue (Deep-Copy Cleanup):**
```zig
// Current: missing errdefer
var releases = try std.ArrayList(Release).initCapacity(allocator, cap);
for (json_releases) |json_release| {
    var release = try copyRelease(allocator, json_release);
    try releases.append(release);  // May fail; partial fields left allocated
}

// Solution: errdefer at copyRelease call site
```

## Session 2026-03-18: P0 Memory Safety Fixes

### Issue #3: Fixed unsafe section-map initialization ✅
**Problem:** 
- `getOrPut` was followed by `catch continue`, hiding allocation failures
- New ArrayList entries initialized with `initCapacity` before insertion, but if `append` failed later, the defer cleanup would call `deinit` on uninitialized memory
- ArrayList API confusion: Zig 0.15.2 uses unmanaged ArrayList by default (`std.ArrayList` -> `Aligned(T, null)`), which requires allocator parameters for all methods

**Solution:**
- Changed `catch continue` to `try`, propagating allocation errors to caller
- Initialize new map entries to `.empty` (zero-cost empty ArrayList) before any fallible operations
- Corrected all ArrayList method calls to include allocator parameter (deinit, append, toOwnedSlice)
- Added regression test with failing allocator to verify error propagation

**Key Learning:** Zig 0.15.2 ArrayList API:
- `std.ArrayList(T)` returns unmanaged version (`Aligned(T, null)`)
- Methods need explicit allocator: `.append(gpa, item)`, `.deinit(gpa)`, `.toOwnedSlice(gpa)`
- Initialization: use `.empty` constant or `initCapacity(gpa, n)`
- Managed version (`AlignedManaged`) has allocator as field, unmanaged doesn't

### Issue #4: Hardened gh token resolution ✅
**Problem:**
- Direct union field access `term.Exited != 0` without checking tag (undefined behavior)
- stderr piped but never read -> potential deadlock if gh writes error messages

**Solution:**
- Use explicit `switch` statement on termination status to handle all cases (.Exited, .Signal, .Stopped, .Unknown)
- Changed stderr_behavior to `.Ignore` to prevent deadlock (stderr not needed for token)
- Made `getTokenFromGhCli` pub for testing purposes
- Updated test file to match new API (fchmodat for chmod, removed setenv test)

**Key Learning:**
- Always use switch on tagged unions, never direct field access
- `.Pipe` stderr requires reading or risks deadlock; `.Ignore` is safer when output not needed
- Zig doesn't have setenv in std lib; env vars are read-only from Zig process

### Issue #7: Pagination Investigation ��
**Current State:**
- `getReleases`: No pagination, returns only first page (default 30 items)
- `getMergedPullRequests`: Hardcoded per_page=100, no pagination, sorted by `updated` not `merged_at`
- HttpResponse doesn't capture response headers (needed for Link header parsing)

**Findings:**
- GitHub API returns pagination via `Link` header with `rel="next"` for next page
- Need to:
  1. Modify HttpResponse to include headers (at least Link header)
  2. Implement pagination loop in github_api methods
  3. Consider changing PR sort from `updated` to chronological to avoid missing merged PRs
  4. Accumulate results from all pages into single owned slice

**Decision Needed (for Keaton):**
1. Should we fetch all pages or add max-page limit?
2. Should PR query change from `sort=updated` to default (chronological) or `sort=created`?
3. Accept rate limit risk or add throttling?
4. Should getReleases also paginate (repos with >30 releases)?

### Learnings

**Allocator Patterns:**
- Always initialize struct fields before entering error-prone code paths
- Use `.empty` for zero-cost empty ArrayList initialization
- Prefer `try` over `catch continue` unless you have explicit fallback logic
- Add failing-allocator regression tests for allocation-heavy code

**Memory Safety:**
- Tagged union fields must be accessed via switch, not direct field access
- Process pipes can deadlock - only .Pipe what you'll read
- defer cleanup assumes all fields are initialized - be careful with partial initialization

**API Patterns:**
- GitHub API pagination requires Link header parsing
- Unmanaged ArrayList API takes allocator as first parameter in all methods
- Process termination has 4 states: Exited(code), Signal, Stopped, Unknown

---

## Session 2026-03-18: P1 Correctness Fixes

### All 6 P1 Issues Implemented ✅

**Branch Strategy:** Independent feature branches for parallel development
- fix/7-pagination-support
- fix/5-release-assignment-semantics  
- fix/9-label-exclusion-exact-match
- fix/6-api-deep-copy-cleanup
- fix/8-tag-filter-rejection
- fix/10-release-link-rendering

### Issue #7: Pagination Implementation ✅
**Problem:**
- Only first 100 items fetched (default page size)
- No Link header parsing
- Missing merged_at filtering in PR queries

**Solution:**
- Added `link_header: ?[]u8` field to HttpResponse
- Implemented `extractNextPageUrl()` to parse RFC 5988 Link headers
- Modified `getReleases()` to loop through all pages
- Modified `getMergedPullRequests()` to loop through all pages and filter by merged_at != null
- Used 100 items per page for efficiency
- Proper errdefer cleanup on partial page fetches

**Key Learning:** GitHub's Link header format uses angle brackets and rel attributes:
```
<https://api.github.com/...?page=2>; rel="next", <https://...>; rel="last"
```
Parser tokenizes on commas, checks for `rel="next"`, extracts URL between `<` and `>`.

### Issue #5: Timestamp Precision ✅
**Problem:**
- `parseDateToSlice()` truncated ISO-8601 to YYYY-MM-DD
- Same-day PRs at different times treated as identical
- PRs could appear in multiple releases or disappear

**Solution:**
- Removed `parseDateToSlice()` entirely
- Changed `compareDates()` to use full ISO-8601 string comparison (lexicographic order works for ISO-8601)
- Added explicit release sorting (newest first) before PR assignment
- Changed `isBefore()` to `isBeforeOrEqual()` for boundary semantics
- PRs merged at exact release time now belong to that release

**Key Learning:** ISO-8601 timestamps are lexicographically sortable:
```zig
// This works because ISO-8601 format is: YYYY-MM-DDTHH:MM:SS.sssZ
std.mem.order(u8, "2024-01-10T14:30:45.123456Z", "2024-01-10T14:30:45.123457Z") == .lt
```

### Issue #9: CSV Token Parsing ✅
**Problem:**
- Used `std.mem.indexOf()` for substring matching
- "bug" would incorrectly exclude "bugfix"
- No whitespace trimming in CSV

**Solution:**
- Changed to `std.mem.tokenizeScalar(u8, exclude, ',')` for CSV parsing
- Trim each token with `std.mem.trim(u8, token, " \t\r\n")`
- Skip empty tokens
- Use `std.mem.eql()` for exact string matching

**Key Learning:** Zig tokenization pattern:
```zig
var it = std.mem.tokenizeScalar(u8, csv_string, ',');
while (it.next()) |token| {
    const trimmed = std.mem.trim(u8, token, " \t\r\n");
    if (trimmed.len == 0) continue;
    // Process trimmed token
}
```

### Issue #6: Deep-Copy Error Handling ✅
**Problem:**
- No cleanup on allocation failures in `getReleases()`, `getMergedPullRequests()`, `getClosedIssues()`
- Partial structures leaked memory if mid-copy allocation failed
- Example: if label[5].color allocation fails, labels[0..4] already allocated but not freed

**Solution:**
- Added top-level errdefer for ArrayList cleanup
- Added per-field errdefer for each allocated string
- Intermediate variables + errdefer before struct construction:
```zig
const title = try allocator.dupe(u8, pr.title);
errdefer allocator.free(title);

const body = if (pr.body) |b| try allocator.dupe(u8, b) else null;
errdefer if (body) |b| allocator.free(b);

// ... collect all fields, each with errdefer ...

prs.appendAssumeCapacity(.{ .title = title, .body = body, ... });
```

**Key Learning:** errdefer pattern for complex allocations:
1. Top-level errdefer for the collection (ArrayList)
2. Inner errdefer for nested collections (labels ArrayList)
3. Per-field errdefer for each allocated string
4. Only construct struct after all allocations succeed

### Issue #8: Feature Gate with Clear UX ✅
**Problem:**
- `--since-tag` and `--until-tag` parsed but never used
- Silent failure (flags accepted but ignored)
- README documented as working

**Solution:**
- Added validation in CLI parser
- Return `error.NotYetImplemented` with multi-line helpful message
- Error message includes:
  - Clear statement: "not yet implemented"
  - Current behavior: "all releases and PRs included"
  - Tracking link: "https://github.com/.../issues/8"
- Updated help text to move to "Planned Features" section

**Key Learning:** Unimplemented feature pattern:
```zig
if (std.mem.eql(u8, arg, "--since-tag")) {
    std.debug.print("Error: --since-tag is not yet implemented\n", .{});
    std.debug.print("Track progress at: https://github.com/.../issues/8\n", .{});
    return error.NotYetImplemented;
}
```

### Issue #10: Parameterized Formatting ✅
**Problem:**
- Release links hardcoded to "https://github.com/owner/repo/releases/tag/{tag}"
- All generated changelogs had broken links

**Solution:**
- Added `repo_slug: []const u8` field to MarkdownFormatter struct
- Updated `init()` to accept repo_slug parameter
- Changed format string to use `self.repo_slug`
- Passed `parsed_args.repo.?` from main.zig
- Updated all test files to pass "owner/repo" test slug

**Key Learning:** Formatter parameterization pattern - pass runtime values at init, not at format time.

### Learnings

**Pagination Implementation:**
- Link header parsing: tokenize on comma, search for `rel="next"`, extract URL between angle brackets
- Loop pattern: fetch page → parse response → extract next URL → repeat until no next link
- Page size: use 100 (GitHub max) for efficiency
- Filter at fetch time (merged_at != null) to reduce memory usage

**Timestamp Comparison:**
- ISO-8601 is lexicographically sortable (YYYY-MM-DDTHH:MM:SS.sssZ format)
- Don't truncate - preserve full precision
- Explicit sorting before comparison avoids API order dependency
- Boundary semantics: use `<=` for "belongs to this release"

**CSV Parsing:**
- `tokenizeScalar()` for delimiter splitting
- `trim()` for whitespace removal
- Skip empty tokens (handles double commas gracefully)
- `eql()` for exact matching (not `indexOf()`)

**Error Handling in Deep Copies:**
- Top-level errdefer for collection cleanup
- Per-item errdefer for nested allocations
- Intermediate variables with errdefer before struct construction
- Order: allocate all → errdefer all → construct struct

**Feature Gating:**
- Explicit error messages beat silent failures
- Include tracking link for "not yet implemented"
- Update help text to reflect reality
- Return error early (fail fast)

**Parameterization:**
- Pass configuration at initialization, not per call
- Store as struct field for reuse
- Update all call sites (main + tests)

**Zig Patterns Used:**
- `tokenizeScalar()` for CSV parsing
- `trim()` for whitespace handling
- `std.mem.order()` for string comparison
- `errdefer` for cleanup on error paths
- Intermediate variables for complex allocations
