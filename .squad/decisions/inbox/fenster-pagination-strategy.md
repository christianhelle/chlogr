# Pagination Strategy for GitHub API (Issue #7)

**Date:** 2026-03-18  
**Author:** Fenster (CLI Dev)  
**Status:** Needs Keaton Review

---

## Problem

Current implementation:
- **Releases:** No pagination, fetches only first page (~30 items default)
- **PRs:** Hardcoded `per_page=100`, only fetches first page
- **Sorting:** PRs sorted by `updated`, not `merged_at` - may miss relevant PRs if old PR updated recently

**Impact:** Repos with >100 PRs or >30 releases will have incomplete changelogs.

---

## Technical Constraints

1. **GitHub API Rate Limits:**
   - Authenticated: 5,000 requests/hour
   - Unauthenticated: 60 requests/hour
   - Each page = 1 request

2. **Link Header Format:**
   ```
   Link: <https://api.github.com/repos/owner/repo/pulls?page=2>; rel="next",
         <https://api.github.com/repos/owner/repo/pulls?page=10>; rel="last"
   ```

3. **HttpResponse Structure:**
   Currently only captures body and status. Need to add headers.

---

## Proposed Solutions

### Option A: Fetch All Pages + Filter Locally (Recommended)
**Implementation:**
1. Modify `HttpResponse` to include `headers: []std.http.Header`
2. Parse `Link` header for `rel="next"`
3. Loop until no next page
4. Accumulate results into ArrayList, return owned slice

**Pros:**
- Complete changelog data
- Simple implementation
- Correct for repos of any size

**Cons:**
- Multiple API requests (consumes rate limit)
- Slower for large repos (100+ PRs = 2+ requests)

**Code Changes:**
```zig
// http_client.zig: Add headers to HttpResponse
pub const HttpResponse = struct {
    status: std.http.Status,
    body: []u8,
    headers: []std.http.Header, // NEW
};

// github_api.zig: Pagination loop
pub fn getMergedPullRequests(self: *GitHubApiClient) ![]models.PullRequest {
    var all_prs = std.ArrayList(models.PullRequest).init(self.allocator);
    var page: u32 = 1;
    
    while (true) {
        const endpoint = try std.fmt.allocPrint(
            self.allocator,
            "/repos/{s}/pulls?state=closed&per_page=100&page={d}",
            .{ self.repo, page }
        );
        defer self.allocator.free(endpoint);
        
        const response = try self.http_client.get(endpoint);
        defer self.allocator.free(response.body);
        
        // Parse and append PRs...
        
        // Check for next page in Link header
        if (!hasNextPage(response.headers)) break;
        page += 1;
    }
    
    return try all_prs.toOwnedSlice(self.allocator);
}
```

### Option B: Add Max-Page Limit
Same as Option A, but add `--max-pages` flag (default 10).

**Pros:** Protects against rate limit exhaustion  
**Cons:** Still incomplete for very large repos

### Option C: Query Strategy Change
Instead of pagination, use GraphQL API or date-based filtering:
- PRs: `?since=<last_release_date>`
- Use `sort=created` instead of `updated`

**Pros:** Fewer requests  
**Cons:** Complex filtering logic; doesn't solve releases pagination

---

## Recommended Approach

**Phase 1 (This Sprint):**
1. Implement Option A for PRs (fetch all pages)
2. Add pagination for releases
3. Change PR sort to `sort=created` for chronological order
4. Add logging: "Fetched page {page} ({count} PRs)" for transparency

**Phase 2 (Future):**
- Add `--max-pages` flag if rate limit becomes issue
- Add `--since` date filter for incremental changelog updates

---

## Questions for Keaton

1. **Approve Option A?** (Fetch all pages for PRs and releases)
2. **Max-page default?** Unlimited or cap at 10?
3. **Sort strategy?** Change from `updated` to `created` or keep current?
4. **Rate limit handling?** Log warning or fail when approaching limit?
5. **Releases pagination?** Enable or assume <30 releases sufficient?

---

## Acceptance Criteria (if approved)

- [ ] HttpResponse includes headers
- [ ] getMergedPullRequests paginates until no more pages
- [ ] getReleases paginates (or document assumption of <30)
- [ ] Add test with >100 mock PRs to verify pagination
- [ ] Log page fetches for user transparency
- [ ] Update README with rate limit guidance

---

**Next Step:** Awaiting Keaton's decision before implementation.
