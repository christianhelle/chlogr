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

---

## Session: PR Metadata Automation

**Date:** 2026-03-20
**Task:** Configure automatic labeling and assignment for squad member PRs

### Work Completed

**Files Created:**
1. `.github/workflows/pr-squad-metadata.yml` — Active workflow
2. `.squad/templates/workflows/pr-squad-metadata.yml` — Template for future reference

**Files Updated:**
1. `.github/copilot-instructions.md` — Added PR Automation section
2. `.squad/templates/copilot-instructions.md` — Added PR automation notes for Copilot agent

### Automation Logic

The new workflow (`pr-squad-metadata.yml`) triggers on `pull_request` events (opened, reopened) and:

1. **Detects squad member PRs** by checking:
   - Branch name contains a squad member name (parsed from `.squad/team.md`)
   - Branch follows squad convention (`feature/`, `fix/`, `docs/`, `chore/`, `refactor/`, `test/`)
   - Author is Copilot agent (`copilot-swe-agent[bot]`, etc.)

2. **Applies automation:**
   - Adds `enhancement` label
   - Assigns to `christianhelle`

3. **Respects non-squad PRs** — skips automation for external contributors

### Key Design Decisions

- **Squad detection via multiple signals** — not just branch name, also includes convention-based detection for `feature/`, `fix/`, etc.
- **Graceful degradation** — warnings instead of failures if label/assignment fails
- **Team-aware** — parses `.squad/team.md` to know who squad members are
- **Copilot-aware** — recognizes Copilot agent PRs when `@copilot` is on the team roster

### Documentation Updates

- **copilot-instructions.md** — PR Workflow section now explains that squad PRs automatically get labeled and assigned
- **Template version** — Both workflow and copilot-instructions template updated for consistency

### Next Steps for Other Repos

This pattern can be reused in other squad-enabled repos:
1. Copy `pr-squad-metadata.yml` to `.github/workflows/`
2. Update assignee from `christianhelle` to the target maintainer username
3. Optionally customize label (currently hardcoded to `enhancement`)

**Status:** ✅ Complete and ready for testing on next PR

---

## Session: PR Metadata Workflow Permissions Fix

**Date:** 2026-03-20
**Task:** Fix permissions and label dependencies in PR automation workflows

### Problem Identified

The initial PR metadata workflow had two issues:
1. **Wrong permissions** — Used `pull-requests: write` but called `issues.*` APIs (GitHub treats PR labels/assignees as issues API)
2. **Missing label definition** — PR workflow depends on `enhancement` label, but label sync workflow didn't define it

### Fixes Applied

**File: `.github/workflows/pr-squad-metadata.yml`**
- Changed permission from `pull-requests: write` to `issues: write`
- This allows `issues.addLabels()` and `issues.addAssignees()` to work correctly

**File: `.squad/templates/workflows/pr-squad-metadata.yml`**
- Applied same permission fix to template for consistency

**Files: `.github/workflows/sync-squad-labels.yml` + template**
- Added `enhancement` label to `SIGNAL_LABELS` array
- Color: `A2EEEF` (GitHub standard enhancement color)
- Description: "New feature or improvement"
- Ensures the label exists before PR workflow tries to apply it

### Architectural Note

**GitHub API quirk:** Pull request labels/assignees use the `issues.*` API namespace, not `pull_requests.*`. This is because GitHub internally models PRs as a specialized type of issue.

**Permission requirements:**
- `issues: write` — Required for label and assignee operations on PRs
- `pull-requests: write` — Only required for PR-specific fields (merge, review requests, etc.)

**Label lifecycle:**
1. `sync-squad-labels.yml` defines and creates canonical labels (runs on team.md changes + manual dispatch)
2. `pr-squad-metadata.yml` applies labels to squad PRs (runs on PR open/reopen)
3. Label sync acts as "source of truth" — PR workflow is a consumer

### Learnings

- **GitHub Actions permissions are namespace-specific** — always check which API namespace your script calls
- **Label dependencies must be explicit** — if a workflow applies a label, another workflow must define it
- **Templates and active files must stay in sync** — changes to `.github/` must be mirrored in `.squad/templates/`

**Status:** ✅ Fixed — workflow now has correct permissions and label is properly defined

---

## Session: Trailing Whitespace Cleanup

**Date:** 2026-03-20
**Task:** Remove trailing whitespace from history.md

### Work Completed

Removed trailing spaces from lines 5-8 in the Project Context section. Four lines had trailing double-spaces after markdown text that needed cleanup.

### Learnings

- **Keep markdown clean** — trailing whitespace in markdown files can cause diff noise and linting issues
- **Surgical edits** — when fixing formatting issues, preserve all content and only touch the specific formatting problem
- **History maintenance** — squad agent history files should follow same hygiene rules as codebase (clean commits, no trailing whitespace)

---

## Session: Trailing Whitespace Git Check Fix

**Date:** 2026-03-20
**Task:** Remove trailing spaces from two `**Date:** 2026-03-20` lines

### Work Completed

Fixed lines 67 and 120 in `history.md` which had trailing double-spaces after the date field. This was causing potential issues with `git diff --check`.

### Learnings

- **Pre-commit hygiene** — `git diff --check` catches trailing whitespace that can slip into history files
- **Two-space markdown linebreak trap** — Markdown uses two trailing spaces for explicit line breaks, but these should be intentional, not accidental
- **Edit tool precision** — Used targeted edits to fix only the problematic lines without touching surrounding context

---

## Session: PR Metadata Automation Batches 1–3

**Date:** 2026-03-20
**Tasks:** Implement PR automation, fix permissions, clean history

### Batch 1: Created PR Metadata Workflow
- Built GitHub Actions workflow to auto-label and auto-assign squad PRs
- Detects squad authorship via branch names, conventions, and Copilot agent detection
- Uses dynamic roster parsing from `.squad/team.md`
- Created both active workflow and template version

### Batch 2: Fixed Permission and Label Issues
- **Permission bug:** Workflow used `pull-requests: write` but needed `issues: write`
  - Root cause: GitHub models PR labels/assignees under `issues.*` namespace, not `pull-requests.*`
- **Label dependency:** Added missing `enhancement` label to sync workflow
  - Prevents failure when label doesn't exist on first run
- Applied fixes to both active workflows and templates

### Batch 3: Trailing Whitespace Cleanup
- Removed trailing spaces that could trigger `git diff --check` failures
- Maintained all content, fixed formatting only

### Key Learnings

- **GitHub API namespace quirk** — Most PR automation needs `issues: write`, not `pull-requests: write`. PR labels/assignees are managed through issues API.
- **Label lifecycle** — If a workflow applies a label, another workflow must define it. Explicit label definitions prevent race conditions.
- **Template-code sync** — Changes to active `.github/` files must be mirrored in `.squad/templates/` for consistency and reusability.
- **Squad detection is multi-signal** — Branch names alone aren't enough. Combine with convention-based detection and Copilot agent awareness.
- **Graceful degradation** — Non-squad PRs should be skipped silently, not fail the workflow.
