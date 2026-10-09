---
date: 2026-10-07
title: "Closed schema design: required + optional items, tracked skeleton, reviewed ignore list"
status: decided
scope: "Standard"
artifact-schema-version: 1
chosen-approach: "Closed-world schemas over a tracked skeleton, YAML rules + reusable R evaluator"
tags: [schema, rules, classification, closed-world, yaml, persistence, discovery]
supersedes: ".cg-docs/brainstorms/2026-10-06-schema-rule-requirements.md"
---
<!-- Valid status values: decided, in-progress, abandoned -->

# Closed schema design: required + optional items, tracked skeleton, reviewed ignore list

## Context

This brainstorm **supersedes** `2026-10-06-schema-rule-requirements.md`. That
document defined a schema as a minimum checklist ("a folder matches if it has
all required items"). Reviewing it showed a flaw: a lineup folder has every item
of the older schema too, so it would match **both** schemas, breaking "exactly
one schema per folder". The fixes considered then (explicit "absent" rules, or
"most specific schema wins") were rejected: the first forces edits to released
schemas, the second is a silent resolution rule.

This session replaces matching-by-containment with **closed descriptions**
and re-tested the idea on the real data.

Data used: `Y:/temp/povertyscore-data`, **19 vintage folders**
(`20220609` to `20260922`, all PROD). The analysis started on 17 complete
folders; the two `20260922_*` folders were still being copied then (`_2017` had
no `survey_data/`, `_2021` had only 170 files). The copy has since completed
and all 19 were rescanned (F8). All inspection was read-only: file listings
and `.fst` headers only. No table was loaded.

## What this work produces, and how it is used

The output of this design is **not a one-off analysis**. It is a set of
**schema definitions (YAML files) plus a reusable R evaluator** inside
`{pipschema}`:

- The evaluator can be **run at any time** on the data directory. Each run
  scans every vintage folder, classifies it against the current definitions,
  validates the result, and regenerates the central schema file.
- **New vintage folders** are classified on the next run with no code change.
  If a new folder fits an existing schema, it is simply added to it. If it fits
  none, the run fails loudly with a per-folder report, and a person decides
  whether to fix the data, add an optional item (with a recorded reason) to an
  unreleased schema, or add a new schema.
- **Rules can be extended later** (more files, column rules, new schemas) by
  adding definitions. Released schemas are not edited in meaning.
- The same data plus the same definitions always gives the same result
  (deterministic), so the schema file can be regenerated and compared.

The analysis in this brainstorm was used only to **choose the rules**; it is
the evidence behind them, not the product.

## Requirements

### R1. A schema is a closed description

- A schema lists **required** items (must be present) and **optional** items
  (may be present or absent). Any other **tracked** item is **not allowed**.
- A folder matches a schema only if it has every required item **and** nothing
  outside required + optional. The match is exact.
- Two schemas differ by their item sets, so they separate by construction. The
  absence of an item in an older schema is implied by the closed list; no
  "absent" rules are needed.
- A folder that matches no schema is rejected loudly (unclassified). Overlaps
  are never resolved by picking a "most specific" schema.
- Adding a schema adds a definition and edits nothing else.

### R2. What is tracked (the skeleton)

Some parts of a vintage folder are content, not shape. They are not listed
item by item.

| Area | How it is tracked |
|---|---|
| Top-level entries | closed list of entries directly under the folder |
| `survey_data/`, `lineup_data/` | present/absent + file format inside (`.fst`); individual files not listed (one per survey / per country-year = content) |
| `estimations/` | closed list of files |
| `_aux/` | **required core set (integrity guard, A10)**; other `_aux` files allowed, each unreviewed one reported as a **warning** in a per-folder inventory |
| Columns | **not in v1**; can be added later in the same closed style |

