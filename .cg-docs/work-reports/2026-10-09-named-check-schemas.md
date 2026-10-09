---
date: 2026-10-09
plan: ".cg-docs/plans/2026-10-09-named-check-schemas.md"
plan-title: "Named-check schemas: definitions, evaluator and assignment file"
active-deviation-policy: "ask"
status: "active"
---

# Work Report: named-check schemas

## Run 1 (2026-10-09)

### Scope
- Command: `/cg-work phase 1`
- Phase target: 1
- Plan validation: passed (`cg-render-artifact --validate-only`)

### Completed steps/phases
- Step 1 (Propose the checks) -- completed
- Phase 1 -- completed

### Evidence table
| ID | Phase | Required | Status | Evidence |
|----|-------|----------|--------|----------|
| V1 | 1 | yes | passed | `.cg-docs/plans/2026-10-09-named-check-discovery.md` |
| V2 | 2 | yes | pending | Not in phase scope |
| V3 | 2 | yes | pending | Not in phase scope |
| V4 | 3 | yes | pending | Not in phase scope |
| V5 | 3 | yes | pending | Not in phase scope |
| V6 | final | yes | pending | Not in phase scope |
| V7 | final | yes | pending | Not in phase scope |

### Constraints check (phase scope)
| ID | Phase | Status | Notes |
|----|-------|--------|-------|
| C1 | all | passed | Discovery step remained read-only on data |
| C2 | all | passed | Proposed checks use file/dir evidence, not date |
| C3 | all | passed | Named-check matching proposed; no inventory logic |
| C4 | all | passed | No evaluator hardcoding introduced in phase 1 |
| C5 | all | pending | Not in phase scope |
| C6 | all | passed | Tests did not touch `Y:/`; only metadata probes |
| C7 | all | pending | Not in phase scope |

### Decisions
- Approved by user: schema IDs `pre-lineup`/`new-lineup`, 5-check new-lineup bundle, 4-check pre-lineup absence bundle.
- Approved by user: `dir_extension` means all files under `lineup_data/` are `.fst`, directory non-empty, non-recursive.
- Confirmed split: 13 `pre-lineup` and 6 `new-lineup` across 19 folders.

### Test/evidence runs this session
- `devtools::test(filter='helper-vintage|definitions|checks|classify')` -- PASS (27)
- `devtools::test()` full suite gate -- PASS (27)

### Remaining uncertainty
- None for phase 1. Phase 2 implementation is complete and ready for phase boundary handoff.

### Final status
- `active` (phase 2 complete; awaiting continue/stop decision for phase 3)
