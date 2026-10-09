---
date: 2026-10-07
title: "pipschema: closed schema definitions, evaluator and registry"
status: active
scope: "Deep"
brainstorm: ".cg-docs/brainstorms/2026-10-07-closed-schema-design.md"
language: "R"
estimated-effort: "large"
deviation-policy: "ask"
artifact-schema-version: 1
phases: 3
tags: [schema, classification, closed-world, yaml, registry, evaluator]
---

# Plan: pipschema closed schema definitions, evaluator and registry

## Objective

`{pipschema}` holds reviewed YAML schema definitions and an evaluator that can
be run on a PIP data directory at any time. It classifies each PROD vintage
folder into exactly one schema (or reports it as unclassified), checks the
result, and writes a generated registry (folder to schema) that `{pipapi}`'s
`main.R` can read with base R. On `Y:/temp/povertyscore-data` it must give
13 base and 6 lineup folders, none unclassified.

**v1 scope (cut down).** v1 is: definitions + overlap check + scanner +
classifier + registry + docs + one manual real-data run (with the small PROD
listing and orchestrator glue that the run needs). Stability checks, logged
overrides, definition fingerprints and the release-consistency check are
deferred to a **v2 plan**, to be written once the schema split has been
validated against the real data (step 11).

## Context

- Source of truth: `.cg-docs/brainstorms/2026-10-07-closed-schema-design.md`
  (referred to below as "the brainstorm"; R1-R7, A1-A11, F1-F8) and
  `docs/context.md`.
- The repo currently holds only the package scaffold (`DESCRIPTION`,
  `R/pipschema-package.R`, `tests/testthat.R`, empty `NAMESPACE`). `DESCRIPTION`
  has no `Imports`; `testthat` is in `Suggests`.
- Branch: `feat/schema-discovery`. Roadmap feature: `closed-schema-design`.
- Working schema names are `base` and `lineup`. They are placeholders until
  confirmed in step 9.
- Project rules (`compound-gpid.md`): fail loudly, read-only on data, no silent
  fallbacks, deterministic output, tests on synthetic trees only, runs on real
  data are manual and on a read-only copy.

### Decisions this plan settles (proposals from the brainstorm)

| Topic | Default adopted here | Where |
|---|---|---|
| "Released" schema, stability, overrides (A2) | **deferred to v2**; v1 does not enforce it | v2 plan |
| Release consistency (R6.3) | **deferred to v2**; the real-run notes may mention release dates by hand | v2 plan |
| Unclassified folders (A3) | write the registry with an `unclassified` status per folder, then raise a failing error; hard errors stop before writing | step 8 |
| Registry format (A7) | one CSV with `# key: value` comment lines, readable with `read.csv(comment.char = "#")` | step 7 |
| Where the ignore list lives | one shared file `inst/schemas/_ignore.yml` | step 2 |
| Where the core `_aux` set lives | inside each schema definition, so adding a schema edits nothing else | step 2 |