Core `_aux` set (13 files, see A10 for the rule and its basis):
`missing_data.fst`, `country_list.fst`, `countries.fst`, `regions.fst`,
`pop.fst`, `pop_region.fst`, `poverty_lines.fst`, `country_profiles.rds`,
`censored.rds`, `interpolated_means.fst`, `survey_means.fst`, `framework.fst`,
`survey_metadata.rds`.

Why `_aux/` is not closed: its listing changes almost every release and would
split folders of the same release date into different schemas (see Findings).

### R3. Reviewed ignore list

Items that are not part of the vintage's structure go on an explicit,
recorded, reviewable ignore list:

- `*.qs`, `*.dta`, `*.duckdb` (duplicate formats / caches; consumers read `.fst`/`.rds`)
- `data_update_timestamp.txt`
- `_vintage/` folders (**purpose unconfirmed**; ignored for now; no consumer
  found in `{pipapi}`; to be confirmed with the data team)

Changing the ignore list is a reviewed change, like a rule change.

### R4. Optional items are an exception, with a recorded reason

- Optional is used **sparingly**. Without it, every harmless extra file would
  create a new schema (and a new container). With too much of it, schemas start
  to overlap (caught by the check in R6).
- Every optional item must carry a recorded reason.

### R5. Persistence principle

> A structural difference defines a schema only if it marks a **lasting**
> layout change. A difference that appears and later disappears is not a
> schema boundary.

This principle must be written into the rules documentation of `{pipschema}`.

Applied case: `estimations/lineup_median.fst` is **optional in the base
schema** and **not listed in the lineup schema**. Reason recorded: persistence.
It appears only in the folders from 2022-09 to 2023-09 and in none before or
after, so it does not mark a lasting layout change.
**Action:** confirm with the data team that it was a dropped output.

### R6. Three checks

1. **Definition-time (no data needed):** two schemas can overlap only if each
   one's required items are allowed by the other (allowed = required +
   optional). Simple set comparison, run whenever definitions change. Overlap =
   error.
2. **Data-time:** every real folder matches exactly one schema. Zero or several
   = error, with a readable per-folder report.
3. **Release consistency (data-time, reported):** folders that share the same
   8-digit release-date prefix are expected to belong to the same schema. A
   violation is reported as a validation problem; it is not assumed. The
   prefix is used only to group folders for this check, never to decide a
   schema. Whether a violation blocks the run is settled in the plan. Today it
   holds for all 10 release dates (F8).

### R7. Carried over from the 2026-10-06 brainstorm (still valid)

- Rules stored as **YAML files** (one per schema) + **one R evaluator**.
- Cheap checks first; never load full tables; read-only on the data.
- Never decide by folder name or date (cross-check only).
- Any rule that cannot be evaluated is reported, never silently passed or failed.
- Deterministic output.
- `pg_lnp`, `pg_svy`, `metaregion`: allowed `_aux` extras, **flagged** in the
  report. Reasons are in A10 (additive `_aux` growth; the `pg_*` files differ
  within a release). The earlier reason "pipapi tolerates their absence" is no
  longer the basis.

## Findings (evidence from the real folders)

### F1. Exact matching over-splits

| Basis for grouping | Groups for 17 folders |
|---|---|
| Exact file list (with digits/country codes masked) | 12 |
| Exact columns + types of 47 `.fst` tables | 17 (every folder unique) |
| Closed list of all 91 tracked items, no optional | 11 |
| **Closed skeleton (this design)** | **3**, then **2** with one optional item |

### F2. `_aux/` varies by release and within a release

Extra (non-core) `_aux` files per folder, after the ignore list:

| Folders | Extra `_aux` files |
|---|---|
| `20220609_2011`, `20220909_*` | 16 |
| `20230328_*`, `20230919_2011` | 18 |
| `20230919_2017` | 20 |
| `20240326_*` | 19 |
| `20240627_2011` | 20 |
| `20240627_2017` onward | 22 |

Same release, different extras: `20230919` (18 vs 20), `20240627` (20 vs 22,
including `pg_lnp`/`pg_svy` only in `_2017`). Closing `_aux/` would split these
pairs. All 9 core `_aux` tables are present in all 17 folders.

