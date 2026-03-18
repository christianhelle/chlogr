# P0/P1 Test Suite - Quick Reference

## Quick Start

```bash
# Run all P0/P1 tests
zig build test-all

# Run by issue
zig build test-allocator   # Issue #3 - Memory safety
zig build test-token        # Issue #4 - Token resolution
zig build test-timestamps   # Issue #5 - Timestamp comparison
zig build test-pagination   # Issue #7 - Multi-page fetching
zig build test-labels       # Issue #9 - Label exclusion
```

## Test Files

| Issue | File | Tests | Status |
|-------|------|-------|--------|
| #3 | `test_allocator_failures.zig` | OOM scenarios, leak detection | ✅ All pass |
| #4 | `test_token_resolver.zig` | Process errors, stderr handling | ✅ All pass |
| #5 | `test_timestamp_comparison.zig` | ISO-8601 precision, boundaries | ✅ Documents bug |
| #7 | `test_pagination.zig` + `test_pagination_data.zig` | Multi-page, sorting, rate limits | ✅ Documents bug |
| #9 | `test_label_exclusion.zig` | CSV parsing, exact match | ✅ Documents bug |

## What Each Test Suite Validates

### Issue #3 - Allocator Failures
**Validates:** Error path memory safety  
**Key Tests:**
- ✅ Allocation fails during section creation → no crash
- ✅ Allocation fails during PR append → no crash
- ⚠️  Memory leaks detected (expected - bug not fixed yet)

**Expected after fix:**
- errdefer cleanup in place
- No leaks on error paths

---

### Issue #4 - Token Resolution
**Validates:** Robustness against abnormal process states  
**Key Tests:**
- ✅ gh CLI exits with non-zero → graceful fallback
- ✅ gh CLI not installed → graceful fallback
- ✅ Empty token output → graceful fallback
- ✅ Stderr written → no deadlock
- ✅ Token from env var → owned memory tracked

**Expected behavior:** ✅ Already correct

---

### Issue #5 - Timestamp Comparison
**Validates:** Precision and correctness of PR assignment  
**Key Tests:**
- ⚠️  Microsecond precision → currently truncated to date
- ⚠️  Same-day, different times → all go to same bucket (BUG)
- ⚠️  Boundary (merged_at == published_at) → undefined
- ⚠️  Multiple releases same day → all merged PRs in one release (BUG)

**Expected after fix:**
- Full ISO-8601 string comparison
- Time-based windows, not date-based

---

### Issue #7 - Pagination
**Validates:** Completeness for large repositories  
**Key Tests:**
- ✅ 250 PRs across 3 pages → data structure correct
- ✅ 15 releases across 2 pages → data structure correct
- ✅ Release ordering → sort algorithm works
- ⚠️  Same-day merge/release → broken due to #5 bug
- ✅ 1000+ PRs → parsing scales
- ✅ Rate limit responses → can be parsed

**Expected after fix:**
- Pagination loop implemented
- Link header parsing
- All pages fetched and merged

---

### Issue #9 - Label Exclusion
**Validates:** Accuracy of label matching  
**Key Tests:**
- ⚠️  "bug" excludes "bugfix" → substring search (BUG)
- ⚠️  "bug, wontfix" → whitespace not trimmed (BUG)
- ✅ "bug,,wontfix" → empty tokens handled
- ✅ Case sensitivity → works as expected
- ⚠️  Multiple labels → substring matches all (BUG)

**Expected after fix:**
- CSV tokenization with trim
- Exact label name matching
- No substring matches

---

## Test Output Legend

- ✅ `PASSED` - Test executed successfully
- ⚠️  `CURRENT BEHAVIOR: ...` - Documents existing bug
- ✓  `EXPECTED BEHAVIOR: ...` - Documents correct behavior
- 🔴 `MEMORY LEAK DETECTED` - Allocator failure test found leak

## Interpreting Results

### Tests That Should Pass (Already Correct)
- All Issue #4 tests ✅

### Tests Documenting Bugs (Will Pass After Fixes)
- Issue #3: Memory leaks on error paths
- Issue #5: Timestamp truncation
- Issue #7: Same-day assignment (blocked by #5)
- Issue #9: Substring matching

### Tests That Verify Test Infrastructure
- Allocator failure simulation works
- Mock script execution works
- Test data generation works

## Next Steps

1. **Fenster fixes Issue #3 and #4**
   - Re-run `zig build test-allocator test-token`
   - Expect: No memory leaks, all pass

2. **McManus fixes Issue #5**
   - Re-run `zig build test-timestamps`
   - Update test expectations: change warnings to assertions

3. **Hockney fixes Issue #7** (after #5 complete)
   - Implement pagination loop
   - Re-run `zig build test-pagination`
   - Expect: Same-day test now passes

4. **Fenster fixes Issue #9**
   - Implement CSV tokenization
   - Re-run `zig build test-labels`
   - Update test expectations: exact match works

---

**See also:**
- `docs/test-suite.md` - Full documentation
- `.squad/decisions/inbox/hockney-test-gaps.md` - Coverage gaps and recommendations

**Hockney, QA Lead**  
*Built for testing, designed for quality.*
