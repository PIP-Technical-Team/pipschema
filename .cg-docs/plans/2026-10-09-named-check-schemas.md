---
date: 2026-10-09
title: "Named-check schemas: definitions, evaluator and assignment file"
status: active
scope: "Deep"
brainstorm: ".cg-docs/brainstorms/2026-10-09-named-check-schemas.md"
language: "R"
estimated-effort: "medium"
deviation-policy: "ask"
artifact-schema-version: 1
phases: 3
tags: [schema, classification, named-checks, yaml, evaluator]
execution-report: ".cg-docs/work-reports/2026-10-09-named-check-schemas.md"
completed-phases: [1, 2]
current-phase: 3
---

# Plan: named-check schemas, evaluator and assignment file

## Objective

`{pipschema}` holds a reviewed YAML definition of two schemas, `pre-lineup`
and `new-lineup`, and a generic evaluator that applies those checks to every
vintage folder. A run writes one versioned YAML file that copies the rules and
lists the folders under each schema. It writes nothing if any folder matches
zero schemas or more than one. The exact checks are proposed from the vintage
folders and from `{pipapi}`, and reviewed before they are written.

## Context

- Design source: `.cg-docs/brainstorms/2026-10-09-named-check-schemas.md`.
  Charter: `compound-gpid.md` (reviewed 2026-10-09).
- The package is still the usethis scaffold: `DESCRIPTION` has no `Imports`,
  `R/pipschema-package.R` is empty, `tests/testthat.R` exists, and there is no
  `tests/testthat/` directory. `NAMESPACE` is empty.
- Branch: `feat/schema-discovery`.
- Do not implement `.cg-docs/plans/2026-10-07-pipschema-schema-evaluator.md`.
  Its findings F3, F5 and F8 may be reused as discovery evidence only. Its
  closed inventory, ignore list, skeleton and core `_aux` guard are out.
- `{pipapi}` still decides lineup from the folder-name date
  (`use_new_lineup_version()` in `R/create_lkups.R`, after 2025-05-01), then
  reads `estimations/prod_refy_estimation.fst`, `estimations/lineup_years.fst`
  and `lineup_data/<country>_<year>.fst`. That date cutoff is not a schema rule.
  It is the guess this package replaces. A later `{pipapi}` version is built
  for one or more known schemas and does not branch on the folder date. One
  version serves `pre-lineup`. Another serves `new-lineup`. Removing that
  cutoff, and any other schema conditional, is `{pipapi}` work. It is not built
  here. The assignment file must make "folders for schema X" readable so that
  work can use it.
- The data directory holds only PROD vintage folders. There is no PROD filter.
- Dialect: data.table-collapse. The evaluator should stay in base R plus
  `yaml`. Do not add data.table unless a step needs a table. No table is loaded
  from a vintage folder.

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| R1 | A schema is a name plus the checks named in a reviewed YAML definition. A folder matches when those checks pass. Extra files do not fail it unless a check says they must be absent. | Brainstorm R2, R3; charter |
| R2 | The evaluator loads definitions and applies a small check catalog. It does not name `pre-lineup` or `new-lineup`. Adding a schema that reuses a catalog check edits YAML only. A new check type adds one catalog function. | Brainstorm R2 |
| R3 | Every folder in the data directory is classified by contents. Zero matches or several matches are errors. A check that cannot be evaluated is an error. No date rule. No PROD/INT/TEST filter. | Brainstorm R4, R5; charter |
| R4 | The first two schemas are `pre-lineup` and `new-lineup`. Their checks are proposed by a read-only discovery step from the vintage folders and `{pipapi}`, and reviewed before they are written. Names may be confirmed in that review. | Brainstorm R4; charter |
| R5 | Checks are cheap: file or directory existence, format, and `.fst` headers. No full table loads. No content rules (countries, cell values). | Brainstorm R6; charter |
| R6 | The generated file is YAML. It copies the reviewed rules, lists folder names under each schema, carries a version field, and is deterministic. The path is an argument. It is never hand-edited. | Brainstorm R7; charter |
| R7 | Generation stops if validation fails. No partial file is written. The failure report names the folder and the failed check. | Brainstorm R7; charter |
| R8 | Read-only on vintage folders. Tests use synthetic trees and never touch `Y:/`. A real run is manual and on a read-only copy. | Charter |
| R9 | Documentation states why each starting schema matches, how to add a schema, and how to add a check type. | Charter |

