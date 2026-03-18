# Mr. Orange — History

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

## Learnings

### Issue #7 — GitHub API pagination for releases and merged PRs (PR #21)

**Approach used:**
Both `getReleases` and `getMergedPullRequests` were converted from single-request functions to pagination loops. Each iteration appends `?page=N&per_page=100` to the endpoint URL, copies items into a persistent `ArrayList`, and breaks when the page returns fewer items than `per_page` (signalling the last page). The `per_page` parameter was removed from both public function signatures — callers no longer need to manage limits.

**Key decisions:**
- `initCapacity(allocator, 0)` is the correct idiom for an empty `ArrayList` in Zig 0.15.2 (`.init(allocator)` does not exist).
- `append(allocator, item)` must be used inside the loop (not `appendAssumeCapacity`) because capacity may need to grow.
- `errdefer` on the outer `ArrayList` covers partial accumulation across pages — if any page fetch, parse, or copy fails, all previously copied items are freed correctly.
- URL strings built with `std.fmt.allocPrint` are freed via `defer` immediately after the HTTP call, keeping per-page memory transient.
- `toOwnedSlice(allocator)` is called once at the end to transfer ownership to the caller.
