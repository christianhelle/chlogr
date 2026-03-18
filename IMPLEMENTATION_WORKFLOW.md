# Implementation Workflow & Commit Strategy

**Date:** 2026-03-18  
**Status:** P0 fixes committed. P1 implementation ready.

---

## Summary

The chlogr team has completed P0 memory-safety fixes and created a comprehensive test suite. All work is now tracked on the **`fix/p0-memory-safety`** feature branch with 5 logical commits:

### Commit History

| Commit | Message | Impact |
|--------|---------|--------|
| `8cc94f2` | Fix #3: Safe ArrayList initialization | Memory-safety regression fix |
| `6c86b71` | Fix #4: Harden gh token resolution | Process-safety regression fix |
| `6c581d2` | Add comprehensive test suite for P0/P1 | 27 new tests, full coverage |
| `062ba4e` | Squad: P0 investigation & planning | Team state & decisions |
| `6e199b0` | Squad: Add copilot instructions | P1 implementation guide |

**All commits:**
- Reference the issues they fix
- Include small, logical changes (not monolithic)
- Pass all 27 tests
- Are ready to merge after review

---

## Branching & Commit Strategy (ENFORCED)

### Git Pre-Commit Hook
A pre-commit hook is installed in `.git/hooks/pre-commit` that **prevents commits to main**. Any attempt to commit directly to main will be rejected:

```
❌ ERROR: You are on the main branch.

Squad policy: NEVER commit to main. Create a feature branch:
  - Bug fixes:   git checkout -b fix/{issue-number}-{slug}
  - Features:    git checkout -b feature/{slug}
  - Refactors:   git checkout -b refactor/{slug}
```

### Workflow

For **every issue**, follow this pattern:

```bash
# Step 1: Create a feature branch (never commit to main)
git checkout -b fix/7-pagination-support

# Step 2: Make changes, commit in small logical groups
git add src/github_api.zig build.zig
git commit -m "Fix #7: Implement pagination for releases

Add support for fetching multiple pages of releases via GitHub API Link
headers. Parse rel="next" from HTTP response headers to walk pagination.

- Modify HttpResponse to capture response headers
- Implement loop to fetch all pages
- Add test coverage for multi-page scenarios
- Update documentation with pagination support claim

Tests: All 27 passing

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"

# Step 3: Test thoroughly
zig build test-all  # Must pass

# Step 4: Push and create PR
git push -u origin fix/7-pagination-support
# Then create PR on GitHub for review
```

### Commit Message Format

```
{Fix|Issue} #{number}: {Brief description}

{Detailed explanation of what was changed and why}

{List of changes with bullets}
- Change 1
- Change 2

Tests: All {N} passing

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

---

## P1 Implementation Queue

The team is ready to implement P1 issues in parallel, each on its own feature branch:

| Issue | Branch Name | Priority | Owner | Status |
|-------|-------------|----------|-------|--------|
| #7 | `fix/7-pagination-support` | 1 | Fenster | Ready |
| #5 | `fix/5-release-assignment-semantics` | 2 | Fenster | Ready |
| #6 | `fix/6-api-deep-copy-cleanup` | 3 | Fenster | Ready |
| #9 | `fix/9-label-exclusion-exact-match` | 4 | Fenster | Ready |
| #8 | `fix/8-tag-filter-rejection` | 5 | Fenster | Ready |
| #10 | `fix/10-release-link-rendering` | 6 | Fenster | Ready |

Each issue:
- Has test coverage already written (`src/test_*.zig`)
- Can be worked on independently
- Must be committed to a separate feature branch
- Should be small enough to review in one PR

---

## Copilot Instructions

Comprehensive implementation guide available at:
**.squad/agents/copilot/copilot-instructions.md**

Contains:
- Architecture overview
- Zig 0.15.2 patterns and safety rules
- Known issues with detailed solutions
- Testing strategy
- Common pitfalls and GitHub API quirks
- Squad context and team roles

---

## Next Steps

1. **Review & merge P0 branch**
   - PR: https://github.com/christianhelle/chlogr/pull/new/fix/p0-memory-safety
   - All 27 tests passing
   - Ready for review

2. **Begin P1 implementation**
   - Start with Issue #7 (pagination) — highest impact
   - Create branch: `git checkout -b fix/7-pagination-support`
   - Reference `src/test_pagination.zig` for expected behavior
   - Commit in logical groups
   - Push and create PR for review

3. **Parallel work**
   - Multiple issues can be worked on simultaneously
   - Each on its own feature branch
   - No merge conflicts due to branch isolation
   - Scribe will sync squad state across branches

---

## Enforcement

**Pre-commit hook prevents:**
- ❌ Committing directly to main
- ❌ Bypassing feature branch requirement

**Copilot instructions require:**
- ✅ Feature branch for every issue
- ✅ Small logical commits (not monolithic)
- ✅ Issue reference in commit messages
- ✅ All tests passing before push
- ✅ Co-author trailer on every commit

---

## Testing Checklist

Before pushing any changes:

```bash
# Run all tests
zig build test-all

# Verify specific test suites relevant to your fix
zig build test-allocator      # If fixing memory issues
zig build test-pagination     # If fixing pagination
zig build test-timestamps     # If fixing release assignment
zig build test-labels         # If fixing label parsing
zig build test-token          # If fixing token resolution

# Check git status
git status

# Verify pre-commit hook works (try committing to main)
git checkout main && git commit --allow-empty -m "test" 
# Should fail with branching error
```

---

## Squad State

All team learnings, decisions, and orchestration logs are in `.squad/`:
- `.squad/decisions.md` — Architectural decisions
- `.squad/agents/*/history.md` — Per-agent learnings
- `.squad/orchestration-log/` — Session records
- `.squad/agents/copilot/copilot-instructions.md` — Implementation guide

For questions on **why** a decision was made, check the decision files. For questions on **how** to implement, check copilot instructions and existing code patterns.
