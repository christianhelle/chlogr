# Copilot Instructions for chlogr

## Project Overview

**chlogr** is a Zig v0.15.2 CLI tool that generates structured changelogs from GitHub repository data (releases, merged PRs, closed issues).

**Current State:** P0 memory-safety fixes complete. P1 correctness issues ready for implementation.

**Repository:** `github.com/christianhelle/chlogr`

---

## Architecture

### Core Components

| File | Purpose | Status |
|------|---------|--------|
| `src/main.zig` | CLI entry point, argument parsing | Implemented |
| `src/cli.zig` | CLI flag definitions and parsing | Implemented; `--since-tag`/`--until-tag` unimplemented |
| `src/github_api.zig` | GitHub API client (releases, PRs, issues) | Partially broken (pagination, sorting) |
| `src/changelog_generator.zig` | Core changelog generation logic | P0 fixed; P1 issues remain |
| `src/markdown_formatter.zig` | Markdown output formatting | Uses hardcoded release links |
| `src/token_resolver.zig` | GitHub token resolution from gh CLI | P0 fixed (safe process handling) |
| `src/test.zig` | Baseline test suite | All 12 tests passing |
| `src/test_*.zig` | P0/P1 regression tests | All 27 tests passing |

### Key Patterns

**Zig 0.15.2 ArrayList Pattern:**
```zig
// Correct usage (what we fixed):
var list = .empty;  // Zero-cost initialization
try list.append(allocator, item);  // Allocator in every method
defer list.deinit(allocator);  // Allocator in deinit too
```

**Safe Process Handling:**
```zig
// Correct pattern for child processes:
var child = try std.process.Child.init(&cmd_args, allocator);
child.stderr_behavior = .Ignore;  // Never pipe stderr without draining it
const term = try child.wait();
switch (term) {
    .Exited => |code| if (code != 0) return error.NonZeroExit,
    else => return error.AbnormalExit,
}
```

**Safe Map Value Initialization:**
```zig
// Correct pattern for maps with ArrayList values:
var gop = try map.getOrPut(key);
if (!gop.found_existing) {
    gop.value_ptr.* = .{};  // Initialize BEFORE any fallible operation
}
try gop.value_ptr.append(allocator, item);  // Then use try, not catch continue
```

---

## Known Issues & Priority

### P0 (COMPLETED ✅)
- ✅ **#3** — Unsafe ArrayList initialization in changelog_generator.zig
- ✅ **#4** — Token resolution crashes/deadlocks in token_resolver.zig

### P1 (READY FOR IMPLEMENTATION 🔧)
- **#5** — Release assignment timestamps truncated to date-only; PRs can appear in multiple releases or disappear (Issue: compare full ISO-8601, enforce single-release assignment)
- **#7** — Pagination missing; only first page of releases/PRs fetched (Issue: implement pagination via Link headers in HttpResponse)
- **#6** — API deep-copy paths leak memory on allocation failures (Issue: add errdefer cleanup helpers)
- **#9** — Label exclusion uses substring matching instead of exact CSV tokens (Issue: split on commas, trim, compare with equality)
- **#8** — `--since-tag`/`--until-tag` flags are parsed but never used; should reject with error or implement

### P2 (LOWER PRIORITY)
- **#10** — Release links hardcoded to `github.com/owner/repo` instead of using CLI `--repo` value
- **#11** — Allocation churn in changelog generation; O(releases * prs) complexity

---

## Implementation Guidelines

### Branching Strategy (ENFORCED)
**NEVER commit to main.** Always create feature/fix branches:

- **Bug fixes:** `fix/{issue-number}-{slug}` (e.g., `fix/7-pagination-support`)
- **Features:** `feature/{slug}` (e.g., `feature/tag-filtering`)
- **Refactors:** `refactor/{slug}` (e.g., `refactor/allocation-reduction`)

Example:
```bash
git checkout -b fix/7-pagination-support
# ... make changes, test ...
git commit -m "Fix #7: Implement pagination for releases and PRs

..."
git push -u origin fix/7-pagination-support
# Create PR on GitHub
```

### Commit Style
- **Small logical groups**: One commit per fix, feature, or well-contained change
- **Reference issues**: Include `Fix #N:` or `Issue #N:` in commit message body
- **Test coverage**: Each commit that changes logic must pass existing + new tests
- **Co-author trailer**: End commit message with `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`

### Testing Requirements
- Run `zig build test-all` before pushing
- New features must add test cases in `src/test_*.zig`
- Regression tests already exist in test suite for P0/P1 issues

