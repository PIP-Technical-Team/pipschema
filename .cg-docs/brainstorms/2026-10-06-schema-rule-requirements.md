---
date: 2026-10-06
title: "Schema rule requirements: what makes a schema and how rules are expressed"
status: decided
scope: "Deep"
artifact-schema-version: 1
chosen-approach: "Required-items schemas from pipapi evidence, YAML rules + R evaluator"
tags: [schema, rules, classification, yaml, pipapi, discovery]
---
<!-- Valid status values: decided, in-progress, abandoned -->

# Schema rule requirements: what makes a schema and how rules are expressed

## Context

`{pipschema}` must classify every vintage folder in the PIP data directory into
exactly one schema, using explicit, reviewable rules on folder **structure**
(not content, not folder name/date). See `docs/context.md` and `compound-gpid.md`.

This session ran a first read-only discovery pass over
`Y:/temp/povertyscore-data` (19 vintage folders) and over the `{pipapi}` code
and git history, to decide **what rules make a schema** before naming any
schema. Branch: `feat/schema-discovery`.

The two `20260922_*` folders were found incomplete (copy in progress) and are
**excluded** until the user confirms the copy is done.

## Findings (evidence)

All checks were read-only: file listings, `fst::metadata_fst()` headers only,
no table loads.

### Data inventory (17 complete folders)

- No single file path is present in all folders. Exact file-set fingerprints
  give **12 groups**; exact column/type fingerprints of 47 `.fst` tables give
  **17 groups** (every folder unique). Both are far too fine → rejected as a
  schema basis.
- 21 of 47 tables change columns over time (e.g. `_aux/gdp.fst`, `_aux/pop.fst`
  6 variants each; core `estimations/*` tables 3-4 variants).
- Most aux tables are stored in duplicate formats (`.fst`+`.qs`, `.qs`+`.rds`).
- Same release date, different file sets: `20230919`, `20240627`, `20260324`
  (2011 vs 2017 / 2017 vs 2021 PPP).

### pipapi-required items checked per folder

Files read in `create_lkups()` (pipapi `R/create_lkups.R`) and the columns it
uses:

| Item | 13 folders `20220609`-`20250401` | 4 folders `20250930`, `20260324` |
|---|---|---|
| 10 core files (`_aux/*`, `prod_svy/ref_estimation`, `dist_stats`, `.rds`) + used columns | present | present |
| `estimations/prod_refy_estimation.fst`, `lineup_years.fst`, `lineup_dist_stats.fst` | absent | present, columns OK |
| `lineup_data/` (country-year `.fst`) | absent/empty | present |
| `_aux/missing_data.fst` column `welfare_type` | absent | present |
| `_aux/_vintage/`, `estimations/_vintage/` | absent | only `20260324_*` |

→ **Two provisional candidate groups**: pre-lineup (13) and lineup (4). No
partial/mixed folder; same-release folders agree on these items. Boundary is
consistent with, but not defined by, pipapi's date cutoff
`use_new_lineup_version()` (> 2025-05-01). Groups are **not yet named**.

### pipapi git history (first commit referencing each file)

| File | First used by pipapi | First seen in data |
|---|---|---|
| `pop_region`, `country_profiles.rds`, `missing_data` | 2021-2022 | all folders |
| `pg_lnp` (+ `pg_svy`) | `adc3184` 2024-07-02 | `20240627_2017` on |
| `metaregion` | `6c78fca` 2024-07-05 | `20240627` on |
| `prod_refy_estimation`, `lineup_data/` | `ddebbfd`/`2a60af2` 2025-05-27 | `20250930` on |
| `lineup_years`, `lineup_dist_stats` | `a7da907`/`b29cc6b` 2025-08 | `20250930` on |
| `national_poverty_lines` | no clear code read | 2023 on |

The lineup change was rolled out in code over ~3 months → supports treating it
as one structural change.

### How pipapi reads optional aux files

- `get_pg_table()` and `get_metaregion_table()` (`R/utils-aux.R`) wrap reads in
  `tryCatch` and return an **empty typed table** when the file is missing →
  results silently lose prosperity-gap / metaregion info.
- `aux_tables` is built from whatever `_aux/*.fst` exists (auto-listed).
- `20240627_2011` has **no** `pg_*` files; `20240627_2017` has them → same
  release, silently different pipapi output.

## Requirements

### R1. Definition of a schema

- A schema = a **named list of required structural items** (files, folders,
  formats, columns), each with a rationale.
- A folder belongs to a schema iff it satisfies **all** its required items.
  Anything not listed is ignored for classification.
- Every folder → exactly one schema. Zero or several matches = error. No
  fallbacks, no date-based guessing.

### R2. Choosing required items

- **Approach A**: start from what `{pipapi}` reads, cross-checked against what
  the real folders share. Start coarse; refine only by **adding new schemas**,
  never by redefining existing ones.
- **Requirement test**: an item is required if some consumer code reads it by
  name **and fails without it**. Evidence (file + commit / line in pipapi) is
  cited in the rule's rationale.
