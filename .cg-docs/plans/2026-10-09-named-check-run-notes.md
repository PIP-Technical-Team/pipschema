---
date: 2026-10-09
plan: ".cg-docs/plans/2026-10-09-named-check-schemas.md"
step: 8
title: "Manual read-only run notes"
status: done
artifact-schema-version: 1
---

# Manual read-only run notes

## Preconditions

- Data root: `Y:/temp/povertyscore-data`
- Confirmed as a directory (`Attributes: Directory`) and treated as read-only input for this run. This is an operational read-only guarantee (no writes under `Y:/`), not an ACL-level permission proof.
- Output path intentionally outside data root:
  `C:/Users/wb621604/AppData/Local/Temp/6/kilo/schema-manual-run-2026-10-09.yml`

## Command

Run with package code loaded from current branch:

```r
devtools::load_all(quiet = TRUE)
assign_schemas(
  data_dir = "Y:/temp/povertyscore-data",
  output = "C:/Users/wb621604/AppData/Local/Temp/6/kilo/schema-manual-run-2026-10-09.yml"
)
```

## Results

- Run completed without classification errors.
- Generated YAML includes both schema rule bundles and sorted folder lists.
- Folder counts:
  - `pre-lineup`: 13
  - `new-lineup`: 6
- Total folders classified: 19.

## Boundary cross-check (not a rule)

The schema split aligns with the expected date-line evidence used during
Discovery (folders after the historical 2025-05-01 pivot are in `new-lineup`),
but folder date was not used by classification logic.

## Read-only compliance

- No writes occurred under `Y:/temp/povertyscore-data`.
- Only output artifact written was the external YAML path above.
