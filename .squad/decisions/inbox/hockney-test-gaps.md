# Test Coverage Gaps and Recommendations

**Author:** Hockney (Tester)  
**Date:** 2026-03-18  
**Priority:** High

## Executive Summary

Comprehensive test suites written for P0 (#3, #4) and P1 (#5, #7, #9) issues. All tests compile and execute successfully. Tests document both current (buggy) behavior and expected behavior after fixes. **Critical gaps remain** in error path testing and concurrent scenarios.

---

## Identified Gaps

### 1. Issue #6 - Missing Test Coverage (P1)
**File:** `github_api.zig` - Deep-copy allocation failures  
**Status:** No tests written

**What's missing:**
- Allocation failure during release deep-copy (lines 40-48)
- Allocation failure during PR label copy (lines 75-81)
- Allocation failure during issue label copy (lines 123-129)
- Partial initialization when mid-loop allocation fails

**Why critical:**
Same pattern as Issue #3 - ArrayList allocated, then loop allocates, then toOwnedSlice. If allocation fails mid-loop, earlier allocations leak.

**Recommended test:**
```zig
fn testReleaseCopyAllocationFailure() !void {
    var failing_alloc = FailingAllocator{ .fail_after = 5 };
    // Parse 3 releases, fail on second release's string allocation
    // Verify first release's strings are cleaned up (no leak)
}
```

**Severity:** P1 - Same class of bug as #3, but in different file

---

### 2. Network Error Scenarios (All APIs)
**Files:** `github_api.zig`, `http_client.zig`  
**Status:** Not tested

**What's missing:**
- HTTP 404 (repository not found)
- HTTP 500 (server error)
- HTTP 403/429 (rate limiting) - documented but not tested with retries
- Network timeout (connection timeout, read timeout)
- Malformed JSON response
- Partial JSON response (connection drop mid-transfer)

**Why important:**
Real-world failures will hit these paths. No tests verify error messages, cleanup, or retry logic.

**Recommended test:**
```zig
fn testRateLimitRetry() !void {
    // Mock HTTP client returns 403 with Retry-After header
    // Verify exponential backoff or error propagation
    // Verify no resource leaks on repeated 403s
}
```

**Severity:** P2 - Production resilience

---

### 3. Concurrent/Parallel Request Scenarios
**Files:** `github_api.zig`, `main.zig`  
**Status:** Not tested

**What's missing:**
- Fetching releases + PRs + issues in parallel (if supported)
- Multiple page fetches in parallel (after pagination implemented)
- Thread safety of allocator usage
- Race conditions in error handling

**Why important:**
If pagination fetches pages in parallel, need to verify no data races or double-frees.

**Recommended approach:**
Wait until pagination is implemented, then add:
```zig
fn testParallelPageFetch() !void {
    // Spawn threads to fetch pages 1, 2, 3 simultaneously
    // Verify all pages collected, no double-free
}
```

**Severity:** P3 - Future-proofing (depends on pagination design)

---

### 4. Release/Issue Pagination
**Files:** `github_api.zig`  
**Status:** Test data exists, no implementation tests

**What's missing:**
- Actual pagination loop for releases (currently only PRs tested)
- Issue pagination (not mentioned in P0/P1 but same pattern)
- Edge case: exactly 100 items (is there a next page?)
- Edge case: 0 items

**Why important:**
getReleases() and getClosedIssues() have same hardcoded limit as getMergedPullRequests().

**Recommended test:**
```zig
fn testReleasePaginationLoop() !void {
    // Mock API returns Link: <...page=2>; rel="next"
    // Verify loop continues until no next link
    // Verify all pages merged into single result
}
```

**Severity:** P1 - Same bug as #7, just not documented

---

### 5. Timestamp Comparison Edge Cases
**File:** `changelog_generator.zig`  
**Status:** Boundary cases tested, but missing:

**What's missing:**
- Timezone handling (all tests use 'Z', what about +00:00 or -05:00?)
- Leap seconds (rare but valid in ISO-8601)
- Truncated timestamps (API returns "2024-01-10" without time)
- Invalid timestamps (malformed, unparseable)

**Why important:**
GitHub API may return varied timestamp formats. Need to verify robust parsing.

**Recommended test:**
```zig
fn testTimestampFormats() !void {
    // "2024-01-10T14:00:00Z"
    // "2024-01-10T14:00:00+00:00"
    // "2024-01-10T14:00:00.123456Z"
    // "2024-01-10" (no time)
    // Verify all parse correctly or fail gracefully
}
```

**Severity:** P2 - Defensive programming

---

### 6. Label Exclusion Tokenization
**File:** `changelog_generator.zig`  
**Status:** Bug documented, but missing:

**What's missing:**
- Test for leading/trailing whitespace: " bug , wontfix "
- Test for only commas: ",,,,"
- Test for single token: "bug"
- Test for empty exclude string: ""
- Test for null exclude string (current default)

**Why important:**
User input parsing needs to handle all edge cases gracefully.

**Recommended test:**
```zig
fn testLabelExclusionEdgeCases() !void {
    // Test: ""       → exclude nothing
    // Test: "   "    → exclude nothing
    // Test: ",,"     → exclude nothing
    // Test: " , , "  → exclude nothing
    // Test: "bug"    → exclude only "bug"
}
```

**Severity:** P1 - User-facing input validation

---

## Recommendations

### Immediate (P0 completion):
1. **Write tests for Issue #6** - Same allocator failure pattern as #3
2. **Expand label exclusion tests** - Cover all tokenization edge cases
3. **Add release/issue pagination tests** - Same bug as #7

### Short-term (P1 completion):
4. **Network error scenarios** - 404, 500, timeout, malformed JSON
5. **Timestamp format variations** - Timezone, truncated, invalid

### Long-term (P2-P3):
6. **Parallel fetch scenarios** - After pagination design finalized
7. **Stress testing** - 10,000+ PRs, rate limit exhaustion
8. **Integration tests** - Real GitHub API calls (opt-in, require token)

---

## Test Infrastructure Improvements

### Suggested Additions:
1. **Mock HTTP client** - Return canned responses, simulate errors
2. **Test fixture library** - Reusable JSON blobs for common scenarios
3. **Assertion helpers** - Custom matchers for changelog structure
4. **Performance benchmarks** - Baseline for optimization work (P3)

### Example Mock HTTP Client:
```zig
const MockHttpClient = struct {
    responses: []const MockResponse,
    call_count: usize = 0,
    
    const MockResponse = struct {
        status: http.Status,
        body: []const u8,
    };
    
    pub fn get(self: *MockHttpClient, endpoint: []const u8) !http.Response {
        const response = self.responses[self.call_count];
        self.call_count += 1;
        return response;
    }
};
```

This would enable testing error responses without process mocking.

---

## Conclusion

**Test suite foundation is solid.** All P0/P1 issues have test coverage documenting bugs and expected behavior. **Critical gaps:**

1. Issue #6 (allocation in github_api.zig) - needs tests NOW
2. Network error handling - production resilience
3. Release/issue pagination - same bug class as #7

**Action items:**
- Hockney writes #6 tests immediately
- Fenster includes network error tests when fixing #6
- Team discusses mock HTTP client for future tests

**Status:** Test infrastructure ready for P0/P1 fixes. Recommend no blocking on P2 gaps until P0/P1 complete.

---

**Hockney**  
*Quality is not an act, it is a habit.*
