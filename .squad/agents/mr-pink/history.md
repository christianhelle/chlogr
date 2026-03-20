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

## Learnings

## P2/P3 Code Review Session — PRs #22, #23, #24

### PR #22 — Exact CSV token matching (`fix/9-exclude-labels-csv`)

**Review verdict:** Approved. The fix is correct and complete.  
**Key observations:**
- Previous substring match via `std.mem.indexOf` allowed `"bug"` to match `"debug"` — a correctness bug.
- New approach (`splitScalar(',')` + `trim` + `eql`) is exact and handles whitespace-padded CSV input.
- Edge cases covered: empty label list, single label, multi-label CSV, substring-that-must-not-match.
- 19 tests; all pass.

### PR #23 — Dynamic repo slug in release header URLs (`fix/10-repo-slug`)

**Review verdict:** Approved. Clean struct extension, no regressions.  
**Key observations:**
- `MarkdownFormatter` promoted from zero-field struct to value-carrying struct; `init(allocator, repo)` is idiomatic.
- Release header anchor links now use the actual repo instead of a hardcoded placeholder.
- All formatter tests updated to supply `repo`; formatting output assertions adjusted for new URL shape.
- 20 tests; all pass.

### PR #24 — Reduce allocation churn (`fix/11-alloc-churn`)

**Review verdict:** Approved. Behaviour-preserving refactor; measurable allocation reduction.  
**Key observations:**
- `ArrayList(u8)` writer pattern replaces N `allocPrint` + N `free` pairs per markdown section with a single owned-slice allocation — correct and idiomatic Zig.
- `ensureTotalCapacity(allocator, 3)` on `AutoHashMap`s in `changelog_generator.zig` avoids rehash on the first few inserts (most changelogs have ≤ 3 PRs per release).
- No observable behavioural change; all 20 tests continue to pass.
- The pattern should be applied to any future string-building code added to `markdown_formatter.zig`.

## Parallel Crash Fix Review — `fix/parallel-crash` branch

**Date:** 2026-03-20  
**Changes by:** Mr. Orange  
**Review scope:** Test coverage validation for parallel PR fetcher fixes

### What I reviewed

Mr. Orange fixed 6 critical bugs in the parallel PR fetcher:
1. **Fixed-size array limit** — Replaced `[32]std.Thread` stack array with dynamic `ArrayList` to support arbitrary `--parallel N` values
2. **Double-free on thread spawn failure** — Fixed cleanup logic in error path
3. **Memory leak on partial results** — Fixed cleanup of remaining thread contexts before early return
4. **`has_more` propagation** — Now correctly stops pagination when GitHub API indicates no more pages
5. **CLI test updates** — Fixed existing tests to pass values to `--parallel` flag (no longer a boolean flag)
6. **`--parallel 0` validation** — Added check to reject zero (would cause infinite loop)

### What I added

**7 new edge case tests** to ensure comprehensive coverage:

#### CLI tests (src/cli.zig):
- `--parallel 1` → boundary test for minimum valid value
- `--parallel 32` → test old fixed-array boundary (ensures no regression)
- `--parallel 64` → test beyond old crash threshold (main bug fix validation)
- `--parallel` with missing value → validates `MissingParallelValue` error
- `--parallel abc` → validates `InvalidParallelValue` error for non-numeric input
- `--repo owner/repo --parallel 10` → validates combined flags work correctly

#### github_api.zig tests:
- `PrsPaginationResult` default fields test → validates `has_more` defaults to `false`, `prs` to empty slice, `prs_err` to null

### Test results

**Before:** 20 integration tests, 11 CLI unit tests  
**After:** 20 integration tests, 17 CLI unit tests, 1 new github_api unit test  
**Status:** ✅ All tests pass

### Code quality assessment

**Verdict:** EXCELLENT

Mr. Orange's fix is comprehensive and production-ready:
- Proper `errdefer` cleanup on all allocations
- No double-free risks remain
- No memory leaks in error paths
- ArrayList API used idiomatically
- Clear, actionable error messages for users
- `has_more` propagation prevents unnecessary API calls

**Recommendations:**
1. ✅ Approve for merge to `main`
2. Ensure README documents `--parallel <N>` syntax change (CLI help text already updated)

### Key takeaway

When reviewing dynamic memory allocation changes in Zig, always verify:
- `errdefer` blocks exist for every allocation
- Early returns clean up all partially-constructed state
- ArrayList capacity is properly managed (they used `initCapacity(..., 0)` which is fine — it defers allocation until first `append`)
- Thread join + context cleanup happens in the right order (join first, then free memory)

This review validated that Mr. Orange handled all of these correctly.

---

## Parallel Crash Fix — Complete (2026-03-20)

**Branch:** `fix/parallel-crash`  
**PR:** #41  
**Verdict:** ✅ APPROVED

### Team Collaboration

- **Mr. Orange:** Fixed all 6 critical bugs (ArrayList, double-free, memory leak, has_more, CLI tests, zero validation)
- **Mr. White:** Approved code review with high confidence — memory safety verified, comprehensive testing complete

### Final Metrics
- Build: ✅ PASS
- Tests: ✅ 44/44 PASS
- Memory safety: ✅ VERIFIED
- Status: Ready to merge
