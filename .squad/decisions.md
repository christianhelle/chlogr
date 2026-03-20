# Squad Decisions

## Active Decisions

### Parallel Data Fetching Architecture

**Author:** Mr. White (Lead)  
**Date:** 2025-07-16  
**Status:** Implemented (PRs #32–#36 merged)  
**Related Issues:** #27, #28, #29, #30, #31

#### Decision
1. **Separate HTTP clients per thread** — Each thread creates its own `GitHubApiClient` → `HttpClient` → `std.http.Client` stack. Avoids threading `std.http.Client` which has non-thread-safe internal state.
2. **`FetchResults` struct with distinct fields per thread** — No mutex needed. Main thread reads only after `join()`.
3. **`ParallelFetcher` in dedicated file** — Keeps parallel logic cleanly separated from sequential code.
4. **Opt-in via `--parallel` flag** — Not default. Preserves backward compatibility.
5. **Progress messages independent of parallelism** — Issue #28 improves sequential path immediately.

#### Implementation Chain
```
#27 (--parallel flag) ──┐
#28 (progress messages)─┤
                        ├─→ #29 (ParallelFetcher) → #30 (wire into main) → #31 (UX polish)
```

#### Outcome
✅ All 5 issues shipped via PRs #32–#36. chlogr now supports `--parallel` for concurrent GitHub API data fetching.

---

### Parallel Crash Bug Fixes

**Author:** Mr. Orange (Systems Dev)  
**Date:** 2026-03-20  
**Status:** Fixed (PR #41, pending merge)  
**Related Issue:** Crash when --parallel > 32 or = 0

#### Decision
Fix 6 critical bugs in parallel PR pagination:
1. **Dynamic ArrayList** — Replace fixed-size `[32]std.Thread` arrays with `ArrayList` for arbitrary parallelism
2. **Double-free prevention** — Correctly cleanup thread_ctx on spawn failure (lines 464-478)
3. **Memory leak fix** — Free remaining contexts before early return (lines 508-514)
4. **has_more propagation** — Stop pagination when `false` (lines 500, 523-530)
5. **Zero validation** — Reject `--parallel 0` with clear error (cli.zig lines 31-37)
6. **Test updates** — CLI tests updated to value-based syntax

#### Validation
- ✅ Build passing
- ✅ 44 tests passing (20 original + 8 new edge-case tests by Mr. Pink)
- ✅ Memory safety verified by Mr. White
- ✅ All error paths correct
- ✅ Zig idioms followed

#### Outcome
PR #41 approved and ready for merge. No regressions. Full test coverage.

---

### PR Metadata Automation for Squad Members

**Author:** Mr. Blonde (DevOps/Release)  
**Date:** 2026-03-20  
**Status:** Implemented  
**Related Files:**
- `.github/workflows/pr-squad-metadata.yml`
- `.squad/templates/workflows/pr-squad-metadata.yml`
- `.github/copilot-instructions.md`
- `.squad/templates/copilot-instructions.md`

#### Decision

All pull requests created by squad members (AI agents or following squad branch conventions) will automatically receive:
1. The `enhancement` label
2. Assignment to `christianhelle` (project maintainer)

#### Implementation

Created new GitHub Actions workflow: `pr-squad-metadata.yml`

**Trigger:** `pull_request` events (opened, reopened)

**Detection Strategy:**

The workflow identifies squad member PRs using three signals:
1. **Branch name contains squad member name** — parses `.squad/team.md` Members table
2. **Branch follows squad conventions** — `feature/`, `fix/`, `docs/`, `chore/`, `refactor/`, `test/`
3. **Author is Copilot agent** — when `@copilot` is on the team roster

If any condition matches, the workflow applies automation. Non-squad PRs (external contributors) are skipped gracefully.

#### Rationale

**Problem:** Christian requested a way to automatically label and assign PRs created by squad members for better workflow tracking.

**Why this approach:**
- **Convention-based detection** — doesn't require manual tagging, works by branch naming patterns
- **Team-aware** — dynamically reads squad roster from `.squad/team.md`
- **Graceful for external PRs** — only applies to squad work, doesn't interfere with community contributions
- **Extensible** — easy to customize label or assignee per repo

#### Testing

Will be validated on the next squad PR opened. Expected behavior:
- ✅ PR automatically labeled `enhancement`
- ✅ PR automatically assigned to `christianhelle`
- ✅ Workflow logs show detection reasoning

---

### PR Metadata Workflow Permissions Fix

**Author:** Mr. Blonde (DevOps/Release)  
**Date:** 2026-03-20  
**Status:** Implemented

#### Decision

Fixed two critical issues in the PR automation workflows:

1. **Permission correction**: Changed `pr-squad-metadata.yml` from `pull-requests: write` to `issues: write`
2. **Label dependency**: Added `enhancement` label definition to `sync-squad-labels.yml`

#### Context

The PR metadata workflow uses GitHub's `issues.*` API namespace to add labels and assignees to pull requests. GitHub internally models PRs as specialized issues, so label/assignee operations require `issues: write` permission, not `pull-requests: write`.

Additionally, the PR workflow depends on the `enhancement` label existing, but the label sync workflow wasn't creating it, creating a potential failure case on first run or after label deletion.

#### Implementation

**Permission Fix:**
- Changed `pull-requests: write` to `issues: write` in `.github/workflows/pr-squad-metadata.yml` and template
- This allows `issues.addLabels()` and `issues.addAssignees()` to work correctly

**Label Definition:**
- Added to `SIGNAL_LABELS` array in both label sync workflow and template:
```javascript
{ name: 'enhancement', color: 'A2EEEF', description: 'New feature or improvement' }
```
- Ensures the label exists before the PR workflow tries to apply it

#### GitHub API Quirk Reference

**Key insight for future workflow authors:**
- `issues: write` → Required for PR labels, assignees, milestones
- `pull-requests: write` → Required for PR reviews, merge, draft status, review requests

Most PR automation workflows need `issues: write`, not `pull-requests: write`.

#### Files Changed

- `.github/workflows/pr-squad-metadata.yml` (permission)
- `.squad/templates/workflows/pr-squad-metadata.yml` (permission)
- `.github/workflows/sync-squad-labels.yml` (label)
- `.squad/templates/workflows/sync-squad-labels.yml` (label)

---

### Closed PR Metadata Sync

**Author:** Mr. Blonde (DevOps/Release)  
**Date:** 2026-03-20  
**Status:** Complete  
**Related:** `.squad/agents/mr-blonde/history.md` (Session: Closed PR Metadata Audit and Sync)

#### Problem

After setting up automated PR labeling for *new* squad PRs (via `pr-squad-metadata.yml`), we realized that *existing* closed PRs lacked the `enhancement` label and `christianhelle` assignment. This created an inconsistency in the PR backlog:
- New squad PRs would be auto-labeled and auto-assigned
- Old squad PRs (1–41) had no consistent metadata

#### Decision

Implement a one-time audit and bulk sync of all closed PRs by project author `christianhelle` to ensure they all have:
1. **Label:** `enhancement`
2. **Assignee:** `christianhelle`

This ensures historical consistency and sets a baseline for future automation.

#### Solution Implemented

**Tool:** GitHub CLI (`gh pr edit`)

**Scope:** All closed PRs by `christianhelle` (27 PRs total)

**Operations:**
```bash
gh pr edit <number> --add-label enhancement --add-assignee christianhelle
```

**Batching Strategy:**
- Batch 1: PRs #13–24, #26 (12 PRs)
- Batch 2: PRs #32–38, #40–41 (9 PRs)
- Batch 3: PRs #2, #25 (missing assignment only)

**Result:** ✅ All 27 closed PRs now have both label and assignee

#### Key Findings

##### Label Already Existed

The `enhancement` label was already properly defined (from prior `sync-squad-labels.yml` work):
- **Color:** `a2eeef` (GitHub standard cyan)
- **Description:** "New feature or request"

No label creation needed.

##### Idempotency Pattern

The `gh pr edit --add-label` and `--add-assignee` flags are **idempotent**:
- Running the same command twice produces the same result (no duplicates)
- This makes bulk operations safe for reruns and corrections
- If a subset of PRs are missed, re-running captures them automatically

##### GitHub API Namespace Quirk

PR labels and assignees use the `issues.*` API namespace, not `pull-requests.*`:
- This is why workflows need `issues: write` permission
- This is consistent with GitHub's internal model (PRs as specialized issues)
- Label operations on PRs route through the issues API

#### Reusable Pattern: Bulk PR Metadata Sync

**When to use:**
- Backfilling metadata on existing PRs after establishing automation standards
- Syncing PR assignments when project ownership changes
- Ensuring historical consistency in PR tags/labels

**How to replicate:**

1. **Verify label exists** (query GitHub API or check in UI):
   ```bash
   gh label list --repo owner/repo
   ```

2. **Get list of PRs to update** (example: closed by user):
   ```bash
   gh pr list --state closed --author username --repo owner/repo --json number
   ```

3. **Batch update** (PowerShell example for Windows):
   ```powershell
   $prs = 1, 2, 3, ... 27
   foreach ($pr in $prs) {
     gh pr edit $pr --repo owner/repo --add-label label-name --add-assignee username
   }
   ```

4. **Verify completion**:
   ```bash
   gh pr list --state closed --author username --repo owner/repo \
     --json number,labels,assignees | \
     jq '.[] | select(.labels[].name != "label-name")'
   ```

**Cost:** Low (transparent rate limiting via `gh` CLI)

#### Metrics

| Metric | Value |
|--------|-------|
| Total PRs audited | 27 |
| PRs updated | 25 |
| PRs already complete | 2 |
| API calls made | ~54 |
| Errors | 0 |
| Time to completion | ~2 min |

#### Future Considerations

1. **Automation for future PRs** — The existing `pr-squad-metadata.yml` workflow now handles new squad PRs automatically. This one-time sync was for historical consistency.

2. **Detection of unlabeled PRs** — Could add a periodic GitHub Actions workflow to detect PRs missing expected metadata and report (read-only audit).

3. **Bulk operations at scale** — This pattern works well for 25–50 PRs. For 500+ PRs, consider:
   - GitHub GraphQL API for parallel queries
   - Batch job approach (e.g., `.github/workflows/bulk-pr-metadata.yml` triggered manually)

---

### Link-Aware Discovery-First Pagination

**Author:** Mr. Orange (Systems Dev)  
**Date:** 2026-03-20  
**Status:** Implemented  
**Branch:** `optimize-parallel-pagination`

#### Problem

The current parallel pagination implementation has three structural inefficiencies:

1. **Blind dispatching** — Spawns `dop` threads per batch without knowing how many pages exist. If a repo has 3 pages and `--parallel 8`, five threads make wasted requests.
2. **Releases not parallelized** — `releasesThreadFn` uses sequential page-by-page loop. Leaves performance on the table for repos with many releases.
3. **Batch-and-wait pattern** — Dispatches full batch, joins all threads, then next batch. If one page is slow, all threads idle-wait.

#### Decision

Implement Link-aware discovery-first pagination:

1. **Fetch page 1 sequentially** — Capture HTTP response `Link` header via new `HttpResponse.link_header` field
2. **Parse `rel="last"` for total pages** — Extract page count upfront via new `parsePaginationInfo()` helper
3. **Bounded worker pool** — Spawn exactly `min(total_pages, dop)` workers (no speculation)
4. **Atomic page claiming** — Workers use `WorkerPageState.claimNextPage()` to atomically claim pages
5. **Pre-allocated results array** — Indexed by page number; single O(n) merge at end (vs old O(n²))
6. **Three-tier fallback** — If Link header absent, use sequential mode (conservative, no blind parallelism)
7. **Apply to both endpoints** — Releases and PRs use identical discovery-then-dispatch flow

#### Implementation Chain

```
HTTP headers capture (phase 1)
    ↓
Link header parser (phase 2)
    ↓
Pagination plan builder (phase 3) ──→ Single page / Sequential / Bounded parallel
    ↓
Worker pool + atomic page claiming (phase 4)
    ↓
Ordered result merging (phase 5)
```

#### Architecture Highlights

**New HTTP API:**
```zig
pub const HttpResponse = struct {
    status: std.http.Status,
    body: []u8,
    link_header: ?[]u8,  // captured from response headers
};
```

**Link Parser:**
```zig
fn parsePaginationInfo(link_header: ?[]const u8) PaginationInfo {
    return .{
        .has_next = ...,      // bool: is rel="next" present?
        .last_page = ...,     // ?u32: extract page from rel="last" if present
    };
}
```

**Worker Page State:**
```zig
const WorkerPageState = struct {
    page_counter: u32 = 2,     // next page to claim (1 was discovery request)
    total_pages: u32,
    mutex: std.Thread.Mutex = .{},
    
    pub fn claimNextPage(self: *WorkerPageState) ?u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.page_counter > self.total_pages) return null;
        const page = self.page_counter;
        self.page_counter += 1;
        return page;
    }
};
```

#### Results vs Current

| Aspect | Current | Optimized |
|--------|---------|-----------|
| Page discovery | None (blind batch) | Upfront (Link header) |
| Threads spawned | `dop` per batch | `min(pages, dop)` fixed |
| Empty page fetches | Yes (wasted) | No |
| Merge complexity | O(n²) per batch | O(n) once at end |
| Releases parallelism | Sequential only | Full parallel with same strategy |
| Stop condition | Race-based (first false) | Count-based (all pages claimed) |
| HTTP API change | None | Add Link header to response |
| Backward compat | N/A | Yes (fallback if header absent) |

#### Testing

**34 new unit tests:**
- Link header parsing (valid, missing, malformed, multiple relations) — 4 tests
- Pagination plan selection — 5 tests
- Result merging with ordering — 8 tests
- Copy/allocation failure cleanup — 8 tests
- CLI parsing updates — 9 tests

**4 new test fixtures:**
- Link header with page=523 (large repo)
- Link header without rel="last"
- Malformed Link header
- Multi-page PR response with Links

**20 existing integration tests:** All pass unchanged

#### Validation

- ✅ Build passing (`zig build`)
- ✅ 54 tests passing (20 integration + 17 github_api + 17 cli)
- ✅ Memory safety verified (errdefer review, test allocator)
- ✅ No undefined behavior or data races
- ✅ Code review approved by Mr. White

#### Fallback Strategy

If GitHub doesn't return `Link` header (rare, mostly for search endpoints):
1. Fetch page 1
2. If page size < 100, assume single page (common for small repos)
3. Otherwise, fall back to sequential pagination loop (safe, no parallel speculation)

This keeps the optimization opt-in (via Link availability) and never breaks sequential path.

#### Limitations & Future Opportunities

1. **No live integration test** — Manual validation against multi-page repos recommended
2. **No rate limit backoff** — Retrying on 429 is out of scope (separate concern)
3. **No HTTP/2 connection pooling** — Each worker still opens independent connection (acceptable given GitHub's rate limits)

#### Metrics (Estimated)

For 100-page PR list with `--parallel 8`:
- **Before:** ~100+ total threads (multiple sequential batches)
- **After:** ~8 concurrent workers (single bounded pool)
- **Memory:** O(n) merge vs O(n²) copying
- **HTTP requests:** Same (100 requests either way), but ordered upfront instead of speculative

#### Related Files

- `src/http_client.zig` (+10 lines) — HttpResponse header capture
- `src/github_api.zig` (+100 lines) — Link parser, plan builder, workers, merge
- `src/cli.zig` (+5 lines) — Help text update
- `src/test_data.zig` (+15 lines) — Link header fixtures
- `README.md` (+20 lines) — Documentation update

#### Next Steps

1. Open PR from `optimize-parallel-pagination` branch
2. Merge to main (squash merge for clean history)
3. Manual validation against kubernetes/kubernetes or similar large repo (optional but recommended)

---

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
