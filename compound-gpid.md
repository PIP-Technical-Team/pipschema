---
project-name: "PIP Schema"
team: "PIP Technical Team"
created: "2026-10-05"
last-reviewed: "2026-10-05"
---

# PIP Schema

## Objective

{pipschema} is an R package that defines what a "schema" is for PIP data, and holds the explicit logical rules that decide which schema a data folder has. It is the single, centrally maintained source of truth for these definitions. Each schema has a name and a set of rules that identify it, based on what a vintage folder contains (which files, which tables, which columns). Given the PIP data directory (/Data), which holds many dated "vintage" folders, the package applies those rules to every folder. It then writes one central schema file with every schema, the rules that define it, and the vintage folders that belong to it. It is built for the PIP API team (DECDG / GPID, World Bank), who need a clear, reviewable and maintainable answer to "what makes a schema, and which vintages are in it".

## Key Deliverables

- R package {pipschema}, whose core is the schema definitions: for each schema, a name and the explicit logical rules that identify it (based on the contents of a vintage folder).
- A schema classification function. It applies the rules to every vintage folder in the PIP data directory and returns, for each folder, the schema it belongs to, or a clear error if it matches no schema or more than one.
- A validation step that checks the classification: every vintage folder matches exactly one schema, schemas don't overlap and don't leave gaps, and the results are consistent for folders that share a release date. It produces a readable report of any problems.
- A central schema registry file (one file at the top of /Data, or inside a schemas/ folder; exact name, location and format still to be decided). It lists every schema, the rules that define it, and the vintage folders that belong to it. The file is generated, never edited by hand.
- Tests, built on synthetic folder trees that mimic each schema, including edge cases such as an unmatched folder, an ambiguous folder and a partly complete folder.
- Documentation of the schemas and rules, so a person who isn't the author can understand why a vintage belongs to a schema, and what a developer must do to add a new schema.

## Constraints

- Exactly one schema per vintage folder. Every vintage folder must match one and only one schema. Zero matches or several matches are errors, never resolved silently.
- No silent fallbacks. If a rule can't be evaluated (missing file, unreadable file, unexpected structure), report it explicitly. Never guess a schema, and never default to a date-based assumption without saying so.
- Strict validation. The classification is checked every time it is generated: no overlaps between schemas, no unclassified folders, and a clear report of any problem. Generation of the schema file stops if validation fails.
- Read-only on the data. Vintage folders are inputs only. The package never modifies, moves or writes anything inside them. Its only output is the central schema file.
- Reproducible and deterministic. The same data directory and the same rules always give the same output: stable ordering, no timestamps or machine-specific paths inside the content that decides the result.
- Rules are explicit and reviewable. Schema rules are stored as readable definitions (data, not hidden logic) so a person who isn't the author can see why a folder belongs to a schema. Every change to a rule or a new schema is a deliberate, reviewed change.
- Existing schema definitions don't change meaning. Adding a new schema means adding a new definition. Changing an old schema's rules would reclassify past data and break reproducibility for every PIP release built on it, so it needs explicit review.
- Evidence from the folder contents, not just its name. The release date in the folder name may be used as a cross-check, but it must not be the only basis for deciding a schema.
- Efficiency. Classifying should be cheap: check whether files exist, and read file headers only when a rule needs them. Don't load full data tables. The project's charter requires code to be as efficient as possible.
- All tests must always pass. This is a project-wide rule.
- Tests don't depend on the real /Data. Use synthetic folder trees. Runs against real data are manual, and only on a read-only copy.
- Stable output format. The schema file carries a version field, so programs that read it (for example, {pipapi} deployments) can check they understand it.

## Current Focus

In order: defining what a schema is, what rules define it, and which PIP vintage belongs to which schema.
