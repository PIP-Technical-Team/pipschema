---
date: 2026-10-09
plan: ".cg-docs/plans/2026-10-09-named-check-schemas.md"
step: 1
title: "Discovery proposal for pre-lineup vs new-lineup checks"
status: proposed
artifact-schema-version: 1
---

# Discovery proposal for schema-separating checks

## Scope and method

Read-only discovery for Plan Step 1.

- Source code evidence from `{pipapi}` only (`R/create_lkups.R`), focusing on the branch currently gated by `use_new_lineup_version()`.
- Data evidence from folder listings under `Y:/temp/povertyscore-data` (19 folders), with file-presence and extension checks only.
- No table-body reads, no writes in the data directory, and no schema definitions written.

## Evidence summary

### A. Current `{pipapi}` branch markers (evidence, not schema rule)

In `pipapi/R/create_lkups.R`, the new-lineup branch reads:

- `estimations/prod_refy_estimation.fst`
- `estimations/lineup_years.fst`
- `estimations/lineup_dist_stats.fst`
- files under `lineup_data/<country>_<year>.fst`

The branch is currently selected by folder-name date (`use_new_lineup_version()`), which is explicitly out as a schema rule.

### B. Folder-profile check across 19 PROD folders

For all folders in `Y:/temp/povertyscore-data`:

- The four lineup markers above are absent in 13 folders (`20220609` to `20250401`).
- The same four markers are present together in 6 folders (`20250930`, `20260324`, `20260922`).
- `lineup_data/` is `.fst`-only in those 6 folders.
- `estimations/lineup_median.fst` appears in a subset of older folders only; it does not separate the two final groups.

## Proposed minimal separating checks

Working schema IDs (confirm in review): `pre-lineup`, `new-lineup`.

### Schema: `new-lineup`

All checks must pass:

1. `dir_exists(path="lineup_data", present=true)`
2. `dir_extension(path="lineup_data", extension=".fst")`
3. `file_exists(path="estimations/prod_refy_estimation.fst", present=true)`
4. `file_exists(path="estimations/lineup_years.fst", present=true)`
5. `file_exists(path="estimations/lineup_dist_stats.fst", present=true)`

### Schema: `pre-lineup`

All checks must pass:

1. `dir_exists(path="lineup_data", present=false)`
2. `file_exists(path="estimations/prod_refy_estimation.fst", present=false)`
3. `file_exists(path="estimations/lineup_years.fst", present=false)`
4. `file_exists(path="estimations/lineup_dist_stats.fst", present=false)`

## Why this is minimal

- Uses only cheap shape checks (existence + extension).
- Uses artifacts `{pipapi}` already treats as boundary-related, without inheriting date logic.
- Separates all 19 folders with no extra inventory machinery.
- Keeps the check catalog small (`file_exists`, `dir_exists`, `dir_extension`) and leaves `.fst` header checks optional for later expansion.

## Explicit non-rules in this proposal

- Folder-name date threshold (`> 2025-05-01`) is not a schema rule.
- `lineup_median.fst` is not a discriminator.
- No content checks (country lists, values) and no full table loads.

## Open review decisions before Step 3

1. Confirm schema IDs: keep `pre-lineup` and `new-lineup`, or rename.
2. Confirm the 5-check `new-lineup` bundle and 4-check `pre-lineup` absence bundle.
3. Confirm that `dir_extension` should enforce `.fst`-only under `lineup_data/` in v1.
