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

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