**Charter conflict to resolve.** `compound-gpid.md` says "Generation of the
schema file stops if validation fails". The unclassified behaviour above (write
the registry with an `unclassified` section, then fail) departs from that
sentence. The plan implements the brainstorm's choice (A3 b); the charter
wording needs a reviewed update (see Risks).

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| R1 | A schema is a closed description: required items, optional items, nothing else tracked is allowed; match is exact | Brainstorm R1 |
| R2 | Tracked skeleton: top-level entries, `survey_data/` and `lineup_data/` as present/absent plus `.fst` format, closed `estimations/` list; reviewed ignore list (`.qs`, `.dta`, `.duckdb`, `data_update_timestamp.txt`, `_vintage/`) | Brainstorm R2, R3 |
| R3 | Core `_aux` set (13 files) as an integrity guard; other `_aux` files allowed and reported as warnings; `pg_svy`, `pg_lnp`, `metaregion` flagged | Brainstorm A10, R7 |
| R4 | Optional items carry a reason and the folder range where they occur; the persistence principle is documented; `lineup_median.fst` is optional in `base` and absent from `lineup` | Brainstorm R4, R5, A8 |
| R5 | Definition-time check: two schemas overlap if each one's required items are allowed by the other; overlap is an error | Brainstorm R6.1 |
| R6 | Data-time check: every PROD folder matches exactly one schema; zero or several is reported loudly with the failed items | Brainstorm R1, R6.2 |
| R8 | PROD scope: INT/TEST folders are skipped and listed once as "skipped, not PROD", never errors; the folder name decides only scope and the R7 grouping | Brainstorm A1 |
| R9 | Registry is a separate generated artifact: deterministic, versioned, committed, and readable from plain base R as "folder names for schema X" | Brainstorm A7 |
| R11 | Unclassified handling: registry written with the problem folders marked, then a failing error; hard errors (overlap, several matches, unreadable directory) stop before writing | Brainstorm A3 |
| R12 | Read-only on vintage folders; cheap checks only; no table loads; any rule that cannot be evaluated is reported, never passed silently | Brainstorm R7, charter |
| R13 | Tests on synthetic trees only, including INT/TEST, truncated, partial and lineup-with-`lineup_median` folders | Charter, brainstorm A1 |
| R14 | Documentation: schemas and rules, persistence principle, PROD-only line, file-level-only limit, core-set rule and its limits, how to add a schema | Brainstorm A1, A6, A8, A10 |
| R15 | Manual read-only run on the real data gives 13 `base` and 6 `lineup`, 0 unclassified | Brainstorm F8 |

## Phase 1: Definitions and scanning

### 1. Package setup and synthetic-tree test helper
- **Requirements**: R12, R13
- **Files**: `DESCRIPTION`, `R/pipschema-package.R`, `tests/testthat/helper-synthetic.R`, `NAMESPACE` (via roxygen)
- **Details**: Add `yaml` to `Imports` (the only new dependency). Write a test helper `make_vintage(root, name, spec)` that builds a synthetic vintage folder from a list (directories, files, optional `lineup_data/` stubs) using empty files only, and `make_base_vintage()` / `make_lineup_vintage()` helpers that build the shape of each real schema. No test may touch `Y:/`.
- **Test Scenarios**: happy: helper builds a base tree and a lineup tree; edge: file lists are produced in stable order; error: helper refuses to write outside `tempdir()`.
- **Tests**: `tests/testthat/test-helper-synthetic.R`
- **Acceptance criteria**: `devtools::test()` passes; helpers create trees under `tempdir()` only.

### 2. Definition format, loader and ignore list
- **Requirements**: R1, R2, R3, R4
- **Files**: `R/definitions.R`, `inst/schemas/_ignore.yml`, `tests/testthat/test-definitions.R`
- **Details**: Define the YAML schema: `id`, `description`, `required` (top-level entries, directories, `estimations/` files, data-folder formats), `optional` (each item with `reason` and `folder_range`), `core_aux` (list), `flagged_aux` (list). `read_schemas(dir)` loads every `inst/schemas/*.yml` except files starting with `_`, validates field presence and types, and reads `_ignore.yml`. It errors on: an optional item without a reason or range, an item that is in both `required` and `optional`, a duplicate schema `id`, an unknown key, an ignore-list entry that collides with a required item. Output is a plain list with items in sorted order.
- **Test Scenarios**: happy: a valid definition loads; edge: reordered YAML gives the same object; error: missing reason, duplicate id, unknown key, unreadable file each raise a clear error.
- **Tests**: `tests/testthat/test-definitions.R`
- **Acceptance criteria**: every validation error names the file and the field.

### 3. Definition-time overlap check
- **Requirements**: R5
- **Files**: `R/check_definitions.R`, `tests/testthat/test-check-definitions.R`
- **Details**: `check_definitions(schemas)` computes, for every pair, whether each schema's required items are within the other's allowed items (required plus optional). A true result for a pair is an error naming both schemas and the shared items. Also check that each schema's `core_aux` is disjoint from `flagged_aux`.
- **Test Scenarios**: happy: `base` and `lineup`-shaped definitions do not overlap; edge: a schema whose optional items cover another's required items is flagged; error: two identical definitions are rejected.
- **Tests**: `tests/testthat/test-check-definitions.R`
- **Acceptance criteria**: no data needed to run; overlapping pairs are always reported.

