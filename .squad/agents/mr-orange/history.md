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
