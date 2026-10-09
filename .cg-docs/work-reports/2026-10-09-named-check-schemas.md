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
| C1 | all | passed | Read-only discovery only; no data writes |
| C2 | all | passed | Proposed checks are content-based, not date-based |
| C3 | all | passed | Proposal uses named checks, not inventory matching |
| C4 | all | passed | Discovery note contains no evaluator schema hardcoding |
| C5 | all | pending | Not in phase scope |
| C6 | all | passed | No tests run against `Y:/`; only metadata probes |
| C7 | all | pending | Not in phase scope |

### Decisions
- Reused evidence from `pipapi` `create_lkups.R` for lineup-path artifacts.
- Confirmed 19 PROD folders in `Y:/temp/povertyscore-data`.
- Proposed separating check bundle based on four lineup markers and one format check.

### Remaining uncertainty
- User approval is required for the proposed check set and schema IDs before Step 3 may write `inst/schemas/definitions.yml`.

### Final status
- `active` (phase 1 complete; awaiting continue/stop decision for phase 2)
