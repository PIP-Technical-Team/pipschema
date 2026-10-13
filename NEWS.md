# pipschema 0.0.0.9000

## Features

- Add YAML schema definitions for `pre-lineup` and `new-lineup` in `inst/schemas/definitions.yml`.
- Add definition loading and validation via `read_definitions()`.
- Add check catalog (`file_exists`, `dir_exists`, `dir_extension`, `fst_columns`) and folder classification via `classify_folder()`.
- Add assignment writer via `assign_schemas()` that emits deterministic YAML and fails fast on unmatched/ambiguous/unevaluable folders.

## Tests

- Add synthetic-tree tests for helper creation, definition validation, check behavior, classifier behavior, and assignment writer failure/success semantics.
