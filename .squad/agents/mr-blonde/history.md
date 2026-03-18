# Mr. Blonde — History

## Project Context

**Project:** chlogr  
**Description:** A fast, efficient, native CLI tool to automatically generate changelogs from GitHub tags, pull requests, and issues. Written in Zig v0.15.2.  
**User:** Christian Helle  
**Stack:** Pure Zig stdlib, zero runtime dependencies. CLI binary targeting multiple platforms.  
**Build:** `zig build` | Tests: `zig build test`

## Release Files

```
build.zig          # Zig build system
install.ps1        # Windows install script
install.sh         # Unix/macOS install script
snapcraft.yaml     # Snap package configuration
.github/           # CI/CD workflows
```

## Build Notes

- `zig build` — produces binary at `zig-out/bin/chlogr`
- `zig build test` — runs integration tests
- Cross-platform targets: Windows, Linux, macOS

## Learnings