### 4. Read-only vintage scanner
- **Requirements**: R2, R3, R12
- **Files**: `R/scan_vintage.R`, `tests/testthat/test-scan-vintage.R`
- **Details**: `scan_vintage(path, ignore)` lists one vintage folder (non-recursive for `_aux/` and `estimations/`; for `survey_data/` and `lineup_data/` it only checks the directory and the set of file extensions, never individual files) and returns the tracked structure: top-level entries, directories, formats inside data directories, `estimations/` files, `_aux/` files. Items matching the ignore list are returned separately as `ignored`. No file is opened. An unreadable path is an error carrying the path, not an empty result.
- **Test Scenarios**: happy: base and lineup trees give the expected structure; edge: `.qs`, `.dta`, `.duckdb`, `_vintage/` and the timestamp file are ignored; error: an unreadable or missing folder raises an error.
- **Tests**: `tests/testthat/test-scan-vintage.R`
- **Acceptance criteria**: the scanner makes no write calls (asserted by a test that checks modification times of the synthetic tree).

## Phase 2: Classification and registry

### 5. Vintage listing and PROD scope
- **Requirements**: R8
- **Files**: `R/list_vintages.R`, `tests/testthat/test-list-vintages.R`
- **Details**: `list_vintages(data_dir)` returns directories under `data_dir` that match `^\d{8}_\d{4}_\d{2}_\d{2}_(PROD|TEST|INT)$` and splits them into in-scope (`_PROD`) and `skipped_not_prod` (INT/TEST). Directories that do not match the pattern at all are reported once as `not_a_vintage_name`, not errors and not counted as unclassified. The pattern is kept in one place with a comment pointing at `{pipapi}`'s `get_vintage_pattern_regex()` (drift risk, see Risks). Output order is sorted.
- **Test Scenarios**: happy: 3 PROD folders are returned; edge: INT and TEST are skipped and listed once; error: an unreadable data directory is a hard error.
- **Tests**: `tests/testthat/test-list-vintages.R`
- **Acceptance criteria**: the folder name is used only for scope.

### 6. Exact-match classifier
- **Requirements**: R1, R3, R4, R6, R12
- **Files**: `R/classify.R`, `tests/testthat/test-classify.R`
- **Details**: `classify_vintage(scan, schemas)` tests the scan against every schema: all required items present, nothing tracked outside required plus optional, all `core_aux` present. Result per folder: `schema`, `status` (`classified` / `unclassified`), `failed` (missing required items, disallowed items, missing core files), `warnings` (non-core `_aux` files not reviewed, flagged files present or absent). One match is classified; zero is `unclassified`; several is a hard error (the definition-time check should make this impossible). No fallback to date or name.
- **Test Scenarios**: happy: base tree gives `base`, lineup tree gives `lineup`; edge: base tree with `lineup_median.fst` is still `base`; a lineup tree with `lineup_median.fst` is unclassified with that file named as disallowed; error: a lineup tree missing `lineup_years.fst`, a base tree missing a core `_aux` table, and a folder with an unknown top-level entry are each unclassified with the failed item named.
- **Tests**: `tests/testthat/test-classify.R`
- **Acceptance criteria**: every unclassified result lists the exact failed items.

### 7. Registry writer and plain-R reader
- **Requirements**: R9, R12
- **Files**: `R/registry.R`, `tests/testthat/test-registry.R`
- **Details**: `write_registry(result, path)` writes a CSV with one comment line (`# registry_format_version: 1`) and columns `folder`, `schema`, `status` (`classified` / `unclassified` / `skipped_not_prod`), `detail`. Rows sorted by `folder`; no timestamps, no machine paths. `read_registry(path)` reads it back, checks the format version and errors on an unknown one. `registry_folders(registry, schema)` returns the folder names of a schema. The CSV must be readable with `read.csv(path, comment.char = "#")` alone, which a test asserts without calling any `{pipschema}` function. v1 stores no definition fingerprints; the format version lets v2 add them.
- **Test Scenarios**: happy: write then read returns the same table; edge: writing twice gives byte-identical files; error: an unknown format version, a missing file and a malformed row each raise an error.
- **Tests**: `tests/testthat/test-registry.R`
- **Acceptance criteria**: "folder names for schema X" is one line of base R.

