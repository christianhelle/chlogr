# Squad Decisions

## Active Decisions

### 1. Issue Priority Tiers (P0–P3)

**Status:** Approved  
**Owner:** Keaton  
**Date:** 2026-03-18

**Decision:**
- **P0 (Safety-Critical):** Issues #3, #4 — block all P1+ work. Hard dependency.
- **P1 (Correctness):** Issues #5–#7, #9 — core product issues. Sequence: #6 → #5 → #7.
- **P2 (Features):** Issue #10 — markdown formatting improvements.
- **P3 (Optimization):** Issue #11 — defer until P0–P2 complete; profile first.

**Rationale:** P0 must complete before P1 testing is reliable due to allocator safety issues and process-edge-case bugs. No parallelization possible; all sequential.

---

### 2. Team Routing & Issue Ownership

**Status:** Approved  
**Owner:** Keaton  
**Date:** 2026-03-18

**Decision:**
- **Fenster (CLI Dev):** #3, #4 (P0); #6, #9 (P1 alloc/parsing)
- **McManus (DevRel):** #5 (semantics), #8 (scope gate)
- **Hockney (Tester):** #7 (pagination), extended test suite
- **Scribe (Logger):** #10 (markdown formatter)
- **Ralph (Monitor):** #11 (post-P1 optimization)

**Rationale:** Ownership aligns with domain expertise: CLI dev owns safety/memory, DevRel defines product semantics, Testers validate correctness at scale, Logger handles presentation.

---

### 3. Issue #5: Release Assignment Window Semantics

**Status:** Decision Pending  
**Owner:** McManus  
**Due:** 2026-03-18 EOD

**Question:** Does a PR belong to `release[i]` if `release[i].published_at <= merged_at < release[i-1].published_at`?

**Current State:** Lossy truncation to YYYY-MM-DD; no explicit lower bound; PR can qualify for multiple releases

**Recommendation:** Option B (Exclusive Lower Bound)
```
PR belongs to release[i] if: release[i].published_at < merged_at < release[i-1].published_at
PRs where merged_at == published_at go to "Unreleased"
```

**Rationale:** Cleaner semantics—a PR cannot belong to a release if merged exactly when released (causal impossibility). Document explicitly.

**What Needs to Change:**
1. **changelog_generator.zig:** Replace date-only `parseDateToSlice()` with full ISO-8601 comparison
2. **README.md:** Add "Release Assignment Algorithm" section explaining the decision
3. **Tests:** Add cases for same-day multiple releases with edge timestamps

**Impact:** Affects #5 implementation, #7 pagination test design, #8 filtering logic

---

### 4. Issue #8: `--since-tag` / `--until-tag` Scope Gate

**Status:** Decision Pending  
**Owner:** McManus  
**Due:** 2026-03-18 EOD

**Current State:** Flags parsed but never used; README documents as working (false expectation)

**Options:**

**Option 1: Implement Full Filtering** (~8h)
- Pros: Feature-complete; valuable for large changelogs
- Cons: Timeline risk; depends on #5; affects roadmap
- **Recommendation:** Post-P1. File as sub-issue for future sprint.

**Option 2: Reject with Error** (~1h)
- Pros: Honest; prevents silent failures; clear message to users
- Cons: Breaks backward compatibility (advertised in README)
- **Recommendation:** ✅ Best choice for P1. Add validation in CLI parser.

**Option 3: Remove Entirely** (~30m)
- Pros: Simplest scope
- Cons: Harsh UX; breaks user scripts
- **Recommendation:** Not recommended. Better to reject gracefully.

**Recommended Action:** Option 2 (Reject with "Not Yet Implemented" error)
- Add validation in `cli.zig` to detect flags and return clear error message
- Update README to remove false documentation
- Add new "Planned Features" section linking to Issue #8

---

### 5. Issue #10: Release Link Formatting

**Status:** Approved (Design)  
**Owner:** Scribe  
**Effort:** 2h  

**Decision:** Pass repository slug to `MarkdownFormatter` at initialization

**Current Problem:** Release links hardcoded to `https://github.com/owner/repo/releases/tag/{tag}` — breaks for all users

**Solution:**
- Add `repo_slug: []const u8` parameter to `MarkdownFormatter.init()`
- Update release link format string to use `self.repo_slug` instead of placeholder
- Pass `parsed_args.repo.?` from `main.zig` to formatter

**Acceptance Criteria:**
- Release links include actual repo slug
- README example shows correct links (e.g., `github/cli` not `owner/repo`)
- No hardcoded placeholders in generated markdown

---

### 6. Allocator Cleanup Pattern (Post-#6 Rule)

**Status:** Pending Approval (after #6 merged)  
**Owner:** Fenster  
**Target:** 2026-03-25

**Decision:**
After #6 (allocation-failure cleanup) is complete:
1. Establish team rule: All partial-initialization error paths use `errdefer` for rollback
2. Ban `catch continue` in error-prone paths; use `try` or explicit error enum
3. Add linting check (manual or automated) on all new `allocator.dupe()` calls

**Rationale:** P0 and P1 fixes revealed inconsistent error handling. Codify best practice to prevent regressions.

---

### 7. Token Resolution Resilience (Post-#4 Rule)

**Status:** Pending Approval (after #4 merged)  
**Owner:** Fenster  
**Target:** 2026-03-25

**Decision Required:**
1. Should `gh auth token` call timeout after N seconds? (Recommend: 5s)
2. Should we retry on transient failure? (Recommend: No, fail fast)
3. Document fallback order in README

**Rationale:** #4 fix prevents hangs, but edge case still possible if gh exits abnormally or stderr fills. Document the contract explicitly.

---

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
