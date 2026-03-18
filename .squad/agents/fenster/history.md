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