### F3. The skeleton gives 3 groups, all release-consistent

| Group | Folders | Distinguishing skeleton items |
|---|---|---|
| 1 | `20220609_2011`, `20240326_*`, `20240627_*`, `20250401_*` (7) | base skeleton |
| 2 | `20220909_*`, `20230328_*`, `20230919_*` (6) | base + `estimations/lineup_median.fst` |
| 3 | `20250930_*`, `20260324_*` (4) | base + `lineup_data/` (`.fst`), `estimations/prod_refy_estimation.fst`, `lineup_years.fst`, `lineup_dist_stats.fst` |

Top-level: only `_aux/`, `estimations/`, `survey_data/` (+ `lineup_data/` in
group 3); no root files remain after the ignore list. `survey_data/` holds only
`.fst`.

### F4. `lineup_median.fst` is a transient item

- Present only in 2022-09 to 2023-09 (6 folders); absent in 2022-06 and from
  2024-03 on. Group 1 is therefore non-contiguous in time.
- Never referenced in `{pipapi}` code or git history (supporting fact only; the
  decision rests on persistence, R5).
- Making it optional in the base schema merges groups 1 and 2.

### F5. Resulting candidate schemas (not yet named)

| Candidate | Folders | Required (beyond common skeleton) | Optional |
|---|---|---|---|
| Base (pre-lineup) | 13: `20220609` to `20250401` | none | `estimations/lineup_median.fst` |
| Lineup | 6: `20250930`, `20260324`, `20260922` | `lineup_data/` (`.fst`), `prod_refy_estimation.fst`, `lineup_years.fst`, `lineup_dist_stats.fst` | none |

The two candidates cannot overlap: lineup items are not allowed in the base
schema, and the lineup required items are absent from base folders. The
boundary agrees with, but is not defined by, `{pipapi}`'s date cutoff
(`use_new_lineup_version()`, > 2025-05-01).

## Approaches Considered

### Approach 1: Closed descriptions over a tracked skeleton (chosen)
Required + optional + "nothing else" on a small skeleton; `_aux/` core-required
with warned extras; reviewed ignore list.
- Pros: exactly-one by construction; no edits to released schemas; damaged or
  partial folders fail loudly; overlap checkable without data; 2 coarse schemas.
- Cons: any new item in the tracked skeleton fails loudly until reviewed (more
  review per release); optional items need discipline.

### Approach 2: Minimum checklist + "absent" rules (rejected)
- Cons: adding a schema forces edits to older schemas.

### Approach 3: Minimum checklist + "most specific wins" (rejected)
- Cons: a silent resolution rule; conflicts with "no silent fallbacks".

### Approach 4: Closed list of every item, no skeleton (rejected)
- Cons: 11 groups for 17 folders; splits same-release folders.

## Decision

Adopt **closed schema descriptions** over a **tracked skeleton** (R1-R3), with
optional items as a reasoned exception (R4) governed by the **persistence
principle** (R5), and three checks (R6). Candidate result: **2 schemas** (base,
lineup) for the **19 folders**: 13 base, 6 lineup, each matching exactly one
(F8). The core `_aux` set is an integrity guard, not a discriminator (A10). The
deliverable is reusable definitions + evaluator, run whenever the data changes.

## Addendum: second review (2026-10-07)

Added after review, before `/cg-plan`. These items are requirements for the
plan unless marked as a decision still to confirm.

### A1. Scope: PROD folders only

- `{pipschema}` classifies only vintage folders whose name ends in `_PROD`.
- `INT` and `TEST` folders are out of scope: skipped, listed once in the report
  as "skipped, not PROD". Never errors, never counted as unclassified.
- `{pipapi}` is not changed: `create_versioned_lkups()` keeps loading any folder
  that matches its pattern, so local testing with TEST/INT folders still works.
  Deployed containers pass an exact list of PROD names taken from the registry.
