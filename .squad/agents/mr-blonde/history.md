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

---

## Session: README Update for Parallel & Progress Features

**Date:** Current session  
**Task:** Document recently shipped features in README.md via PR

### Work Completed

**Branch:** `docs/update-readme-parallel-progress`  
**PR:** #37 (created successfully)

**Changes Made:**
1. Updated Features section (added 2 new bullets about progress output and parallel fetching)
2. Added `--parallel` option to Options list
3. Added "With Parallel Fetching" usage example
4. Updated Development → Running Tests section to mention CLI argument parsing tests

**Commits:**
- `docs: update README with --parallel flag and progress output` (91df18f)

**Key Notes:**
- All edits completed successfully
- Changed Files: README.md (1 file, 12 insertions)
- Branch pushed to origin via gh CLI (HTTPS to avoid SSH/1Password hangs)
- PR created and linked to issue tracking

## Post-Sprint: PR #37 Merged to Main

**Date:** 2026-03-19  
**Status:** ✅ MERGED (squash merge)

README documentation for `--parallel` feature now live on main. Documentation series complete alongside feature series (#27–#31).