- **Three item categories**:

  | Category | Example | Effect |
  |---|---|---|
  | `required` — code fails without it | `prod_ref_estimation`, lineup files | defines the schema |
  | `flagged` — read by name but missing-tolerant; results change silently | `pg_lnp`, `pg_svy`, `metaregion` | reported per folder; does **not** define a schema (for now) |
  | `inventory` — auto-listed only | other `_aux/*.fst` | recorded in inventory only |

- Adding files alone (e.g. "+3 aux files") is **not** a reason for a new schema.
- Promoting a `flagged` item to `required` later = new schema, deliberate review.

### R3. What rules can check (rule kinds)

Evaluated in cost order (cheap first, short-circuit on failure):

1. `dir_exists` / `dir_absent`
2. `file_exists` / `file_absent`
3. `dir_nonempty` / `glob_min` (pattern match count)
4. `format` (extension / expected reader)
5. `columns_include` (from file header only)
6. `column_types` (from file header only)

Each rule must carry: `id`, `kind`, `target`, `category`
(`required`/`flagged`/`inventory`), `rationale` (evidence), `cost` tier.

### R4. Rule constraints

- Never use folder name or date to decide (cross-check only).
- Never load full tables; header metadata at most.
- Any rule that cannot be evaluated (unreadable file, unknown format) is
  reported as an error, never treated as pass/fail silently.
- Read-only on vintage folders.
- Deterministic: stable ordering, no timestamps/machine paths in decisive output.

### R5. Rule storage (decided)

- **YAML data files** in the package (e.g. `inst/schemas/<schema>.yml`), one per
  schema, plus **one small R evaluator** that applies them.
- Rule files are reviewed changes; released schemas are not edited in meaning.

Illustrative sketch only (not final syntax):

```yaml
schema: <tbd>
description: <tbd>
rules:
  - id: est-refy
    kind: file_exists
    target: estimations/prod_refy_estimation.fst
    category: required
    cost: 1
    rationale: "Read by create_lkups() lineup branch (pipapi ddebbfd, 2025-05-27); fails if absent."
  - id: aux-pg-lnp
    kind: file_exists
    target: _aux/pg_lnp.fst
    category: flagged
    cost: 1
    rationale: "get_pg_table() tolerates absence; PG silently empty."
```

### R6. Reporting

- Per folder: assigned schema or error (no match / multiple matches / rule
  evaluation error), failed required rules, flagged items missing.
- Inventory of non-classifying differences, for human review.

## Approaches Considered

### Approach 1: Required-items schemas (chosen)
Schemas list only required items; other differences flagged or inventoried.
- Pros: simple, coarse, easy to review; extendable by adding schemas.
- Cons: relies on judgement + pipapi evidence to choose required items.

### Approach 2: Compatibility rule with traits (deferred)
Breaking changes → new schema; additive changes → recorded traits/minor version.
- Pros: richer record of evolution.
- Cons: extra machinery; user unsure it is worth it. Kept open.

### Approach 3: Exact fingerprints (rejected)
Group by exact file set or exact columns/types.
- Cons: 12-17 groups for 17 folders; content-like variation (country/year files,
  timestamps) leaks into schema identity.

### Rule-storage options considered
- **YAML + R evaluator** (chosen): readable, data not logic.
- R predicate functions: no parser, but rules become code.
- Reference fingerprints: too strict, over-splits.

## Decision

Use **required-items schemas** chosen via Approach A (pipapi evidence,
cross-checked with data), with three item categories
(`required` / `flagged` / `inventory`). Optional-but-tolerated files
(`pg_*`, `metaregion`) are **flagged, not schema-defining**, for now. Rules are
stored as **YAML files + one R evaluator**. Provisional result: two candidate
groups (pre-lineup, lineup), not yet named.

## Open Questions

1. Compatibility rule with traits — adopt later or not?
2. Do `_aux/_vintage/` / `estimations/_vintage/` (only `20260324_*`) define a
   schema? Default lean: detail only.
3. `20260922_*` folders: re-scan once copy completes; may confirm, extend or
   create a group.
4. Release definition (date prefix?) and same-release consistency
   (`20240627` differs on flagged `pg_*`).
5. Folders matching no schema: fail vs list as excluded.
6. Schema output file format and location.
7. Exact YAML syntax and rule-kind set.
8. Meaning-only changes: known limit, out of scope.
9. Whether non-`.fst` copies (`.qs`, `.rds`, `.dta`) matter for any rule.

## Notes for pipapi (out of scope, record only)

- Hard reads without tolerance: `R/ui_country_profile.R:126` (`pg_svy`),
  `wld_lineup_year()` in `R/valid_years.R` (`metaregion`) — fail if file absent,
  unlike the `tryCatch` helpers.
- `get_pg_table()` / `get_metaregion_table()` silently return empty tables —
  conflicts with "no silent fallbacks".

## Next Steps

1. Finalise YAML rule syntax and rule-kind set (R3, R5).
2. Write the required-item list per candidate group with pipapi evidence
   citations (R2).
3. Build a read-only scanner: inventory + rule evaluation + flag report (R6),
   with synthetic-folder tests.
4. Re-run on all folders once `20260922_*` copy is complete.
5. Review groups, then name the schemas.