- Documentation line: *Scope is PROD only. In deployed containers INT/TEST are
  not available, because only PROD folders exist on the server.*
- A local non-PROD folder has no schema. If `{pipapi}` later becomes
  single-schema per release, ensuring such a folder has the right structure is
  the developer's job.
- The folder name decides only **scope**, never the schema (R7 still holds).

### A2. Stability of past classifications

- A committed record of folder → schema (the registry, A7) is kept in version
  control.
- Every run compares its result with that record. A run that **changes the
  schema of a previously classified folder fails**, unless an explicit, logged
  change (reason, date, reviewer) authorises it.
- **Decision to confirm in the plan: when is a schema "released"?** "Never
  edited in meaning" starts there. Proposed: a schema is released when the
  first registry assigning at least one folder to it is committed to the
  default branch. Before that, its definition may change (including adding
  optional items); after that, only a new schema may be added.

### A3. Folders that fit no schema

- **Decision to confirm in the plan.** Two behaviours:
  - (a) stop the whole run, write nothing;
  - (b) write the registry with the classified folders plus an explicit
    `unclassified` section (folder, reason, failed items), and exit with a
    failing status.
- Operational impact: one incomplete folder (such as the `20260922` copy in
  progress) should not block the update for every other folder. That favours
  (b). Proposed: **(b)**, provided a previously classified folder never moves
  into `unclassified` silently (that is an A2 failure).
- Hard errors that stop the run in either case: overlapping definitions (R6.1),
  a folder matching several schemas, a changed past classification (A2), an
  unreadable data directory.

### A4. Completeness is not schema membership

- Presence-only checks of `survey_data/` cannot detect a truncated copy.
  Example: while it was being copied, `20260922_2021` had 170 files in total
  and no `survey_data/`; a copy stopped part-way through `survey_data/` would
  have the folder but too few files. After the copy completed, no folder is
  missing a survey file (F8).
- `{pipapi}` filters its lookup tables to survey files that exist
  (`cache_id %in% paths_ids` in `create_lkups()`), so missing files are dropped
  silently and numbers come out incomplete.
- Record as an **adjacent integrity check**, not a schema rule: either a separate
  validation step in `{pipschema}` (e.g. every `cache_id` in
  `prod_svy_estimation.fst` has a file in `survey_data/`) or a data-pipeline
  task. Which one is open. It is **not** folded into the schema rules.

### A5. Sample

- The data directory holds **19 folders, all PROD**, all matching the
  `{pipapi}` vintage-name pattern (F7). The "~200 folders" figure in early
  notes was an estimate.
- The `20260922_*` copy has completed and was rescanned: both folders are
  classified as lineup, and the 17 earlier classifications are unchanged (F8).
- To confirm: these 19 are the full set expected.

### A6. Known limit: the skeleton is file-level only

- Column-level changes inside files with the same name are not detected by v1.
- Cheap check done (header metadata only, both PPP versions of each release):
  column names of 15 key tables (all `estimations/*.fst` + core `_aux` `.fst`)
  between `20250930` and `20260324` (F6). Identical, except `_aux/pop.fst`,
  where `20260324` has one more year column (`2026`). `pop.fst` is a wide table
  with one column per year, so this is content growth, not a shape change. The
  file-level skeleton is safe for now.
- Record the limit in the documentation, and note that wide year-column tables
  (`pop`, likely also `gdp`, `pce`, `cpi`) will need a pattern-based column rule
  if column rules are added later.

### A7. Two separate artifacts

| Artifact | Nature | Content |
|---|---|---|
| Schema definitions | hand-written, reviewed (YAML, in the package) | schemas, required/optional items with reasons and folder ranges, ignore list, core `_aux` set |
| Registry | generated, committed, never hand-edited | folder → schema, skipped non-PROD, unclassified, warnings summary, format version |

- The registry is what `{pipapi}`'s `main.R` reads. Requirement: "list of
  vintage folder names for schema X" must be easy to get from plain R with few
  dependencies (ideally base R). The exact format is open, but must meet this.

