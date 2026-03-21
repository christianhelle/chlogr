# Mr. White — History

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

## Core Context

**Code Review Work (2026-03-18 to 2026-03-20):**
- P1 Wave series: reviewed pagination, tag filtering, parallel fetching, progress output. All 5 issues shipped via PRs #32–#36.
- P2/P3 Code reviews: approved CSV label matching, dynamic repo slugs, CLI help text updates.
- PR #38: README hygiene governance established (documentation must stay in sync with features).
- PR #41 Parallel Crash Fix: verified 6 critical bug fixes (dynamic ArrayList, double-free prevention, memory leak cleanup, has_more propagation, zero validation, test updates). 44 tests passing, memory safety verified.
- Link-Aware Pagination: approved 34 new unit tests (Link header parsing, plan selection, result ordering, allocation failure cleanup). 54 tests passing.

**Current Status:**
- 47 tests passing (20 integration + 27 unit)
- All critical code paths reviewed and approved
- Memory safety verified across pagination and parallelism
- Build passing on all platforms
- Ready for production

## Learnings

**Memory Safety in Zig:**
- `errdefer` chains on outer allocations cover partial failures across multi-page loops
- `defer` on temporary allocations (URL strings) prevents unbounded memory growth in pagination
- Labeled blocks (`blk: { ... break :blk value }`) are idiomatic for if/else value returns
- `toOwnedSlice()` transfers ownership cleanly; matching `deinit()` pairs with correct allocator

**Thread-Safe Pagination & Parallelism:**
- Atomic page counter (mutex-guarded fetchAdd) eliminates contention vs work queues
- Pre-allocated results array indexed by page number: O(n) merge vs O(n²) copying  
- Each thread creates own HTTP client stack (no threading of `std.http.Client` — has non-thread-safe internal state)
- Fallback to sequential when Link header absent: conservative, safe, no blind parallelism

**HTTP Header Capture:**
- High-level `client.fetch()` doesn't expose headers; use lower-level `request()` → `receiveHead()` → `readerDecompressing()`
- Decompression is explicit responsibility when using lower-level API
- RFC 5988 Link header: multiple relations in one header, must handle missing/malformed gracefully

---

## Recent Work

### Closed Issues Feature — Architecture Review (2026-03-21)

**Status:** ✅ Approved

**Evaluation Points:**

1. **API Design** — `getClosedIssues()` correctly implements pagination. PR filtering (`pull_request == null`) prevents duplication from `/issues` endpoint. ✅

2. **Memory Safety** — All Issue fields properly duped. `errdefer` chains protect against partial allocation failures. Cleanup functions symmetric with releases/PRs. Test allocator verifies no leaks. ✅

3. **Flagged Observations (follow-up refactor):**
   - `HttpResponse.link_header: ?[]u8` exposes raw header string. Recommend wrapping with internal parser in http_client layer.
   - Result merging allocates per-page slices. Consider pre-allocation by total_pages discovered upfront (optimization).

4. **Test Coverage** — 12 new test cases by Mr. Pink. 100% coverage of `getClosedIssues()`, label filtering, markdown output. All 47 tests passing. ✅

5. **Documentation** — 4 README commits by Mr. Blonde align examples with actual behavior. ✅

**Verdict:** APPROVED — Feature ready for merge. Address HTTP response design suggestion in follow-up.

---

### Closed Issues Feature — Implementation Summary (2026-03-21)

**Team Delivery:**
- **Mr. Orange:** API, models, generator, main, markdown formatter
- **Mr. Pink:** 12 test cases, comprehensive coverage
- **Mr. Blonde:** 4 README commits, documentation alignment
- **Mr. White:** Architecture review, design feedback

**Key Design Decisions:**
- PR filtering at API boundary (not post-fetch)
- Separate `## Closed Issues` section (distinct from PR categories)
- Tag-range filtering applies same logic to closed issues
- Parallel path cleanup symmetric with releases/PRs

**Validation:**
- ✅ 47 tests passing
- ✅ Memory safety verified
- ✅ Build passing
- ✅ README in sync