### 8. Orchestrator and per-folder report
- **Requirements**: R6, R8, R11, R12
- **Files**: `R/update_registry.R`, `R/report.R`, `tests/testthat/test-update-registry.R`
- **Details**: `update_registry(data_dir, registry_path, schemas_dir = <package>)` runs: load and check definitions (R5), list vintages (R8), scan and classify (R6). Hard errors stop before writing: overlapping definitions, several matches, an unreadable directory. Otherwise it writes the registry and, if any folder is unclassified, raises an error of class `pipschema_validation_failed` after writing, so a script exits with a failing status. It returns the full result invisibly on success. `format_report(result)` returns a readable per-folder report: schema or failure reasons, warnings, flagged files, the skipped non-PROD list. The registry is written to a path given by the caller; it is never written inside a vintage folder.
- **Test Scenarios**: happy: a synthetic directory of base and lineup folders writes the registry and returns no error; edge: INT and TEST folders are skipped and appear once in the report, and the run still passes; error: a partial lineup folder gives a registry with that folder `unclassified` and a failing error, the other folders still written; an overlapping definition set stops before writing.
- **Tests**: `tests/testthat/test-update-registry.R`
- **Acceptance criteria**: the same input gives byte-identical output on two runs; failure modes match R11.

## Phase 3: Real definitions, documentation and manual run

### 9. Real schema definitions and name confirmation
- **Requirements**: R1, R2, R3, R4
- **Files**: `inst/schemas/base.yml`, `inst/schemas/lineup.yml`, `tests/testthat/test-shipped-definitions.R`
- **Details**: Write the two definitions from F5 and A10. `base`: required skeleton; optional `estimations/lineup_median.fst` with reason "persistence: present only from 2022-09 to 2023-09, not a lasting layout change" and folder range `20220909` to `20230919`. `lineup`: base skeleton plus `lineup_data/` (`.fst`), `estimations/prod_refy_estimation.fst`, `lineup_years.fst`, `lineup_dist_stats.fst`; `lineup_median.fst` is not listed. Both: the same 13 `core_aux` files and `flagged_aux` = `pg_svy`, `pg_lnp`, `metaregion`. Ask the user to confirm the names `base` and `lineup`, or replace them, before this step is closed. Add a note in each definition that the data team has not yet confirmed that `lineup_median.fst` was a dropped output. A test builds synthetic trees from the shipped definitions and checks the overlap check, the classification and the `lineup_median` rule.
- **Test Scenarios**: happy: shipped definitions load and do not overlap; edge: synthetic base tree with `lineup_median.fst` is `base`; error: synthetic lineup tree with `lineup_median.fst` is unclassified.
- **Tests**: `tests/testthat/test-shipped-definitions.R`
- **Acceptance criteria**: shipped definitions pass `check_definitions()`; the user has confirmed the names.

### 10. Documentation
- **Requirements**: R14
- **Files**: `vignettes/schemas.Rmd`, `README.Rmd`, `README.md`, `man/*.Rd` (roxygen), `DESCRIPTION` (vignette builder)
- **Details**: Document, in plain language: what a schema is (closed list, required, optional); the tracked skeleton and the ignore list; the persistence principle as a rule for people (a difference defines a schema only if it marks a lasting layout change; optional is an exception and each optional item needs a reason and the folder range); the core `_aux` rule and that the core set is not exhaustive and that changing it is a reviewed schema edit; flagged files and why; the PROD-only line ("scope is PROD only; in deployed containers INT/TEST are not available, because only PROD folders exist on the server"); the file-level-only limit and the year-column tables (`pop`, likely `gdp`, `pce`, `cpi`); the completeness check kept outside the schema rules; the compatibility fact about direct `pg_svy` and `metaregion` reads in `{pipapi}`; the registry format with the base-R snippet; how to add a schema; a short "not in v1" section naming the deferred v2 items. Roxygen help for every exported function.
- **Test Scenarios**: happy: the vignette builds; edge: README code runs on a synthetic tree; error: documentation build fails on a broken example.
- **Tests**: `devtools::build_vignettes()`; `devtools::document()`
- **Acceptance criteria**: a person who did not write the package can follow "how to add a schema" with no other source.

