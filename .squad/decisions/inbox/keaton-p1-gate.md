# P1 Work Gate — OPEN

**Status:** ✅ P0 merged to main. P1 implementation may proceed.  
**Lead:** Keaton  
**Date:** 2026-03-18  

## Gate Decision

**P0 COMPLETE** — All safety-critical fixes (#3, #4) merged to main with full test coverage.

**P1 CLEARED FOR LAUNCH** — All P1 issues may now proceed in parallel where appropriate.

## P1 Issues Ready for Implementation

### High Priority (Core Correctness)

**#5: Release Assignment Semantics** (McManus)  
- Replace date truncation with full ISO-8601 timestamp comparison
- Define exclusive lower bound for release windows
- Impact: Affects #7, #8 test design
- **Dependencies:** None — can start immediately

**#6: API Allocation Cleanup** (Fenster)  
- Add `errdefer` to partial-initialization paths in github_api.zig
- Fix allocation leaks on error in deep-copy loops
- **Dependencies:** None — can start immediately

**#7: Pagination Support** (Hockney)  
- Add multi-page fetching for releases and PRs
- Handle Link header parsing for next/prev pages
- **Dependencies:** None for basic implementation; #5 for correct test cases

**#9: Label Exclusion CSV Parsing** (Fenster)  
- Replace substring matching with proper CSV tokenization
- Trim whitespace, handle empty tokens
- **Dependencies:** None — can start immediately

### Medium Priority (Product Scope)

**#8: Tag Filter Rejection** (McManus)  
- Add validation to reject `--since-tag` / `--until-tag` with clear error
- Update README to remove false documentation
- **Dependencies:** None — can start immediately

### Lower Priority (Presentation)

**#10: Release Link Formatting** (Scribe)  
- Pass repository slug to MarkdownFormatter
- Use actual repo in release links instead of "owner/repo"
- **Dependencies:** None — can start immediately

## Recommended Sequencing

**Phase 1 (Parallel):**
- McManus: #5 + #8 (semantic decisions, ~6h combined)
- Fenster: #6 + #9 (allocation cleanup + parsing, ~8h combined)
- Scribe: #10 (formatter fix, ~2h)

**Phase 2 (After #5):**
- Hockney: #7 with correct timestamp-based test cases (~12h)

**Rationale:** #7 tests should use the corrected timestamp semantics from #5 to avoid rework.

## Success Criteria

**P1 Complete When:**
- All 6 issues (#5–#10) merged to main
- Full test suite passing
- No P1 regressions introduced
- Documentation updated (README, test suite docs)

## Next Action

**Fenster:** Launch parallel branches for #6 and #9  
**McManus:** Launch parallel branches for #5 and #8  
**Scribe:** Launch branch for #10  
**Hockney:** Begin #7 after #5 completes, or start pagination infrastructure now  
**Ralph:** Monitor progress, prepare for P3 profiling post-P1

---

**Gate Opened:** 2026-03-18  
**P0 Baseline:** main branch, all tests passing
