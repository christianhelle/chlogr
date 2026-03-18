# Fenster P1 Launch Complete

**Date:** 2026-03-18  
**Agent:** Fenster (Implementation Engineer)  
**Status:** ✅ All 6 P1 branches created and pushed

## Summary

All 6 P1 issues have been implemented, tested, committed, and pushed to individual feature branches. Each fix addresses the root cause identified in the copilot-instructions.md and passes all existing tests.

## Branches Created

1. **fix/7-pagination-support** (HIGHEST PRIORITY)
   - Issue: #7 - Pagination support via Link headers
   - Commit: f3395e8
   - PR: #13 (draft)
   - Status: ✅ All tests passing

2. **fix/5-release-assignment-semantics** (HIGH PRIORITY)
   - Issue: #5 - Release assignment with full timestamp precision
   - Commit: e5dfc12
   - PR: #14 (draft)
   - Status: ✅ All tests passing

3. **fix/9-label-exclusion-exact-match** (MEDIUM PRIORITY)
   - Issue: #9 - Exact-match label exclusion
   - Commit: 1dfd692
   - PR: Pending creation
   - Status: ✅ All tests passing

4. **fix/6-api-deep-copy-cleanup** (MEDIUM PRIORITY)
   - Issue: #6 - Add errdefer cleanup to API copy functions
   - Commit: f43f4bd
   - PR: Pending creation
   - Status: ✅ All tests passing

5. **fix/8-tag-filter-rejection** (LOW PRIORITY)
   - Issue: #8 - Reject tag filter flags with clear error
   - Commit: 2ffa35a
   - PR: Pending creation
   - Status: ✅ All tests passing

6. **fix/10-release-link-rendering** (LOW PRIORITY)
   - Issue: #10 - Use actual repo slug in release links
   - Commit: 36f2e49
   - PR: Pending creation
   - Status: ✅ All tests passing

## Test Results

All branches pass the full test suite:
- ✅ 12 baseline tests
- ✅ 7 pagination tests (Issue #7)
- ✅ 5 timestamp comparison tests (Issue #5)
- ✅ 3 allocator failure tests (Issue #6)
- ✅ 5 label exclusion tests (Issue #9)
- ✅ Token resolver tests
- ✅ Integration tests

**Total:** 27+ tests passing across all branches

## Implementation Details

### Issue #7: Pagination Support
- Modified HttpResponse to capture Link header
- Implemented extractNextPageUrl() to parse RFC 5988 Link headers
- Updated getReleases() and getMergedPullRequests() to loop through all pages
- Each page fetches 100 items; continues until no next link present
- Proper errdefer cleanup on allocation failures during pagination

### Issue #5: Release Assignment Semantics
- Removed parseDateToSlice() that truncated timestamps to YYYY-MM-DD
- compareDates() now uses full ISO-8601 string comparison
- Added explicit release sorting (newest first) before PR assignment
- Changed boundary from `<` to `<=` for exact-time merges
- PRs merged at exact release time now belong to that release

### Issue #9: Label Exclusion Exact Match
- Changed from substring search (indexOf) to exact token matching
- Split exclude_labels on commas using tokenizeScalar
- Trim whitespace from each token
- Skip empty tokens
- Use std.mem.eql for exact string comparison

### Issue #6: API Deep-Copy Cleanup
- Added errdefer to getReleases() for partial release cleanup
- Added errdefer to getMergedPullRequests() for labels and PR fields
- Added errdefer to getClosedIssues() for labels and issue fields
- Each allocated string has corresponding errdefer cleanup
- Prevents memory leaks on allocation failures mid-copy

### Issue #8: Tag Filter Rejection
- Added validation in CLI parser for --since-tag and --until-tag
- Returns error.NotYetImplemented with helpful message
- Error message includes GitHub issue #8 link
- Updated help text to move tag filters to "Planned Features"
- Prevents silent failures from unimplemented flags

### Issue #10: Release Link Rendering
- Added repo_slug parameter to MarkdownFormatter.init()
- Release links now use actual repo slug instead of "owner/repo"
- Passed parsed_args.repo from main.zig to formatter
- Updated all test files to pass repo slug parameter

## Ready for Review

All branches are ready for Keaton's review and merge approval. Each fix is independent and can be merged in any order, though the recommended merge order follows the priority sequence:

1. #7 (Pagination) - Highest impact
2. #5 (Timestamps) - High impact
3. #6 (API cleanup) - Medium impact (memory safety)
4. #9 (Label exclusion) - Medium impact
5. #8 (Tag filters) - Low impact (UX improvement)
6. #10 (Release links) - Low impact (cosmetic fix)

## Co-authored-by Trailer

All commits include:
```
Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```
