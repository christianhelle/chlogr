# McManus — History

## Project Context (Day 1)

**Project:** chlogr — Zig CLI tool for GitHub release changelog generation  
**Language:** Zig v0.15.2  
**User:** Christian Helle  
**Date Initialized:** 2026-03-18  

**What we're building:** A command-line tool that ingests GitHub repository data (releases, merged PRs, closed issues) and generates structured changelogs. Users can filter by release, date range, and category.

**Team:** Keaton (Lead), Fenster (CLI Dev), Hockney (Tester), McManus (DevRel), Scribe (Logger), Ralph (Monitor)

**Documentation anchors:**
- README.md — main entry point
- docs/ — extended guides (if any)
- install.sh / install.ps1 — installation instructions (check these)
- GitHub releases page — where users discover the tool

## Learnings

### Issue #5: Timestamp Precision & Release Assignment (2026-03-18)
- **Discovered:** Timestamps truncated to date-only (`YYYY-MM-DD`); full ISO-8601 discarded at `'T'`
- **Risk:** Same-day releases and multi-release merges produce duplicates or lost data
- **Scope decision required:** PR inclusion boundary (inclusive vs. exclusive on release.published_at)
- **User-facing doc needed:** "Release Assignment Algorithm" section explaining window semantics
- **Pattern:** When filtering/sorting by date, always use full precision; document edge cases explicitly

### Issue #8: Unimplemented Flags (2026-03-18)
- **Discovered:** `--since-tag` and `--until-tag` parsed but never used; silently ignored
- **False expectation:** README documents them as working; misleading help text
- **Scope decision required:** Implement full filtering, reject with error, or remove entirely
- **Recommendation:** Reject with "not yet implemented" error; file sub-issue for post-P1 work
- **Pattern:** Flag parsing ≠ flag implementation. Consider linting to catch dangling code paths.

### Issue #10: Broken Release Links (2026-03-18)
- **Discovered:** Release links hardcoded to `github.com/owner/repo/releases/tag/{tag}`
- **Impact:** User-visible broken links in generated markdown—immediately obvious failure
- **Fix:** Pass repo slug to MarkdownFormatter at init time; update README examples
- **Pattern:** Never hardcode placeholders in user-facing output. Test with real data early.

### Documentation Patterns Established (2026-03-18)
- **Timestamp semantics:** Document full ISO-8601 comparison explicitly; explain why precision matters
- **Feature completeness:** If README documents a flag, the behavior must be end-to-end wired
- **Release notes:** Always include "Planned Features" section to set expectations and link to issues
- **Code comments:** Flag architectural decisions (especially boundary conditions) so future maintainers understand trade-offs
- **README structure:** Add sections for algorithms, planned features, and architecture decisions—not just quick-start

### Team Coordination
- **Keaton's routing:** McManus handles scope decisions & correctness semantics; owns user expectations
- **Blocking work:** #5 and #8 require product-level decisions before coding can begin
- **Documentation-first:** Spec out the algorithm (timestamps, boundaries) before implementation

---

## Sprint 1 (P1 Scope & Semantics — Assigned 2026-03-18)

**Assigned Issues:** #5 (release assignment semantics), #8 (scope gate: since/until tags)

**Immediate Decisions (Due EOD 2026-03-18):**

### 1. Release Assignment Window Semantics (#5)

**Question:** Does a PR belong to `release[i]` if `release[i].published_at <= merged_at < release[i-1].published_at`?

**Current State:** Lossy truncation to YYYY-MM-DD; no explicit lower bound; PR can qualify for multiple releases

**Decision Needed:**
- Define the closed interval: Should lower bound be `release[i].published_at` or something else?
- Should comparison use full timestamps or just dates?
- What about unreleased PRs (merged after latest release)?

**Impact on Other Issues:**
- #5 implementation depends on this decision
- #7 pagination test cases depend on this decision
- #8 `--since-tag` / `--until-tag` filtering depends on this decision

**Recommendation:** Closed interval semantics: PR belongs to release if `release[i].published_at <= merged_at < release[i+1].published_at`. Unreleased PRs have `release[i+1].published_at = infinity` (current time or max timestamp).

### 2. Scope Gate: `--since-tag` / `--until-tag` (#8)

**Question:** Implement or reject the `--since-tag` / `--until-tag` flags?

**Current State:** Advertised in help/parser but not implemented; treated as silent no-op

**Options:**
- **Implement:** Full end-to-end filtering by release range; add to #5 sequence; 3–4h additional effort
- **Reject:** Remove from parser/help; close issue; document that feature is not supported

**Trade-offs:**
- Implement: increases scope; must coordinate with #5 semantics; but provides user value
- Reject: reduces scope creep; limits feature set; but simpler codebase

**Recommendation (pending):** Decide within 1 hour of sprint start. Document decision in RFC.

**P1 Sprint (after decisions above):**
1. Write RFC for #5 window semantics + test cases for same-day merges, multi-release scenarios
2. If #8 approved: refactor release filtering logic to include date-range check
3. Hand off to Fenster for implementation
4. Validate correctness with Hockney extended test suite

**Unblocks:** Fenster (#5 implementation), Hockney (test case design), roadmap validation
