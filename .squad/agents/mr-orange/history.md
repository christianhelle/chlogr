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
### Issue #8 — --since-tag / --until-tag filtering (PR #18)

**Approach used:**  
Tag filtering is implemented as a pre-processing step inside `ChangelogGenerator.generate()` via a new private method `filterReleasesByTagRange`. The method scans the releases slice (assumed newest-first, matching GitHub API ordering) to find the index positions of the requested tags, then returns a sub-slice covering the inclusive range. With only `since_tag`, it returns from that index to the end of the slice (older releases); with only `until_tag`, it returns from the start to that index. With both, it uses `min`/`max` of the two indices to produce the correct window regardless of which index is lower.

**Key decisions:**
- Fields `since_tag` and `until_tag` were added with `null` defaults to `ChangelogGenerator` so no existing `init(allocator, exclude_labels)` call sites needed changing.
- Callers set them directly after `init`: `gen.since_tag = parsed_args.since_tag;`
- Unknown tags return typed errors (`SinceTagNotFound` / `UntilTagNotFound`) rather than silent empty results; `main.zig` prints a clear diagnostic before propagating the error.
- The filter returns a slice of the original releases array — no allocation required.
