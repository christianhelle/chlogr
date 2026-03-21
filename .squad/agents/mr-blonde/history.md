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

## Core Context

**Documentation & DevOps Work (Jan-Mar 2026):**
- Updated README for parallel & progress features (Features, Options, usage examples)
- Implemented PR metadata automation: `pr-squad-metadata.yml` GitHub Actions workflow
  - Auto-applies `enhancement` label to squad member PRs (detected by branch name, convention, author)
  - Auto-assigns to `christianhelle`
  - Fixed permission issue: `pull-requests: write` → `issues: write`
- One-time audit and bulk sync of 27 closed PRs to add metadata (label + assignee)
  - Used idempotent `gh pr edit --add-label` and `--add-assignee` commands
  - Documented reusable pattern for future bulk operations
  - GitHub API quirk: PR labels/assignees use `issues.*` namespace, not `pull-requests.*`

**Current Status:**
- All 27 closed PRs updated with metadata
- PR automation workflow active for new squad PRs
- README in sync with shipped features
- Build passing

## Learnings

**GitHub Workflows & PR Automation:**
- PR metadata uses `issues.*` API namespace, not `pull-requests.*` — fixes permission errors
- Bulk operations with `gh cli` are idempotent — safe for reruns and corrections
- Label definitions must exist before workflows apply them (otherwise first run fails)
- Squad member detection: branch naming patterns + convention prefixes + author

**Documentation Hygiene:**
- README must stay in sync with shipped features (new flags, changed defaults, new output)
- Update README in same PR as feature, OR in dedicated docs/ branch immediately after merge
- Keep specific sections current: Features, Options, Usage examples, Development → Running Tests
- Link new flags to their descriptions in help text

**Bulk PR Operations:**
- Audit first: list target PRs and check current metadata
- Batch update idempotently: three batches of 8-9 PRs for easier recovery
- Verify completion: re-query to confirm all PRs have updated metadata
- Document as reusable pattern for future team use

---

## Recent Work

### README Hygiene for Parallel & Progress (2026-03-19)

**Branch:** `docs/update-readme-parallel-progress`

**Changes Made:**
1. Updated Features section (added 2 bullets: progress output, parallel fetching)
2. Added `--parallel` option to Options list with description
3. Added "With Parallel Fetching" usage example
4. Updated Development → Running Tests to mention CLI argument parsing

**Commit:** 91df18f

**Result:** README updated, PR #37 created

---

### PR Metadata Automation Workflow (2026-03-20)

**File:** `.github/workflows/pr-squad-metadata.yml`

**Detection Strategy:**
1. Branch name contains squad member name (parsed from `.squad/team.md`)
2. Branch follows squad conventions: `feature/`, `fix/`, `docs/`, `chore/`, `refactor/`, `test/`
3. Author is Copilot agent (in squad roster)

**Automation:**
- Apply `enhancement` label
- Assign to `christianhelle` (project maintainer)

**Tested:** On next squad PR open/reopen

---

### PR Metadata Workflow Permission Fix (2026-03-20)

**Issue:** Workflow failed because it used `pull-requests: write` instead of `issues: write`

**Fix:**
- Changed `.github/workflows/pr-squad-metadata.yml` permission in both live and template
- Added `enhancement` label definition to `sync-squad-labels.yml` (wasn't there before)

**Key Learning:** GitHub API routes PR labels/assignees through `issues.*` namespace internally

---

### Closed PR Metadata Sync (2026-03-20)

**Task:** Audit 27 closed PRs by `christianhelle` and apply `enhancement` label + assignment

**Approach:**
1. Query: `gh pr list --state closed --author christianhelle` — found 27 PRs
2. Identify gaps: 25 PRs missing metadata, 2 already complete
3. Batch update (3 batches) using `gh pr edit --add-label enhancement --add-assignee christianhelle`
4. Verify: all 27 PRs now have label and assignee

**Key Findings:**
- `enhancement` label already existed (color `a2eeef`, description "New feature or request")
- `--add-label` and `--add-assignee` flags are idempotent (safe for reruns)
- Each `gh pr edit` is a separate API call (~54 calls for 27 PRs × 2 operations)
- GitHub handles rate limiting transparently

**Result:** ✅ All 27 closed PRs updated, baseline established for ongoing automation

---

### README Hygiene for Closed Issues Feature (2026-03-21)

**Task:** Align README examples with shipped closed issues behavior

**Problem:** README showed `--unreleased-changes` capturing both PRs *and* closed issues, but implementation keeps unreleased changes PR-only.

**Solution (4 commits):**

1. **Updated unreleased changes example** — removed closed issues from "Unreleased Changes" section
2. **Clarified `--unreleased-changes` flag** — added note: "Captures only merged pull requests since last release"
3. **Updated feature list** — reworded to clarify scope of each feature
4. **Added closed issues usage example** — showed `--closed-issues --closed-issues-labels "bug,docs"` with both sections in output

**Key Pattern:** When features interact (e.g., `--unreleased-changes` + `--closed-issues`), documentation must explicitly clarify scope and show examples combining related flags.

**Result:** README in sync with implementation