## Phase 1: Discovery

### 1. Propose the checks

- **Requirements**: R4, R5
- **Files**: `.cg-docs/plans/2026-10-09-named-check-discovery.md` (notes only)
- **Details**: Read-only. Inspect `{pipapi}` branches that change which files or headers a vintage must have (`create_lkups.R` and the functions it calls). Inspect vintage folders under the data directory the user names, headers only (`fst::metadata_fst()`), no table loads. Propose the smallest set of named checks that separates `pre-lineup` from `new-lineup`. Record, for each check: type, path, expected result, and the folders it separates. Record evidence that is not a rule (the date cutoff, `lineup_median.fst`). Do not write `inst/schemas/`. Stop and ask the user to approve or edit the proposal, including the schema ids.
- **Test Scenarios**: none (research note).
- **Tests**: none.
- **Acceptance criteria**: the note names a separating check set, says what it does not check, and is explicitly approved before step 3 writes definitions.

## Phase 2: Catalog and evaluator

### 2. Package setup and synthetic helper

- **Requirements**: R5, R8
- **Files**: `DESCRIPTION`, `tests/testthat/helper-vintage.R`
- **Details**: Add `yaml` to `Imports`. Add `fst` to `Suggests` only if an approved check reads headers; do not Import it unless the catalog calls it on the user path. `make_vintage(root, name, files)` creates empty files and directories under `tempdir()`. It refuses a root outside `tempdir()`.
- **Test Scenarios**: happy: a tree with the approved lineup files is created; edge: file order in the helper does not affect the tree; error: a root outside `tempdir()` is refused.
- **Tests**: `tests/testthat/test-helper-vintage.R`
- **Acceptance criteria**: `devtools::test()` passes; no test path contains `Y:`.

### 3. Definition loader

- **Requirements**: R1, R2
- **Files**: `R/definitions.R`, `inst/schemas/definitions.yml` (written only after step 1 is approved), `tests/testthat/test-definitions.R`
- **Details**: YAML shape: `version`, then `schemas`, each with `id` and `checks`. Each check has `type` and the fields that type needs (`path`, `present`, `extension`, `columns`). `read_definitions(path)` returns a plain list, schemas and checks in sorted order. Errors, naming file and field: duplicate `id`, missing `checks`, unknown `type`, a check missing a required field, unreadable YAML. The shipped file contains only the two approved schemas.
- **Test Scenarios**: happy: the shipped file loads; edge: reordered YAML loads to the same object; error: duplicate id, unknown type, missing field, and bad YAML each error.
- **Tests**: `tests/testthat/test-definitions.R`
- **Acceptance criteria**: every loader error names the file and the field.

### 4. Check catalog

- **Requirements**: R2, R5
- **Files**: `R/checks.R`, `tests/testthat/test-checks.R`
- **Details**: One function per approved type, dispatched by `type`. Minimum set, extended only by what step 1 approved: `file_exists` (`path`, `present`), `dir_exists` (`path`, `present`), `dir_extension` (`path`, `extension`), `fst_columns` (`path`, `columns`) if approved. A false check returns a reason. A check that cannot be evaluated (unreadable path, header read failure) signals an error with the path. No check opens a table body. No check reads the folder name.
- **Test Scenarios**: happy: each type passes on a matching tree; edge: an extra file does not fail `file_exists`; error: a missing path when `present` is true fails with a reason; an unreadable header is an error, not a failed check.
- **Tests**: `tests/testthat/test-checks.R`
- **Acceptance criteria**: the catalog has no schema ids in its source.

### 5. Classifier