### Code Style
- Follow existing Zig patterns in the codebase
- Use `try` for error propagation, not `catch continue`
- Always pair allocate/free operations (use `errdefer` for cleanup)
- Comment complex allocation patterns
- Add `defer deinit()` early in functions that manage lifetime

---

## P1 Implementation Sequence

**Recommended order (dependencies first):**

1. **Issue #7** (Pagination) — Core correctness, unblocks other work
2. **Issue #5** (Timestamps) — Release assignment semantics
3. **Issue #6** (API cleanup) — Memory safety on error paths
4. **Issue #9** (Label matching) — Exact CSV parsing
5. **Issue #8** (Tag filters) — Reject with error or implement
6. **Issue #10** (Link rendering) — Low-risk, quick win

### Issue #7: Pagination (Core)
**Problem:** Only first page of releases/PRs fetched. PR sort is by `updated`, not `merged_at`.

**Solution:**
1. Modify `HttpResponse` struct to capture response headers
2. Parse `Link` header for pagination (GitHub uses `rel="next"` format)
3. Implement loop to fetch all pages of releases
4. Implement loop to fetch all pages of PRs, filter by `merged_at`
5. Update documentation with correctness claim

**Test coverage:** Already in `src/test_pagination.zig`

### Issue #5: Release Assignment Semantics
**Problem:** Timestamps truncated to `YYYY-MM-DD`, causing same-day merges to disappear.

**Solution:**
1. Compare full ISO-8601 timestamps (keep microseconds if present)
2. Define explicit semantics: PR can belong to at most one release
3. Sort releases explicitly before assignment (don't rely on API order)
4. Algorithm: Unreleased if merged_at > latest.published_at; else assign to oldest release where merged_at <= published_at
5. Document boundary behavior in code comments

**Test coverage:** Already in `src/test_timestamp_comparison.zig`

---

## Testing Strategy

**Run before every push:**
```bash
zig build test-all          # Run all 27 tests
zig build test-allocator   # Memory safety regression tests
zig build test-pagination  # Pagination correctness
zig build test-timestamps  # Release assignment correctness
```

**For P1 work:**
- Update relevant test file when implementing fix
- Add test case that documents bug behavior → expected behavior
- All tests must pass before pushing

---

## Common Patterns & Gotchas

### Zig 0.15.2 Allocator Patterns
- **ArrayList:** Requires allocator in `.append()`, `.deinit()`, `.toOwnedSlice()`
- **HashMap:** Requires allocator in `.getOrPut()`, `.deinit()`
- **Strings:** Use `allocator.dupe(u8, ...)` and `allocator.free(...)`
- **Error paths:** Always use `errdefer` to clean up partially initialized structures

### GitHub API Quirks
- Releases endpoint doesn't support sorting by `published_at`, only by creation
- PRs sorted by `updated` may not include all historically merged PRs
- Link headers use RFC 5988 format: `<url>; rel="next"`
- Rate limits: 60 req/min (unauthenticated), 5000 req/hour (authenticated)

### Release Assignment Rules (Proposed)
Given sorted releases (newest first):
```
for each PR:
  if PR.merged_at > releases[0].published_at:
    assign to Unreleased
  else:
    find oldest release where PR.merged_at <= release.published_at
    assign to that release
    if not found: discard (merged before all releases)
```

---

## Skill: Zig ArrayList & Process Safety

**Confidence:** `high` (established after P0 fixes)

Correctly use `ArrayList` with allocator-in-every-call pattern. Handle process termination with explicit switch, never directly access union fields. Always drain pipes or set them to `.Ignore`.

---

## Squad Context

**Team:** Keaton (Lead), Fenster (CLI Dev), Hockney (Tester), McManus (DevRel), Scribe (Logger), Ralph (Monitor)

**Decisions:**
- P0 → P1 implementation sequence (strict dependency)
- Pagination via loop + local filter (not Link header streaming)
- Release assignment: exclusive lower bound (Option B)
- Tag filters: reject with error now, implement post-P1

**Orchestration:** All decisions logged in `.squad/decisions.md`. Feature branches enable parallel P1 work without conflicts.

---

## Getting Started (First Issue)

1. Pick an issue from P1 (recommended: start with #7)
2. Create a feature branch: `git checkout -b fix/{number}-{slug}`
3. Review test expectations in `src/test_*.zig`
4. Implement the fix
5. Run full test suite: `zig build test-all`
6. Commit in logical groups with issue reference
7. Push and create PR: `git push -u origin fix/{number}-{slug}`

**Questions?** Check `.squad/decisions.md` for architectural decisions, or `.squad/agents/{name}/history.md` for learnings from implementation.
