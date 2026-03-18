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

### Day 1 - Test Suite Development (2026-03-18)

**Comprehensive P0/P1 Test Coverage Completed:**

1. **Issue #3 - Allocator Failures:**
   - Created failing allocator wrapper to simulate OOM conditions
   - Tests for section creation failures, PR append failures, partial cleanup
   - **Critical finding:** Memory leaks on error paths - ArrayList allocated but not freed
   - Need `errdefer` cleanup in changelog_generator.zig lines 110-143, 170-204

2. **Issue #4 - Token Resolution:**
   - Tests for abnormal gh process exit (non-zero, signals, crashes)
   - Empty token handling, stderr without deadlock
   - **Finding:** Current `.Ignore` for stderr may cause buffer fill in edge cases
   - Recommend: Drain stderr asynchronously or use bounded buffer

3. **Issue #5 - Timestamp Comparison:**
   - Full ISO-8601 tests with microsecond precision
   - Same-day, different time scenarios
   - Boundary conditions (merged_at == published_at)
   - **Critical bug confirmed:** parseDateToSlice() truncates at 'T' (line 78-85)
   - All same-day PRs go to same bucket regardless of time

4. **Issue #7 - Pagination:**
   - Multi-page scenarios: 250 PRs, 15 releases
   - Release ordering, merged_at vs updated_at
   - Large repo (1000+ PRs), rate limiting (403/429)
   - **Finding:** No pagination loop exists - hardcoded first page only
   - Need Link header parsing in github_api.zig

5. **Issue #9 - Label Exclusion:**
   - Exact match tests: "bug" vs "bugfix"
   - CSV parsing: whitespace, empty tokens, case sensitivity
   - **Bug confirmed:** Substring search (line 48) matches "bug" in "debugging"
   - Need CSV tokenization with exact label comparison

**Test Patterns Established:**
- Failing allocator for OOM simulation
- Mock shell scripts for process testing
- Test data generators for pagination
- Current vs expected behavior documentation

**Build Integration:**
- Added `test-all` target for full P0/P1 suite
- Individual targets per issue for focused testing
- All tests compile and run successfully on Zig 0.15.2

**Coverage Gaps:**
- No tests for Issue #6 (allocation cleanup in github_api.zig deep-copy)
- Missing: release/issue pagination tests
- Missing: concurrent request scenarios
- Missing: network error simulation (timeout, 404, 500)


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