- **Requirements**: R1, R2, R3
- **Files**: `R/classify.R`, `tests/testthat/test-classify.R`
- **Details**: `classify_folder(path, definitions)` runs every schema's checks and returns the single matching `id`, or a condition that names every matching id and every failed check. It does not rank schemas and does not consult the folder name. A third schema added only in the test definitions classifies without any edit to `R/classify.R`.
- **Test Scenarios**: happy: a pre-lineup tree and a new-lineup tree each match one id; edge: an extra unlisted file still matches; a third schema in test YAML matches its own tree; error: a tree that matches none, and a tree that matches two, each return both ids or the failed checks.
- **Tests**: `tests/testthat/test-classify.R`
- **Acceptance criteria**: `R/classify.R` contains neither `pre-lineup` nor `new-lineup`.

## Phase 3: Assignment file

### 6. Writer and orchestrator

- **Requirements**: R6, R7, R8
- **Files**: `R/assign.R`, `tests/testthat/test-assign.R`
- **Details**: `assign_schemas(data_dir, output, definitions = NULL)` lists child directories, classifies each, and writes YAML only if every folder matches exactly one schema. The file has `version`, `schemas` (id, description, checks, sorted `folders`), and no timestamp or machine path. Schema and folder order are sorted. Default definitions are the shipped file. On failure, write nothing and signal an error whose message names the folder and the failed check or the matching ids. Listing is one level deep. An unreadable `data_dir` errors before any write.
- **Test Scenarios**: happy: two synthetic folders write a file whose folders sit under the approved ids; edge: a second run is byte-identical; an extra file in a folder does not change its schema; error: an unmatched folder, an ambiguous folder, and an unevaluable check each leave no output file.
- **Tests**: `tests/testthat/test-assign.R`
- **Acceptance criteria**: a failed run does not create `output`; a successful file round-trips with `yaml::read_yaml()` and contains the checks.

### 7. Documentation

- **Requirements**: R9
- **Files**: `README.Rmd`, `NEWS.md`, roxygen on exported functions
- **Details**: State the three parts, the named-check match rule, the two schemas and why their checks separate them, that the folder date is not a rule, that the data directory is PROD-only so there is no filter, and the two extension paths (edit YAML; add one catalog function). Note that `{pipapi}` binding is out of scope. Render `README.md` from `README.Rmd`.
- **Test Scenarios**: none.
- **Tests**: roxygen examples, if any, run under `devtools::check()`.
- **Acceptance criteria**: a reader can add a schema without reading `R/classify.R`.

### 8. Manual read-only run

- **Requirements**: R4, R8
- **Files**: `.cg-docs/plans/2026-10-09-named-check-run-notes.md`
- **Details**: Confirm the data directory is a read-only copy before running. Run `assign_schemas()` with an output path outside that directory. Record folder counts per schema and any cross-check against the 2025-05-01 date line. Do not change a check to force a count. If a folder matches zero or several schemas, stop and report the folder and the checks.
- **Test Scenarios**: none (manual).
- **Tests**: the run notes are the evidence for V6.
- **Acceptance criteria**: every folder is in exactly one schema; the lineup boundary matches the approved discovery note; the output path is not inside the data directory.

## Testing Strategy

- testthat 3rd edition, already in `Suggests`.
- Synthetic trees only, under `tempdir()`.
- One test must show that a schema added only in YAML is classified with no change to the evaluator.
- One test must show that an extra unlisted file does not fail a match.
- Assert modification times of the synthetic tree are unchanged after classify and after a failed assign.
- `devtools::test()` after each code step. `devtools::check()` once, at step 7.

## Documentation Checklist

- [ ] README: three parts, match rule, two schemas, how to add a schema, how to add a check type
- [ ] Roxygen on `read_definitions()`, `classify_folder()`, `assign_schemas()`
- [ ] `NEWS.md` entry
- [ ] Discovery note and run notes kept as plan evidence, not as package docs

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Discovery cannot separate the two schemas without a content rule or a date rule | Stop at step 1. Do not invent a check. Report the gap. |
| The approved checks still leave a real folder unmatched or ambiguous | Step 8 stops. Do not loosen a check inside the run. |
| `fst` header reads pull in a heavy dependency for one check type | Keep `fst` in `Suggests` unless the catalog must call it; skip the type if step 1 does not need it. |
| A later edit of a shipped check reclassifies past folders | Document that a released check changes only by explicit review. This plan does not add a fingerprint. |
| The old closed-inventory plan is still `status: active` and could be picked up by mistake | This plan is the current direction. Do not implement the 2026-10-07 plan. |

