---
project-name: "PIP Schema"
team: "PIP Technical Team"
created: "2026-10-05"
last-reviewed: "2026-10-09"
---

# PIP Schema

## Objective

{pipschema} is an R package that defines what a "schema" is for PIP data, and holds the explicit logical rules that decide which schema a data folder has. It is the single, centrally maintained source of truth for these definitions. A schema is a name plus the named checks that identify it, based on the shape of a vintage folder (which files and directories exist, their format, and, when a check needs it, table headers). It is not an inventory of every file in the folder. Given the PIP data directory (/Data), which holds only PROD vintage folders, the package applies those checks to every folder. It then writes one generated schema file that copies the rules and lists the vintage folders that belong to each schema. It is built for the PIP API team (DECDG / GPID, World Bank), who need a clear, reviewable and maintainable answer to "what makes a schema, and which vintages are in it". How {pipapi} later binds a version to one or more schemas is outside this package.

## Key Deliverables

- A reviewed schema definition file (YAML, in the package): for each schema, a name and the named checks that identify it. Hand-written, never generated. The first schemas are pre-lineup and new-lineup; their exact checks are proposed from the vintage folders and from {pipapi}, then reviewed before they are written.
- A generic classification function. It loads the definitions, applies the checks to every vintage folder, and returns the schema a folder belongs to, or a clear error if it matches none or more than one. It does not name the schemas. Adding a schema edits the definition file. Adding a kind of check adds one function to a small catalog.
- A validation step that checks the classification: every vintage folder matches exactly one schema, and any check that cannot be evaluated is reported. It produces a readable report of any problems. Generation of the schema file stops if validation fails.
- One generated schema file (YAML, path given as an argument). It copies the reviewed rules and lists the vintage folders that belong to each schema. The file is generated, never edited by hand, and carries a version field.
- Tests, built on synthetic folder trees that mimic each schema, including an unmatched folder, an ambiguous folder, and a folder whose check cannot be evaluated.
- Documentation of the schemas and rules, so a person who isn't the author can understand why a vintage belongs to a schema, and what a developer must do to add a schema or a check type.

## Constraints

- Exactly one schema per vintage folder. Every vintage folder must match one and only one schema. Zero matches or several matches are errors, never resolved silently.
- No silent fallbacks. If a rule can't be evaluated (missing file, unreadable file, unexpected structure), report it explicitly. Never guess a schema, and never default to a date-based assumption without saying so.
- Strict validation. The classification is checked every time it is generated: no overlaps between schemas, no unclassified folders, and a clear report of any problem. Generation of the schema file stops if validation fails.
- Read-only on the data. Vintage folders are inputs only. The package never modifies, moves or writes anything inside them. Its only output is the central schema file.
- Reproducible and deterministic. The same data directory and the same rules always give the same output: stable ordering, no timestamps or machine-specific paths inside the content that decides the result.
- Rules are explicit and reviewable. Schema rules are stored as readable definitions (data, not hidden logic) so a person who isn't the author can see why a folder belongs to a schema. Every change to a rule or a new schema is a deliberate, reviewed change.
- Existing schema definitions don't change meaning. Adding a new schema means adding a new definition. Changing an old schema's rules would reclassify past data and break reproducibility for every PIP release built on it, so it needs explicit review.
- Evidence from the folder contents, not its name. The release date in the folder name is not a schema rule. It may be recorded as a cross-check only.
- Named checks, not a closed inventory. A folder matches a schema when the checks named for that schema pass. Extra files do not fail the match unless a check says they must be absent.
- The data directory holds only PROD vintage folders. There is no PROD/INT/TEST filter. Every folder in the directory is classified.
- Efficiency. Classifying should be cheap: check whether files exist, and read file headers only when a rule needs them. Don't load full data tables. The project's charter requires code to be as efficient as possible.
- All tests must always pass. This is a project-wide rule.
- Tests don't depend on the real /Data. Use synthetic folder trees. Runs against real data are manual, and only on a read-only copy.
- Stable output format. The schema file carries a version field, so programs that read it (for example, {pipapi} deployments) can check they understand it.

## Current Focus

Prove the named-check system on two schemas, pre-lineup and new-lineup. First propose the checks from the vintage folders and from {pipapi}, and review them before they are written. Then build the definition file, the generic evaluator, and the generated schema file. The closed-inventory plan (`.cg-docs/plans/2026-10-07-pipschema-schema-evaluator.md`) is not the current direction. Design source: `.cg-docs/brainstorms/2026-10-09-named-check-schemas.md`.
