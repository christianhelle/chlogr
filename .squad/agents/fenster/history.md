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
