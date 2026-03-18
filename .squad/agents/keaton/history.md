# Keaton — History

## Project Context (Day 1)

**Project:** chlogr — Zig CLI tool for GitHub release changelog generation  
**Language:** Zig v0.15.2  
**User:** Christian Helle  
**Date Initialized:** 2026-03-18  

**What we're building:** A command-line tool that ingests GitHub repository data (releases, merged PRs, closed issues) and generates structured changelogs. Users can filter by release, date range, and category.

**Team:** Keaton (Lead), Fenster (CLI Dev), Hockney (Tester), McManus (DevRel), Scribe (Logger), Ralph (Monitor)

## Learnings

### Codebase Architecture (Day 1 Analysis)

**Project Size:** ~1800 lines Zig; core logic split into 4 modules:
- `github_api.zig` — GitHub API client with fetch methods + owned allocation helpers
- `changelog_generator.zig` — Core logic: group PRs by release using timestamp comparison
- `markdown_formatter.zig` — Render changelog to markdown
- `token_resolver.zig` — Multi-fallback GitHub token resolution (env vars + gh CLI)
- `cli.zig` — CLI argument parsing
- `main.zig` — Orchestration

**Allocation Model:**
- Zig GeneralPurposeAllocator throughout
- Owned strings (duped from API JSON responses)
- Cleanup methods on API client (`freeReleases`, `freePullRequests`, `freeIssues`)
- **Pain point:** Inconsistent error handling in deep-copy loops; missing `errdefer` for partial allocations

**Critical Data Flow:**
1. CLI parses args (--repo, --token, --exclude-labels, --since-tag, --until-tag)
2. TokenResolver resolves token via fallback chain (provided → GITHUB_TOKEN → GH_TOKEN → `gh auth token`)
3. GitHubApiClient fetches releases and PRs (currently single page only)
4. ChangelogGenerator groups PRs into release buckets + unreleased section
5. MarkdownFormatter renders to CHANGELOG.md

**Test Infrastructure:**
- Baseline test suite: 12 tests, all passing
- Uses `test_data.zig` for JSON fixtures
- Good coverage of basic generation and exclusion logic
- **Gap:** No failing-allocator tests; no pagination tests; no process-edge-case tests

### Issue Landscape (9 Issues, All P0–P3)

**P0 (Safety, blocks P1):**
- #3: Uninitialized ArrayList in deferred cleanup (unsafe allocation paths)
- #4: Token resolver process handling bugs (abnormal exit + stderr deadlock)

**P1 (Correctness):**
- #5: Release assignment truncates timestamps; PR can appear in multiple releases
- #6: Deep-copy paths leak allocations on error (missing errdefer)
- #7: No pagination; hardcoded 100 PRs, single page only
- #8: --since/--until flags advertised but not implemented (scope decision needed)
- #9: --exclude-labels uses substring matching, not exact CSV tokens

**P2:**
- #10: Release links hardcoded to "owner/repo"; don't use real repo slug

**P3:**
- #11: Allocation churn in generation and formatting loops (optimization)

**Hard Dependency:** P0 must complete before P1 testing is reliable. All issues are sequential; none can parallelize due to intertwined allocator patterns and shared state changes.

### Key Architectural Patterns

**Allocator cleanup pattern (current):**
```zig
var items = try std.ArrayList(Item).initCapacity(allocator, cap);
defer items.deinit(allocator);
// ... loop that may partially append ...
```
**Problem:** If append fails mid-way, `items.deinit()` still runs but some fields were never initialized.
**Solution:** Use `errdefer` at point of fallible operation, or pre-initialize all fields before error path exists.

**Timestamp comparison (current):**
- Truncates to `YYYY-MM-DD` by breaking at `T`
- Compares as string lexicographically
- **Problem:** Loses time-of-day; same-day merges can flip their release bucket

**Release window (current):**
- PR included in release[i] if `merged_at < release[i].published_at`
- **Problem:** No lower bound; PR can also qualify for release[i-1], [i-2], etc.

**Token resolution (current):**
- 4-step fallback: provided → GITHUB_TOKEN → GH_TOKEN → `gh auth token`
- **Problem:** `gh auth token` call doesn't drain stderr; direct union field access on Term without variant check

### Team Routing Decision

- **Fenster (CLI Dev):** #3, #4, #6, #9 — owns API client and generator
- **McManus (DevRel):** #5, #8 — defines correctness semantics and product scope
- **Hockney (Tester):** #7, extended suite — pagination and large-repo testing
- **Scribe (Logger):** #10 — markdown formatter
- **Ralph (Monitor):** #11 post-P1 — profiling and optimization

### Sprint Execution (Day 1 Orchestration)