### 11. Manual read-only run on the real data
- **Requirements**: R15, R12
- **Files**: `inst/scripts/run_real_data.R`, run notes appended to this plan's folder (`.cg-docs/plans/2026-10-07-pipschema-schema-evaluator-run-notes.md`)
- **Details**: Run `update_registry()` on `Y:/temp/povertyscore-data` only after confirming with the user that it is a read-only copy. Write the registry to a path outside the data directory. Compare with F8: 19 PROD folders, 13 `base`, 6 `lineup`, 0 unclassified, 13 core files present everywhere, warnings only for extra `_aux` files. Save the report in the run notes, together with the open points for the v2 plan. A second run must give a byte-identical registry. If the real result differs from F8, stop (blocked-stop condition) and report. This run is the validation of the schema split that gates the v2 plan.
- **Test Scenarios**: happy: result equals F8; edge: running twice is identical; error: a deliberate renamed file in a scratch copy of one folder (never the data copy) is reported as unclassified.
- **Tests**: manual; output saved in the run notes
- **Acceptance criteria**: V3 holds and the run notes are saved.

### 12. Final checks and hand-over
- **Requirements**: R12, R13, R14
- **Files**: `NEWS.md`, `roadmap.json` (via `@cg-roadmap`)
- **Details**: Run `devtools::test()` and `devtools::check()`; review `DESCRIPTION` Imports (only `yaml`); add a `NEWS.md` entry; list the open items for the user (data-team confirmations, charter wording, registry location, completeness check owner). Use conventional commits per phase.
- **Test Scenarios**: happy: check passes; edge: tests pass on a clean temp directory; error: any warning in `devtools::check()` is fixed or explained.
- **Tests**: `devtools::test()`, `devtools::check()`
- **Acceptance criteria**: V1 and V9 hold.

## Testing Strategy

- `testthat` 3rd edition; every test builds synthetic trees under `tempdir()`; no test reads `Y:/`.
- Unit tests per step (listed above). One integration test per behaviour of `update_registry()`: pass, INT/TEST skipped, partial folder, overlapping definitions.
- Determinism test: two runs, byte-identical registry.
- Read-only test: modification times of the tree are unchanged after a run.
- A test that reads the registry with `read.csv(comment.char = "#")` only, to prove the plain-R requirement.
- Real data is checked only in step 11, by hand.

## Documentation Checklist

- [ ] Vignette `schemas.Rmd` covering every point in step 10
- [ ] README updated; `README.md` regenerated from `README.Rmd`
- [ ] Roxygen help for all exported functions; `man/` regenerated
- [ ] Persistence principle and "optional needs reason and range" written as a rule
- [ ] PROD-only line, file-level-only limit, core-set limits, compatibility fact
- [ ] How to add a schema; "not in v1" section
- [ ] `NEWS.md` entry

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Unclassified handling (write then fail) conflicts with the charter sentence "generation stops if validation fails" | Hard errors stop before writing; the charter wording needs a reviewed update before release (flagged to the user) |
| The core `_aux` set is not exhaustive (dynamic reads missed), so a damaged folder missing an unlisted table still classifies | Document the limit; core membership is a reviewed edit; completeness is an adjacent check outside the schema rules |
| Closed lists fail loudly on every new file in `estimations/` or the skeleton (accepted cost A11) | The report names the exact item; the fix is a reviewed definition edit or a new schema |
| Vintage-name pattern drifts from `{pipapi}`'s | One shared constant with a pointer comment; the shared definition stays an open item (`docs/context.md` question 7) |
| Without stability checks (v2), a re-run can silently change a folder's schema, or a definition can be edited after release | Accepted for v1; the registry is committed so `git diff` shows any change; v2 adds enforcement |
| The real data directory is not a read-only copy | Confirm before step 11; the registry is written outside the data directory |
| `lineup_median.fst` reason not yet confirmed by the data team | Definition carries a note; documented as open; the rule does not depend on the answer |

## Out of Scope