## Out of Scope

- `.cg-docs/plans/2026-10-07-pipschema-schema-evaluator.md` and its inventory, ignore list, skeleton, and core `_aux` guard
- Editing `{pipapi}` so a version no longer branches on the folder date. The intended consumer is: one `{pipapi}` version serves one or more known schemas (here, one version for `pre-lineup` and another for `new-lineup`) and drops `use_new_lineup_version()`. That edit is out of scope. The assignment file is the input it will read.
- The pairing file, routing, Docker, and ITS pipelines
- Any edit to `{pipapi}`
- A PROD/INT/TEST filter or a skipped-folder report
- Rules on cell values, country lists, or other content
- A stability fingerprint or a released-schema lock (record as a later idea only if the user asks)

## Completion Contract

### Outcome

`{pipschema}` holds a reviewed YAML definition of `pre-lineup` and `new-lineup`, a generic evaluator that does not name those schemas, and a function that writes a versioned YAML file copying the rules and listing every vintage folder under exactly one schema. On the real data directory the two schemas separate the known lineup boundary. Generation writes nothing if any folder matches zero or several schemas.

### Verification Surface

| ID | Phase | Evidence Required | Command/Artifact | Required |
|----|-------|-------------------|------------------|----------|
| V1 | 1 | Proposed checks reviewed before any definition is written | `.cg-docs/plans/2026-10-09-named-check-discovery.md` | yes |
| V2 | 2 | Unknown check type, duplicate id, and unloadable YAML each error and name the field | `devtools::test()` | yes |
| V3 | 2 | A third schema that reuses a catalog check classifies without editing the evaluator | `tests/testthat/test-classify.R` | yes |
| V4 | 3 | Unmatched, ambiguous, and unevaluable folders error and write no file | `tests/testthat/test-assign.R` | yes |
| V5 | 3 | Two runs on the same tree write byte-identical YAML | `tests/testthat/test-assign.R` | yes |
| V6 | final | Real read-only run: every folder in exactly one schema, lineup boundary as reviewed | `.cg-docs/plans/2026-10-09-named-check-run-notes.md` | yes |
| V7 | final | `R CMD check` has no errors | `devtools::check()` | yes |

### Constraints

| ID | Phase | Constraint | Check |
|----|-------|------------|-------|
| C1 | all | Read-only on vintage folders | modification-time test in steps 5 and 6 |
| C2 | all | No folder-date rule; no PROD filter | review of `R/classify.R` and `R/assign.R` |
| C3 | all | Named checks only; extra files do not fail a match | extra-file test in step 5 |
| C4 | all | Evaluator does not name `pre-lineup` or `new-lineup` | review of `R/classify.R` and `R/checks.R` |
| C5 | all | No write if validation fails | V4 |
| C6 | all | Tests never touch `Y:/` | review of `tests/testthat/` |
| C7 | all | Only new Imports dependency is `yaml` | `DESCRIPTION` |

### Boundaries

- Allowed: package code, YAML definitions, synthetic tests, docs, one manual read-only run, discovery notes, run notes.
- Out of scope: see Out of Scope.

### Iteration Policy

1. Discovery proposes checks. Stop for review before writing definitions.
2. Build the catalog and evaluator against synthetic trees before the real run.
3. If the real data contradicts the reviewed checks, stop and report. Do not loosen a check to force a match.
4. Do not add inventory, ignore-list, or core-`_aux` machinery.

### Blocked-Stop Conditions

- Discovery cannot separate the two schemas with cheap shape checks.
- The user does not approve the proposed checks.
- A real folder matches zero or several schemas under the approved checks.
- The data directory is unreadable, or is not a read-only copy when step 8 starts.
