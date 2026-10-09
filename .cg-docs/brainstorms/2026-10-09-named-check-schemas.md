---
date: 2026-10-09
title: "Named-check schemas: definitions, generic evaluator, generated assignment"
status: decided
scope: "Deep"
artifact-schema-version: 1
chosen-approach: "Named checks in a reviewed definition file, applied by a generic evaluator"
tags: [schema, rules, classification, yaml, evaluator, extensibility]
supersedes-plan: ".cg-docs/plans/2026-10-07-pipschema-schema-evaluator.md"
---
<!-- Valid status values: decided, in-progress, abandoned -->

# Named-check schemas: definitions, generic evaluator, generated assignment

## Context

`{pipschema}` must define what a schema is, hold the rules that identify it,
and assign every vintage folder in the PIP data directory to exactly one schema.
The current focus in `compound-gpid.md` is still that definition work.

A plan already exists
(`.cg-docs/plans/2026-10-07-pipschema-schema-evaluator.md`), built from
`.cg-docs/brainstorms/2026-10-07-closed-schema-design.md`. That plan treats a
schema as a closed inventory of a vintage folder (required items, optional
items, a tracked skeleton, a reviewed ignore list, a core `_aux` guard). The
user rejected it: it is too complex, and it does not address the functionality
needed now. Nothing from that plan is implemented. The package is still the
scaffold. The plan is not to be implemented.

This session restarts the design from the functionality required now, starting
with two schemas so the definition-and-assignment system can be proved before
it is extended.

## Requirements

### R1. Two steps, one system

1. Define schemas as explicit, reviewable rules.
2. Apply those rules to every vintage folder and write one generated document
   that lists which folders belong to which schema.

The first version starts with two schemas so the system can be proved. The
system must then accept more schemas and more rules without rewriting the
classifier.

### R2. Three parts

| Part | Nature | Role |
|---|---|---|
| Definition file | Hand-written, reviewed YAML | Schemas and the checks that identify each one. Not generated. |
| Evaluator | Generic R | Loads the definitions, tests every folder against every schema, requires exactly one match. Does not name the schemas. |
| Assignment file | Generated YAML, never hand-edited | Copies the reviewed rules and lists the folders under each schema. Carries a version field. |

The evaluator does not reimplement each schema. Adding a schema that uses an
existing check type edits the definition file only. A new kind of check adds
one function to a small catalog. The classifier is not rewritten.

### R3. Match rule

A schema is the checks named in its definition. A folder matches if those
checks pass. Extra files do not fail the match unless a check says they must
be absent.

This rejects the closed-inventory match of the discarded plan, where any
tracked file outside the required-plus-optional lists failed the folder.

### R4. Starting schemas

Working names: `pre-lineup` and `new-lineup`. Names are confirmed after the
discovery step, not fixed here.

The exact checks are not fixed here. A read-only discovery step in the plan
proposes them from the vintage folders and from `{pipapi}` (the main consumer).
The user reviews the proposed checks before they are written into the
definition file.

Evidence only, not the rule set:

- `{pipapi}` `use_new_lineup_version()` (`R/create_lkups.R`) returns true when
  the folder-name date is after 2025-05-01. That date cutoff is the guess
  `{pipschema}` replaces. It is not a schema rule.
- On that branch `{pipapi}` reads `estimations/prod_refy_estimation.fst`,
  `estimations/lineup_years.fst`, and one `.fst` file per country-year under
  `lineup_data/`.
- On the scanned folders (`Y:/temp/povertyscore-data`, 19 PROD folders),
  `lineup_data/`, `prod_refy_estimation.fst`, `lineup_years.fst` and
  `lineup_dist_stats.fst` appear together only from `20250930` on, and are
  absent before. `estimations/lineup_median.fst` appears in some earlier
  folders and is not part of that split.
  Source: `.cg-docs/brainstorms/2026-10-07-closed-schema-design.md` findings
  F3, F5, F8. Those findings are evidence. The closed-world decision in that
  file is not reused.

### R5. Scope of folders

The data directory holds only PROD vintage folders. There is no PROD/INT/TEST
filter and no skipped-folder report. This is a fact about the directory, not a
relaxed rule. Every folder in the directory is classified by its contents.
Zero matches or several matches are errors, never a silent guess. A rule that
cannot be evaluated is reported, never passed.