- **Deferred to a v2 plan**, written after the real run validates the split: stability of past classifications, logged overrides, definition fingerprints and the "released" rule (A2), and the release-consistency check (R6.3)
- Any change to `{pipapi}`; routing, Docker, ITS pipelines
- The pairing file (releases to schemas to `{pipapi}` versions)
- Column-level rules; meaning-only changes
- Where and when `{pipschema}` runs, and who triggers it
- The survey-file completeness check (kept as a documented adjacent check; owner undecided)
- Final registry location in `/Data` or in a repo (the path is an argument)
- Handling of INT/TEST folders beyond skipping them

## Completion Contract

### Outcome
`{pipschema}` has reviewed YAML schema definitions and an evaluator you can run on a data directory at any time. On `Y:/temp/povertyscore-data` it classifies the 19 PROD folders as 13 `base` and 6 `lineup` with none unclassified, and writes a registry readable with base R. Stability checks, overrides, fingerprints and release consistency are deferred to v2.

### Verification Surface
| ID | Phase | Evidence Required | Command/Artifact | Required |
|----|-------|-------------------|------------------|----------|
| V1 | final | All tests pass, using only synthetic folder trees | `devtools::test()` | yes |
| V2 | 1 | Two overlapping definitions are rejected; the shipped definitions have no overlap | `tests/testthat/test-check-definitions.R`, `test-shipped-definitions.R` | yes |
| V3 | 3 | Real run: 19 folders, 13 `base`, 6 `lineup`, 0 unclassified | manual read-only run, notes in `.cg-docs/plans/2026-10-07-pipschema-schema-evaluator-run-notes.md` | yes |
| V4 | 2 | The registry gives "folder names for schema X" with base R only | `tests/testthat/test-registry.R` (uses `read.csv` only) | yes |
| V5 | 2 | Two runs on the same data give byte-identical registries | `tests/testthat/test-update-registry.R` | yes |
| V6 | 2 | INT/TEST folders are skipped and reported once, not errors | `tests/testthat/test-list-vintages.R`, `test-update-registry.R` | yes |
| V7 | 2 | A truncated or partial folder and a lineup folder with `lineup_median.fst` are reported as unclassified with the failed item named | `tests/testthat/test-classify.R`, `test-shipped-definitions.R` | yes |
| V9 | final | `R CMD check` has no errors | `devtools::check()` | yes |

### Constraints
| ID | Phase | Constraint | Check |
|----|-------|------------|-------|
| C1 | all | Read-only on data folders | code review; modification-time test in step 4 and step 8 |
| C2 | all | Folder name decides only PROD scope, never a schema | review of `classify_vintage()` and step 5 |
| C3 | all | Deterministic: stable ordering, no timestamps or machine paths in decisive output | V5 |
| C4 | all | Few dependencies: `yaml` only in Imports; the registry reader needs base R | `DESCRIPTION` review, V4 |
| C5 | all | v1 does not implement stability checks; the registry is committed so changes show in `git diff` | review |
| C6 | all | No fallback: any rule that cannot be evaluated is reported | step 4 and step 6 tests |
| C7 | all | Conventional commits, on a branch | `git log` |

### Boundaries
- Allowed: everything inside `pipschema` (code, YAML definitions, registry code, tests, documentation, run notes, the roadmap link through `@cg-roadmap`).
- Out of scope: see the Out of Scope section.

### Iteration Policy
1. Build the steps in order and run the tests after each step.
2. If the real data contradicts F8, stop and report it instead of loosening a rule.
3. Schema names are placeholders until the user confirms them in step 9.
4. The defaults in "Decisions this plan settles" apply unless the user changes them before the step that implements them.
5. Do not add v2 items (stability, overrides, fingerprints, release consistency) to v1; record them in the run notes for the v2 plan.

### Blocked-Stop Conditions
- The real run shows a folder that fits no schema, or more than one.
- Two definitions overlap in a way the closed lists cannot resolve.
- The data directory is unreadable, or is not a read-only copy when step 11 starts.
- The data team contradicts a recorded reason, such as the `lineup_median.fst` persistence reason.
- The charter conflict on "generation stops if validation fails" is answered against the plan's unclassified behaviour.
