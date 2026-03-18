# Hockney — History

## Project Context (Day 1)

**Project:** chlogr — Zig CLI tool for GitHub release changelog generation  
**Language:** Zig v0.15.2  
**User:** Christian Helle  
**Date Initialized:** 2026-03-18  

**What we're building:** A command-line tool that ingests GitHub repository data (releases, merged PRs, closed issues) and generates structured changelogs. Users can filter by release, date range, and category.

**Team:** Keaton (Lead), Fenster (CLI Dev), Hockney (Tester), McManus (DevRel), Scribe (Logger), Ralph (Monitor)

**Testing domains to care about:**
- GitHub API responses (success, errors, edge cases)
- CLI argument parsing and validation
- Changelog output formatting and correctness
- Release filtering and date range logic
- Integration with gh CLI or REST API

## Learnings

(None yet — explore the project structure and existing tests.)

---

## Sprint 1 (P0–P1 Test Scaffolding — Assigned 2026-03-18)

**Assigned Issues:** #7 (P1 pagination); extended test suite for P0–P1 validation

**P0 Support (parallel with Fenster):**
1. Prepare failing-allocator test infrastructure for #3 regression detection
2. Build test scaffolding for #4 edge cases (abnormal gh exit, stderr fill, timeout scenarios)
3. Prepare mock data generators for >100 PR scenarios

**P1 Sprint (after Fenster #6 complete):**
1. Implement pagination loop with GitHub Link header or cursor-based pagination
2. Add integration tests with >100 PR mocks
3. Validate extended test suite passes with all fixes
4. Validate output correctness for large repos

**Blocked By:** Fenster (#6) — cannot reliably test pagination until allocation paths are clean

**Unblocks:** Final validation before release (P1 completion gate)

### Test Case Design

**For #3 (Section-Map):**
- Normal case: 10 releases, 50 PRs, single allocation
- Failing allocator case: inject allocation failure at specific point; verify cleanup doesn't crash
- Edge case: empty release list, single PR, many releases with one PR each

**For #4 (Token Resolution):**
- Normal: `gh auth token` succeeds, returns token
- Abnormal exit: gh exits with non-zero code; verify fallback to next method
- Stderr fill: gh writes to stderr but doesn't read; verify we drain and don't deadlock
- Timeout: gh hangs; verify timeout after N seconds (recommend 5s)

**For #7 (Pagination):**
- Single page: 50 PRs, all on first page; verify single page fetch
- Multi-page: 250 PRs across 3 pages (100 + 100 + 50); verify all pages fetched and merged
- Max-pages: 500+ PRs; verify we stop after reasonable limit (recommend 10 pages = 1000 PRs)
- Edge case: empty repo (0 PRs), single PR, exactly 100 PRs on boundary