### A8. Decisions already made (unchanged)

- `estimations/lineup_median.fst`: optional in the base schema, not listed in
  the lineup schema. Reason: persistence (appears only 2022-09 to 2023-09), not
  "no consumer uses it".
- A lineup folder containing it is reported as unclassified.
- The persistence principle goes into the documentation as a rule for people.
  Each optional item records a **reason** and the **folder range** where it
  occurs.
- To confirm with the data team: that `lineup_median.fst` was a dropped output.
  `_vintage/` stays on the ignore list, purpose unconfirmed.
- Schemas are named now that the re-scan is done (names are for the plan to
  propose; none are fixed here).
- `lineup_median.fst` is not read by `{pipapi}` today; that is a side fact, not
  the reason (the reason is persistence).

### A9. Open, not for the first version

- Where and when `{pipschema}` runs: who triggers it when a new vintage arrives,
  and on which machine. Undecided. Keep dependencies small.

### A10. The core `_aux` set is an integrity guard, not a schema discriminator

- Purpose: catch a damaged or incomplete folder. A folder missing a core table
  is unclassified. The core set does not separate schemas: all 13 files are
  present in all 19 folders, so it plays no part in telling base from lineup.
- **Membership rule:** a table is core if it (a) is present in **every** folder
  classified under the schema and (b) is read by name by `{pipapi}`. A table
  that is missing from some folders of a schema is never core.
- Do **not** state the rule as "a file defines a schema only if `{pipapi}`
  reads it and breaks without it". Schema rules are not limited to what
  `{pipapi}` reads today (`docs/context.md` section 4a); `{pipapi}`'s reads are
  evidence for the integrity guard only.
- Basis corrected. The earlier statement "read by `create_lkups()`" was
  incomplete. Reads by name in `{pipapi}`:
  - `create_lkups()`: `missing_data`, `country_list`, `countries`, `regions`,
    `pop`, `pop_region`, `country_profiles.rds`, `poverty_lines`,
    `censored.rds`;
  - `valid_years()` (called from `create_lkups()`): `interpolated_means`,
    `survey_means`;
  - request time: `framework` (`utils-stats.R:122`), `survey_metadata.rds`
    (`ui_svy_meta()`).
- **The core set is not exhaustive.** A name search cannot find dynamic reads:
  `get_aux_table_ui()` passes the table name as a variable, and the generic aux
  endpoint serves any `_aux/*.fst`. `cpi`, `gdp`, `pce`, `ppp` never appear by
  name.
- **Changing the core set is a reviewed schema edit**, because it changes what
  the schema accepts.
- `pg_svy`, `pg_lnp`, `metaregion` stay **allowed, flagged extras** (present in
  9, 9 and 10 of 19 folders). Reasons:
  1. they are additive `_aux` growth;
  2. the `pg_*` files differ **within a release** (`20240627_2017` has them,
     `20240627_2011` does not); requiring them would split same-release
     folders. `metaregion` is present in both `20240627` folders, so for it
     only reason 1 applies.
- **Compatibility fact for the later pairing work (out of scope here):**
  `{pipapi}` reads `pg_svy` directly (`ui_country_profile.R:126`) and
  `metaregion` directly (`wld_lineup_year()`, `valid_years.R`), without
  handling absence. A `{pipapi}` version with those endpoints cannot safely
  serve folders that lack the files, even though both are in the same schema.

### A11. Accepted cost: new `estimations/` files

- `estimations/` is a closed list. A new file there in a future vintage makes
  the folder unclassified until a reviewed definition change (a new schema, or
  an optional item added before release). The cost is accepted: `estimations/`
  holds the pipeline's main outputs, so a new file there is rarely harmless,
  and failing loudly is the wanted behaviour.

### F6. Column-name check, lineup folders (for A6)

