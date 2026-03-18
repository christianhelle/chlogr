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