**Completed:**
- ✅ Priority assessment: P0 (2 issues), P1 (4 issues), P2 (1 issue), P3 (1 issue)
- ✅ Issue routing: Assigned owners to each issue based on domain expertise
- ✅ Dependency mapping: Established hard dependency P0 → P1; no parallelization
- ✅ Risk identification: Allocator safety, process edge cases, scope creep, silent correctness bugs
- ✅ Team routing decisions documented in charter.md

**In Flight:**
- 🔄 Fenster: P0 fixes (#3, #4) with regression tests
- 🔄 McManus: RFC for #5 window semantics; decision on #8 scope
- 🔄 Hockney: Test scaffolding for P0–P1 validation
- 🔄 Scribe: Orchestration/decision logs (this session)

### Code Conventions

- Error handling: `try` for propagation; `catch` only when explicitly handled
- Defer cleanup: use `errdefer` for partial-state rollback
- String duplication: `allocator.dupe()` always matched with corresponding `.free()`
- No naked pointer arithmetic; use slices and array lists
- Tests use `std.testing.expect()` for assertions

### Risk Flags

1. **Allocator pressure:** Baseline tests pass under normal allocator. Real failures surface under pressure or edge cases (e.g., many releases/PRs, failing allocator, OOM).
2. **Process handling:** Token resolution can hang if stderr fills or gh exits abnormally.
3. **Silent correctness bugs:** Release assignment and label exclusion can fail silently; wrong changelog looks valid.
4. **Feature scope:** #8 (since/until tags) advertised but unimplemented; must decide now or remove.

---

## P0 Merge Review (2026-03-18)

### Decision: APPROVED ✅

P0 fixes (#3, #4) merged to main. All tests passing, fixes are sound and production-ready.

### Code Review Findings

**Issue #3 Fix (ArrayList Safety):**
- **Before:** `catch continue` swallowed errors, `initCapacity()` pre-allocated memory that may never be used
- **After:** `try` propagates errors properly, `ArrayList.empty` initializes without allocation
- **Pattern:** Using `.empty` is safer when final size unknown; reduces allocator pressure
- **Test Coverage:** Comprehensive failing allocator tests validate correct error propagation

**Issue #4 Fix (Token Resolution):**
- **Before:** Direct union field access `.Exited` without variant check, stderr piped but never drained (deadlock risk)
- **After:** Explicit `switch` on all termination cases, stderr ignored entirely
- **Pattern:** Always use exhaustive switch on process termination; ignore stderr when output not needed
- **Test Coverage:** Process edge cases (abnormal exit, signal, deadlock) all validated

### Key Learnings

1. **ArrayList.empty vs initCapacity:** When exact size is unknown or variable, prefer `.empty` initialization. Only use `initCapacity()` when size is known upfront and all elements will be added.

2. **Process stderr handling:** If stderr output is not needed, use `.Ignore` instead of `.Pipe` to avoid deadlock on full pipe buffer. Only pipe when you need to read the output.

3. **Union variant safety:** Never access union fields directly (e.g., `term.Exited`). Always use exhaustive switch to handle all cases. This prevents crashes on unexpected variants.

4. **Error propagation vs catch-continue:** Using `catch continue` in critical paths silently swallows errors and can lead to undefined behavior. Use `try` for propagation or explicit error handling with logged diagnostics.

5. **Test-driven safety fixes:** The failing allocator tests and process edge-case tests were critical to validating the fixes. Without them, we'd have no evidence the bugs were actually resolved.

### P1 Priorities

With P0 complete, P1 work can proceed in parallel:

**Immediate Start (Parallel):**
- #6 (allocation cleanup) — Similar patterns to #3, add errdefer to API client
- #9 (label parsing) — CSV tokenization, whitespace handling
- #5 (timestamp semantics) — Full ISO-8601 comparison, affects #7
- #8 (tag rejection) — Product scope decision, add validation
- #10 (release links) — Formatter fix, pass repo slug

**After #5:**
- #7 (pagination) — Should use corrected timestamp semantics for tests

### Code Quality Observations

**Strong Patterns:**
- Minimal, surgical changes focused on root cause
- No scope creep or over-engineering
- Excellent test coverage for edge cases
- Clear error propagation paths

**Watch For (P1):**
- Timestamp comparison changes (#5) will touch similar loops; ensure no regressions
- Pagination (#7) adds complexity; test thoroughly with large datasets
- Label parsing (#9) needs careful CSV tokenization; edge cases around whitespace, empty tokens

### Next Focus

**Gate Status:** P1 cleared for launch. Fenster, McManus, Scribe can begin parallel work immediately. Hockney should coordinate with McManus on #5 completion before finalizing #7 tests.