| Table | Distinct column-name sets across `20250930_*`, `20260324_*` |
|---|---|
| All 11 `estimations/*.fst` (incl. `prod_refy_estimation`, `lineup_years`, `lineup_dist_stats`) | 1 (names and types identical) |
| Core `_aux` `.fst`: `countries`, `country_list`, `missing_data`, `pop_region`, `poverty_lines`, `regions` | 1 |
| `_aux/pop.fst` | 2: `20260324` adds year column `2026` (content growth) |

### F8. Rescan of all 19 folders (after the `20260922` copy completed)

Classified with the closed definitions: base = base skeleton + optional
`lineup_median.fst`; lineup = base skeleton + the 4 lineup items.

| Check | Result |
|---|---|
| Folders | 19, all PROD |
| Base schema | 13 folders (`20220609` to `20250401`) |
| Lineup schema | 6 folders (`20250930`, `20260324`, `20260922`) |
| Folders matching exactly one schema | 19 of 19 (none match both or neither) |
| Existing 17 classifications changed | none |
| Release consistency (R6.3) | 10 release dates, each in one schema (9 with two folders, 1 with one) |
| 13 core `_aux` files present | all 19 folders |
| Survey files vs `prod_svy_estimation` `cache_id` | no folder missing a file (2,542 in each `20260922` folder); some folders have extra files (up to 30), not an error |
| `lineup_median.fst` | still only in `20220909` to `20230919` (6 folders) |
| Extra (non-core, non-ignored) `_aux` files | 12 in the oldest folders, 18 from `20240627_2017` onward; reported as warnings |
| Lineup column check (35 tables, `20260324` vs `20260922`) | identical except `_aux/ppp.fst`, whose year column is named `2017` or `2021` by PPP version |
| `20260922` root files | `cache.duckdb`, `data_update_timestamp.txt` (both on the ignore list) |

The F2 table above counts extras against the earlier 9-file core set; with the
13-file core set each count is 4 lower.

### F7. Folder identities (for A1, A5)

All 19 folders end in `_PROD` and match
`^\d{8}_\d{4}_\d{2}_\d{2}_(PROD|TEST|INT)$`. No INT/TEST folders exist today, so
the A1 skip path is exercised only by synthetic tests.

## Open Questions

1. Confirm the 19 folders are the full expected set (A5).
2. Data-team confirmation: `lineup_median.fst` was a dropped output. `_vintage/`
   stays unconfirmed and ignored (A8).
3. Definition of a "released" schema (A2): proposal to confirm.
4. Behaviour for unclassified folders (A3): proposal (b) to confirm.
5. Completeness check: `{pipschema}` validation step or data-pipeline task (A4).
6. Schema names and IDs (after re-scan).
7. Exact YAML syntax (including where the ignore list and core `_aux` set live).
8. Registry format and location, under the A7 "plain R" requirement; release
   definition; meaning-only changes (known limit).
9. Column-level rules: scope and timing after v1 (A6).
10. Where and when `{pipschema}` runs (A9).
11. `{pipapi}` notes (out of scope): hard reads of `pg_svy` and `metaregion`;
    silent empty results from `get_pg_table()` / `get_metaregion_table()`;
    silent dropping of missing survey files (A4).

## Next Steps

1. Confirm with the data team: `lineup_median.fst` and the expected full
   folder set.
2. Re-scan done (F8); repeat on any new vintage without changing existing
   classifications.
3. `/cg-plan` from this brainstorm, covering: PROD scope filter and skip report
   (A1); YAML definitions; evaluator; definition-time overlap check and
   data-time exactly-one check (R6); stability check against the committed
   registry with a change log (A2); unclassified handling (A3); registry as a
   separate generated artifact readable from plain R (A7); per-folder
   inventory/warning report; synthetic-folder tests (including INT/TEST,
   truncated and partial folders); documentation (PROD scope, persistence
   principle, optional-needs-reason-and-range, file-level-only limit). Settle
   the A2 and A3 proposals inside the plan.
4. Decide where the completeness check lives (A4).
5. Name the schemas after the re-scan.
