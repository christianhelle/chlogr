# Test Suite Documentation

This document describes the comprehensive test suites for P0 and P1 issues.

## Running Tests

```bash
# Run all P0/P1 tests
zig build test-all

# Run individual test suites
zig build test-allocator     # Issue #3: Allocator failures
zig build test-token          # Issue #4: Token resolution
zig build test-pagination     # Issue #7: Pagination
zig build test-labels         # Issue #9: Label exclusion
zig build test-timestamps     # Issue #5: Timestamp comparison
```

## Test Coverage

### Issue #3: Allocator Failure Tests
**File:** `src/test_allocator_failures.zig`

Tests memory safety and error handling:
- Allocation failure during first section creation
- Allocation failure during PR append to section
- Partial initialization cleanup correctness
- Memory leak detection on error paths

**Key Findings:**
- Memory leaks detected when allocation fails after initial ArrayList creation
- Current implementation doesn't clean up partially initialized data structures
- Tests document the need for `errdefer` cleanup patterns

### Issue #4: Token Resolution Tests
**File:** `src/test_token_resolver.zig`

Tests GitHub token resolution robustness:
- Abnormal gh process exit (non-zero, signal, crash)
- gh CLI not installed (FileNotFound)
- Empty token output from gh CLI
- Stderr written without causing deadlock
- Token resolution with and without GitHub token
- Environment variable token resolution

**Key Findings:**
- Current implementation handles stderr by ignoring it (may cause issues if stderr buffer fills)
- Process exit handling works correctly
- Token fallback chain operates as expected

### Issue #5: Timestamp Comparison Tests
**File:** `src/test_timestamp_comparison.zig`

Tests timestamp precision and comparison:
- Full ISO-8601 timestamp comparison with microsecond precision
- Same-day releases and PRs at different times
- Boundary condition: PR merged at exactly release time
- Millisecond precision preservation
- Multiple releases on same day with time-based windows

**Key Findings:**
- **CURRENT BEHAVIOR:** Timestamps truncated to date only (YYYY-MM-DD)
- **EXPECTED BEHAVIOR:** Full timestamp comparison preserving HH:MM:SS.microseconds
- Same-day PRs all assigned to same bucket instead of time-based windows
- Boundary semantics undefined (merged_at == published_at)

### Issue #7: Pagination Tests
**File:** `src/test_pagination.zig`  
**Data:** `src/test_pagination_data.zig`

Tests multi-page data fetching:
- 250 PRs across 3 pages (100, 100, 50)
- 15 releases across 2 pages (10, 5)
- Release ordering correctness (API may return unsorted)
- PR merged_at vs updated_at sorting
- Same-day merge/release assignment
- Large repository scenario (1000+ PRs)
- Rate limiting response handling (403, 429)

**Key Findings:**
- Current implementation only fetches first page (hardcoded limit)
- No pagination loop implemented
- Release sorting may be needed if API doesn't guarantee order
- Same-day assignment broken due to timestamp truncation

### Issue #9: Label Exclusion Tests
**File:** `src/test_label_exclusion.zig`

Tests CSV label parsing accuracy:
- Exact match: "bug" should not exclude "bugfix"
- Whitespace handling: "bug, wontfix" with spaces
- Empty tokens: "bug,,wontfix" (double comma)
- Case sensitivity verification
- Multiple label exclusion

**Key Findings:**
- **CURRENT BEHAVIOR:** Substring search in exclude string
- **EXPECTED BEHAVIOR:** CSV tokenization with exact label matching
- "bug" currently excludes "bugfix", "debugging", "bug-report", etc.
- Whitespace not trimmed from tokens

## Test Patterns

### 1. Failing Allocator Pattern
```zig
var failing_alloc = FailingAllocator{
    .parent_allocator = gpa.allocator(),
    .fail_after = N, // Fail after N allocations
};
const allocator = failing_alloc.allocator();
```

### 2. Mock Process Scripts
```zig
const script_content = "#!/bin/sh\necho 'output'\nexit 0\n";
const script_path = "/tmp/test_script.sh";
const file = try std.fs.createFileAbsolute(script_path, .{});
try file.writeAll(script_content);
file.close();
try std.posix.chmod(script_path, 0o755);
```

### 3. Test Data Generation
```zig
var test_data_gen = PaginationTestData.init(allocator);
const prs_json = try test_data_gen.generatePRs(100, 1, "2024-01-15T10:00:00Z");
defer allocator.free(prs_json);
```

## Coverage Gaps Identified

1. **Issue #3:** Need `errdefer` cleanup in changelog_generator.zig:
   - Lines 110-143: Section map initialization
   - Lines 170-204: Unreleased sections map

2. **Issue #4:** Stderr buffer deadlock risk:
   - Current: `.Ignore` bypasses stderr
   - Should: Drain stderr in background or use bounded buffer

3. **Issue #5:** Timestamp truncation in changelog_generator.zig:
   - Line 78-85: parseDateToSlice() truncates at 'T'
   - Should: Compare full ISO-8601 strings

4. **Issue #7:** No pagination implementation:
   - github_api.zig needs Link header parsing
   - Loop until no next page

5. **Issue #9:** Substring search in changelog_generator.zig:
   - Line 48: `std.mem.indexOf()` matches substrings
   - Should: Tokenize CSV, exact match on labels

## Test Execution Summary

All tests compile and run successfully. Tests document both:
- **Current behavior** (including bugs)
- **Expected behavior** (after fixes)

Tests use assertions where current behavior is correct, and documentation comments where bugs exist.

## Next Steps

1. Fix P0 issues (#3, #4) and verify tests pass
2. Fix P1 issues (#5, #7, #9) and update test expectations
3. Add regression tests for each fix
4. Expand test coverage to include:
   - Issue fetch pagination
   - Release pagination
   - Error response handling (404, 500, timeout)
   - Concurrent request scenarios
