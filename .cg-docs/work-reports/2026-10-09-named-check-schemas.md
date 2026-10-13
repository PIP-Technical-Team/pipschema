---
date: 2026-10-09
plan: ".cg-docs/plans/2026-10-09-named-check-schemas.md"
plan-title: "Named-check schemas: definitions, evaluator and assignment file"
active-deviation-policy: "ask"
status: "completed"
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

## Run 2 (2026-10-09)

### Scope
- Command: `/cg-work proceed with phase 3`
- Phase target: 3
- Plan validation: passed (`cg-render-artifact --validate-only`)

### Completed steps/phases
- Step 6 (`assign_schemas` writer/orchestrator) -- completed
- Step 7 (documentation updates) -- completed
- Step 8 (manual read-only run notes) -- completed
- Phase 3 -- completed

### Evidence table
| ID | Phase | Required | Status | Evidence |
|----|-------|----------|--------|----------|
| V1 | 1 | yes | passed | `.cg-docs/plans/2026-10-09-named-check-discovery.md` |
| V2 | 2 | yes | passed | `devtools::test()` (loader/check tests) |
| V3 | 2 | yes | passed | `tests/testthat/test-classify.R` third-schema test |
| V4 | 3 | yes | passed | `tests/testthat/test-assign.R` unmatched/ambiguous/unevaluable no-write assertions |
| V5 | 3 | yes | passed | `tests/testthat/test-assign.R` byte-identical repeated output assertion |
| V6 | final | yes | passed | `.cg-docs/plans/2026-10-09-named-check-run-notes.md` |
| V7 | final | yes | passed | `devtools::check(document = FALSE, vignettes = FALSE, error_on = 'warning')` (0 errors, 0 warnings) |

### Constraints check
| ID | Phase | Status | Notes |
|----|-------|--------|-------|
| C1 | all | passed | mtime preservation tests for classify and failed assign; manual run wrote output outside data root |
| C2 | all | passed | no folder-date rule in classifier/assigner |
| C3 | all | passed | named-check behavior retained; extra-file tolerance tested |
| C4 | all | passed | evaluator/check catalog has no schema-id hardcoding |
| C5 | all | passed | failed assign cases verify no output file written |
| C6 | all | passed | automated tests use synthetic trees only |
| C7 | all | passed | only new Imports dependency is `yaml` |

### Test/evidence runs this session
- Red-phase confirmed for Step 6: `devtools::test(filter='assign')` failed with `could not find function "assign_schemas"`.
- `devtools::test(filter='assign')` -- PASS (17)
- `devtools::test()` -- PASS (62)
- `devtools::check(document = FALSE, vignettes = FALSE, error_on = 'warning')` -- 0 errors, 0 warnings, 3 notes.

### Notes
- `devtools::build_readme()` required explicit pandoc path via `RSTUDIO_PANDOC`; README rendered successfully.
- `devtools::check()` notes are environmental/repository-shape notes only (path length, non-standard top-level files), not package code warnings/errors.

### Roadmap update
- Updated via `@cg-roadmap`:
  - `schema-rule-requirements.status`: `idea` -> `done`
  - `schema-rule-requirements.plan`: `null` -> `.cg-docs/plans/2026-10-09-named-check-schemas.md`
  - `initial-focus.status`: normalized to valid enum `active`

### Milestone check
- Milestone `in-order-defining-what-a` remains `in-progress` (not all features are `done`).

### Final status
- `completed`