### R6. Checks stay cheap

Allowed check types look at shape: file or directory existence, file format,
and `.fst` headers (column names and types). No full table loads. Country
lists, cell values and other content are not schema rules. Folder name and
release date are not rules. A date may be recorded as a cross-check only.

The first catalog is whatever discovery needs, starting from `file_exists`,
`dir_exists` and `fst_columns`. Discovery may add a type. It may not turn the
catalog into an inventory of every file.

### R7. Generated file

The generated file copies the reviewed rules and lists the folder names under
each schema. It is the file the charter describes: every schema, the rules
that define it, and the folders that belong to it. It is generated, never
hand-edited, deterministic, and versioned. The output path is a function
argument.

Generation stops if validation fails: a folder with zero matches, a folder
with several matches, an unreadable folder, or a definition that cannot be
loaded. No partial file is written in those cases.

### R8. Out of scope

- How `{pipapi}` later binds a version to one or more schemas. The generated
  file must stay readable for that later work. The binding is not built here.
- Routing, Docker, ITS pipelines, and any change to `{pipapi}`.
- The pairing file that links PIP releases to schemas and to `{pipapi}`
  versions.
- Implementing `.cg-docs/plans/2026-10-07-pipschema-schema-evaluator.md`.

### R9. Constraints carried from the charter

- Read-only on vintage folders. The only write is the generated assignment file.
- Same directory and same definitions always give the same file: stable
  ordering, no timestamps or machine paths in the content that decides the result.
- Existing definitions do not change meaning. Adding a schema adds a definition.
  Changing a released schema's checks needs explicit review.
- Tests use synthetic folder trees. A run on real data is manual and on a
  read-only copy. Tests do not depend on `Y:/`.
- All tests must pass.

## Approaches Considered

### Approach 1: Named checks in a reviewed definition file (chosen)

The definition file names each schema and the checks that identify it. A
generic evaluator applies those checks. A folder matches if its schema's checks
pass. Extra files do not fail it.

- Pros: matches the charter (rules as readable data, not hidden logic). A new
  schema is a reviewed data change. A new check type is one catalog function.
  Does not inventory the folder, so it stays small.
- Cons: two schemas that share every named check will both match, which is an
  error. Discovery must pick checks that actually separate them. A check type
  the catalog lacks cannot be added by editing YAML alone.
- Effort: medium for the system, plus a bounded discovery step for the first
  two schemas.

### Approach 2: Hard-coded two schemas (rejected)

The classifier is an R function that names `pre-lineup` and `new-lineup` and
branches on lineup files.

- Pros: shorter for a two-schema proof.
- Cons: a third schema means editing the classifier and its tests. Conflicts
  with the charter rule that schema rules are stored as readable data, not
  hidden logic.

### Approach 3: Closed folder inventory (rejected)

The discarded plan. A folder matches only if its tracked contents equal the
required plus optional lists. Extra tracked files fail the match.

- Pros: schemas cannot overlap by construction.
- Cons: too large for the functionality needed now. Turns every new file into
  a schema event. Already rejected by the user.

## Decision

Approach 1. The first version locks the three-part system, the named-check
match rule, and two starting schemas. It does not lock the checks themselves.
Those are proposed by a read-only discovery step and reviewed before they are
written.

The closed-inventory plan
(`.cg-docs/plans/2026-10-07-pipschema-schema-evaluator.md`) is superseded for
implementation. Its evidence about which lineup items co-occur may be reused
as input to discovery. Its match rule, ignore list, skeleton and core `_aux`
guard are not.

## Next Steps

1. `/cg-plan` from this brainstorm. The plan covers:
   - a read-only discovery step that proposes the checks for `pre-lineup` and
     `new-lineup` from the vintage folders and `{pipapi}`, for user review
     before they are written;
   - the YAML definition format and a small check catalog;
   - a generic evaluator that requires exactly one match and stops without
     writing if validation fails;
   - a generated YAML assignment file that copies the rules and lists the
     folders, with a version field;
   - synthetic-tree tests, including an unmatched folder, an ambiguous folder,
     and a folder whose check cannot be evaluated;
   - documentation of how to add a schema and how to add a check type.
2. Do not implement the closed-inventory plan.
3. Do not add a PROD filter. The data directory contains only PROD folders.
4. Leave `{pipapi}` schema binding for later work in that package.
