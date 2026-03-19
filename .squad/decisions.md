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

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
