
<!-- README.md is generated from README.Rmd. Please edit that file -->

# pipschema

The goal of `{pipschema}` is to define PIP data-folder schemas as
reviewed YAML checks and classify each vintage folder deterministically.

## What this package does

`{pipschema}` has three parts:

1.  **Reviewed definitions** (`inst/schemas/definitions.yml`) listing
    schemas and named checks.
2.  **Generic evaluator** that applies checks to folders without
    hardcoding schema IDs.
3.  **Generated assignment file** that copies rules and lists folders
    under each schema.

Current starting schemas are `pre-lineup` and `new-lineup`.

## Why these two schemas separate

`new-lineup` requires all lineup markers:

- `lineup_data/` exists, is non-empty, and contains only `.fst` files
- `estimations/prod_refy_estimation.fst` exists
- `estimations/lineup_years.fst` exists
- `estimations/lineup_dist_stats.fst` exists

`pre-lineup` requires all four markers above to be absent.

A folder that has only some lineup markers matches neither schema and is
reported as an error.

## Match rule

A folder matches a schema when all checks named for that schema pass.
Extra files do not fail the match unless a check explicitly requires
absence.

Folder-name dates are not schema rules.

The data directory holds only PROD vintage folders, so there is no
PROD/INT/TEST filter.

## Assignment output

`assign_schemas()` writes YAML with:

- `version`
- `schemas[]` with each schema’s `id`, checks, and sorted `folders`

The package writes nothing if classification is invalid (zero match,
multiple matches, or unevaluable check).

## Extending

Two extension paths are supported:

- **Add a schema**: edit `inst/schemas/definitions.yml` (no evaluator
  rewrite).
- **Add a check type**: add it to the check registry in `R/checks.R`
  (required fields and runner function in one place).

How `{pipapi}` versions bind to schemas is out of scope for this
package.

## Minimal example

``` r
library(pipschema)

defs <- read_definitions("inst/schemas/definitions.yml")
classify_folder("path/to/one/vintage", defs)
assign_schemas(
  data_dir = "path/to/vintage-root",
  output = "schema.yml",
  definitions = defs
)
```
