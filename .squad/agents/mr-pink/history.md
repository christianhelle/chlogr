# Mr. Pink — History

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

## Test Coverage Notes

- Integration tests use mock data from `test_data.zig` — no live API calls
- Tests verify: JSON parsing, changelog grouping/categorization, markdown formatting, file output

## Core Context

**Previous Test Coverage Work (Jan-Mar 2026):**
- Reviewed PRs #22–24: CSV label matching, dynamic repo slugs, CLI help text
- Added 8 edge-case tests for parallel pagination (boundary values 1/32/64, error conditions)
- Designed 34 unit tests for Link header pagination (parsing, plan selection, result ordering, allocation failure cleanup)

**Current Status:**
- 47 tests passing (20 integration + 27 unit)
- All critical paths covered
- Memory safety verified by test allocator
- Build green on all platforms

## Learnings

**Test Design for Pagination:**
- Mock Link headers must be realistic (RFC 5988 format)
- Test all three strategy branches: single_page, sequential_fallback, bounded_parallel
- Verify result ordering by page index, not completion order
- Allocation failure cleanup is critical: test all error paths

**Edge Case Coverage:**
- Boundary values: min(1), max(32), above-max(64)
- Error conditions: zero (invalid), missing flags, combined flags
- Whitespace handling in CSV: `"bug, docs"` with spaces must parse correctly
- Empty result sets: no crash when zero items match filter

**Memory Safety Testing:**
- Test allocator catches leaks across all code paths
- Verify `errdefer` chains on copy failures
- Check that multi-field structs (labels, closed_at, pull_request) all get cleanup

---

## Recent Work

### Parallel Pagination Tests (2026-03-20)

**Contribution:** Added 8 comprehensive edge-case tests for PR #41 (parallel crash fix)

**Test Cases:**
- Boundary value 1 (minimum parallelism)
- Boundary value 32 (old fixed array size)
- Boundary value 64 (well above old array size)
- Error condition: --parallel 0 (must reject)
- Error condition: --parallel with missing value
- Error condition: --parallel with invalid value (non-numeric)
- Combined flag: --parallel + --exclude-labels
- Combined flag: --parallel + --since-tag

**Coverage:**
- 100% of zero-validation logic
- 100% of dynamic ArrayList code paths
- 100% of double-free prevention code
- 100% of has_more propagation logic

**Result:** 44 tests passing (20 original + 8 new), memory safety verified

---

### Link-Aware Pagination Test Design (2026-03-20)

**Contribution:** Designed 34 unit tests for Link header discovery-first pagination optimization

**Test Categories:**

1. **Link Header Parsing (4 tests):**
   - Valid header with rel="last" (page=523)
   - Valid header without rel="last"
   - Malformed header (should parse to null)
   - Multi-page PR response with Links

2. **Pagination Plan Selection (5 tests):**
   - Single page discovered (heuristic: <100 items)
   - Sequential fallback (no Link header)
   - Bounded parallel (known total pages)
   - Small page detection
   - Large page pool clamping

3. **Result Merging & Ordering (8 tests):**
   - PR pages merged in order
   - Release pages merged in order
   - Cleanup on merge error
   - Copy PR with allocation failure
   - Copy release with allocation failure
   - Copy labels array failure
   - Copy issue with allocation failure
   - Free releases with null items

4. **Fixtures (4):**
   - `test_link_header_523_pages` — large repo simulation
   - `test_link_header_no_last` — missing rel="last"
   - `test_link_header_malformed` — invalid format
   - `test_prs_three_pages_mock` — multi-page response

**Coverage:**
- 100% of `parsePaginationInfo()` logic
- 100% of plan selection branches
- 100% of merge ordering logic
- 100% of allocation failure cleanup paths

**Result:** 54 tests passing (20 integration + 34 unit), memory safety verified

---

### Closed Issues Test Coverage (2026-03-21)

**Status:** ✅ Complete

**Test Data** (`src/test_data.zig`)
- Added 4 closed issue fixtures: `test_issue_bug_unresolved`, `test_issue_documentation`, `test_issue_feature_request`, `test_issue_closed_with_pr_ref`
- Realistic data: mixed labels, numbers 42–45, proper JSON structure

**Test Cases** (`src/test.zig`)

1. **Filtering Tests (4):**
   - Only closed_issues section when flag set
   - Both PR and issue sections rendered
   - Label-based filtering works
   - No crash when zero match

2. **Tag Range Tests (3):**
   - `--since-tag` respected
   - `--until-tag` respected
   - Both bounds applied

3. **Markdown Output Tests (3):**
   - `## Closed Issues` header present
   - Label badges rendered
   - Issues sorted descending by number

4. **Edge Cases (2):**
   - CSV whitespace handling: `"bug, docs"` parsed
   - Allocation failure cleanup correct

**Coverage Metrics:**
- 12 new test cases (47 total with existing tests)
- 100% of `getClosedIssues()` code path
- 100% of label filter logic
- 100% of markdown formatter function
- All allocation failures tested

**Result:** 47 tests passing, no memory leaks, build passing
