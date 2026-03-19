# Copilot Instructions

This document is the authoritative process guide for all future AI agent tasks in the chlogr repository.

## Branching Policy

**Never commit directly to `main`.** All changes must go through a pull request.

Branch naming convention:
- **Bug fixes:** `fix/{issue-number}-{brief-slug}` — e.g., `fix/42-null-pointer-crash`
- **Features:** `feature/{issue-number}-{brief-slug}` — e.g., `feature/15-json-output`

Use the associated GitHub issue number in the branch name whenever one exists.

## Commit Hygiene

Commits must be small and logical, representing a single coherent change. Each commit message should clearly describe what changed and why.

**Rules:**
- Prefer many small commits over one large "WIP" commit
- Each commit should pass tests independently (when possible)
- Commit messages must be clear and descriptive: no "fixed stuff" or "updates"
- This creates detailed progress history that makes code review easier and history more useful

**Format:** Use conventional commit style:
- `chore: ...` — build, tooling, dependencies
- `fix: ...` — bug fixes
- `feat: ...` — new features
- `refactor: ...` — code cleanup
- `docs: ...` — documentation
- `test: ...` — tests only

Example: `fix: handle nil pointer when parsing empty tags`

## Build Gate

**Before opening a PR, run:**
```
zig build
```

The build must pass. No exceptions.

## Test Gate

**Before opening a PR, run:**
```
zig build test
```

All tests must pass. No exceptions.

## PR Workflow

1. **Create a feature branch** — Follow the branching policy above
2. **Make small, logical commits** — Follow commit hygiene rules
3. **Ensure build and tests pass locally** — Run `zig build` and `zig build test`
4. **Push to origin** — Create the PR on GitHub
5. **Reference the issue** — Use `Closes #N` in the PR description to link the issue
6. **Wait for review** — PRs must be reviewed and approved before merging
7. **Merge and delete branch** — Clean up after merge

**PR Template:**
```
Closes #N

## What
Brief summary of what this PR does.

## Why
Explain the motivation and context for the change.

## How
Describe the approach and implementation.
```

## No Force-Pushing to Main

**Never force-push to the main branch.** The main branch history is sacred and used for releases.

If you need to fix something on main:
1. Create a new branch from main
2. Make the fix
3. Open a PR
4. Merge normally

## README Hygiene

**Keep README.md in sync with the feature set at all times.**

When implementing any change that affects user-facing behaviour — new CLI flags, changed defaults, new output, removed features, updated options — the README **must** be updated in the same PR or a dedicated follow-up PR before closing the issue.

### What triggers a README update

- New CLI flag or option added or removed
- Changed default values or behaviour
- New usage examples or modes
- New features listed in the Features section
- Changed output format or file names
- Updated build or test requirements

### How to update the README

1. Edit `README.md` in the same branch as the feature change, OR
2. Open a separate `docs/` branch immediately after the feature PR merges

Either is acceptable. What is NOT acceptable: closing an issue or merging a feature PR while README is out of sync.

### README sections to keep current

- **Features** — bullet list of what the tool does
- **Options** — every CLI flag with description and default
- **Usage examples** — at least one example per major flag or mode
- **Development → Running Tests** — reflects what the test suite actually covers

## Summary

- **Branch:** `fix/{N}-{slug}` or `feature/{N}-{slug}`
- **Commit:** Small, logical, well-described
- **Build:** `zig build` must pass
- **Test:** `zig build test` must pass
- **PR:** Always via pull request, reference issues, wait for approval
- **Main:** Never force-push, never direct commits
- **README:** Update README.md for any user-facing feature change
