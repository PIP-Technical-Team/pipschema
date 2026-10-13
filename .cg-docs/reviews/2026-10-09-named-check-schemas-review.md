---
date: 2026-10-09
depth: full
type: standard
plan: .cg-docs/plans/2026-10-09-named-check-schemas.md
findings:
  P0.1: open
  P1.1: open
  P1.2: fixed
  P1.3: fixed
  P1.4: fixed
  P1.5: open
  P1.6: open
  P1.7: open
  P2.1: fixed
  P2.2: fixed
  P2.3: open
  P2.4: open
  P2.5: open
  P2.6: open
  P2.7: fixed
  P2.8: open
  P2.9: open
  P2.10: open
  P3.1: open
  P3.2: fixed
  P3.3: open
  P3.4: open
  P3.5: open
  P3.6: open
---

# Review Report

**Review mode**: full
**Resolved via**: config `review-depth: thorough` (local.md), confirmed by auto risk-class routing — this diff changes schema-definition/validation logic, matching the `security-risk` trigger ("schema changes") in `.kilo/shared/review-routing.contract.md`.
**Files reviewed**: 19 (11 modified, 8 new, uncommitted working-tree diff on `feat/schema-discovery`)
**Findings**: 25 (P0: 1, P1: 7, P2: 10, P3: 6) — Fixed this session: 8

Agents dispatched: `@cg-code-quality`, `@cg-testing`, `@cg-documentation`, `@cg-version-control`, `@cg-reproducibility`, `@cg-performance`, `@cg-architecture`, `@cg-data-quality`, `@cg-learnings-researcher`, `@cg-adversarial`.

Brain: `.cg-docs/BRAIN.md` does not exist — skipped (no project brain built yet).

`.Rbuildignore` already excludes `.cg-docs/` — no action needed.

---

### P0 — BLOCKING (immediate remediation required)

- **[P0.1]** [cg-reproducibility, cg-adversarial, cg-architecture] `R/checks.R:22-31` — `get_check_registry()` reads a process-global `getOption("pipschema.check_registry_override")` on every check evaluation, in the **production** code path (not only tests). `cg-adversarial` proved live that `utils::modifyList()` lets an override **silently replace the runner of an existing built-in type** (e.g. `file_exists`) while the entry's `required_fields` stay unvalidated/untouched, so `read_definitions()`'s validation passes unchanged while `classify_folder()`'s actual pass/fail logic is completely hijacked — undetectably, with no trace in the generated YAML. Any code in the same R session (a `.Rprofile`, another package, a prior test that errors before `withr`/`on.exit` restores the option, or a bare `options()` call) can corrupt classification for every subsequent, unrelated call to `assign_schemas()`/`classify_folder()`/`read_definitions()`. This directly violates the charter's "same data directory and same rules always give the same output" and is a silent-incorrect-results risk, not merely a style concern.
  **Why**: Global mutable state with no validation, no scope restriction, and no production-vs-test gate is unsafe in a package meant to be called from long-lived sessions (Shiny, plumber, batch jobs, interactive RStudio).
  **Fix** (two viable approaches, pick one):
  1. **Remove the global option entirely.** Thread the registry as an explicit parameter instead: `run_check(check, base_path, registry = check_registry())`, `required_fields_for_check_type(check_type, registry = check_registry())`; have `classify_folder()` compute the registry once and pass it down. Tests inject a custom registry directly as an argument rather than through global state.
  2. **Keep an injection seam, but make it safe**: convert it to `testthat::local_mocked_bindings()`/`with_mocked_bindings()` on `check_registry()` itself (automatically scoped, cannot leak across tests or into production code paths), and delete the `pipschema.check_registry_override` option.
  If the option must be kept for any reason: validate every override entry has both `required_fields` (character vector) and `runner` (`is.function()`); refuse to override keys that already exist in `check_registry()` (closing the "hijack a built-in type" vector); and gate it behind a second, explicit opt-in flag so it can never activate from a stray `options()` call.
  **This also requires reworking** the `"registry-only check type is accepted by loader and classifier"` test in `tests/testthat/test-definitions.R:119-161`, which currently depends on this exact mechanism.
  **Tag**: [manual] — architectural decision needed before applying.

### P1 — CRITICAL (must fix before merge)

- **[P1.1]** [cg-adversarial, cg-data-quality] `R/checks.R:56-138` (`check_file_exists`, `check_dir_exists`, `check_dir_extension`, `check_fst_columns`) — Path traversal via unsanitized `check$path`. `cg-adversarial` confirmed live that `check$path = "../../secret/passwords.txt"` resolves `file.exists()` to `TRUE` against a file outside the vintage folder being classified. `check_dir_extension()`'s `list.files()` and `check_fst_columns()`'s `fst::metadata_fst()` have the same exposure. `assign_schemas()`/`read_definitions()` accept an arbitrary `definitions` object/file, not only the shipped `inst/schemas/definitions.yml`, so a schema authored from a less-trusted source (or a typo like `estimations/../../../secret.fst`) can probe for existence of, or read FST headers from, files anywhere the R process can read.
  **Why**: Directory-traversal / information-disclosure primitive reachable through reviewed-but-not-bullet-proofed YAML input.
  **Fix**: Resolve `target <- normalizePath(file.path(base_path, check$path), winslash = "/", mustWork = FALSE)` and `base <- normalizePath(base_path, winslash = "/", mustWork = TRUE)` once (centrally, e.g. in `run_check_with_registry()` or in `validate_check()` at load time), and reject the check (`stop()` or `passed = FALSE` with a clear "path escapes base directory" reason) unless `startsWith(target, paste0(base, "/"))`. Prefer validating at `read_definitions()` load time too, so an escaping path is rejected before any classification run, not just at check-run time.
  **Tag**: [manual] — needs a decision on where validation is centralized (checks.R vs definitions.R) before applying.

- **[P1.2]** [cg-reproducibility] `R/assign.R:60`, `R/checks.R:27`, `R/checks.R:123` — `stats::setNames`, `utils::modifyList`, and `fst::metadata_fst` are called via `::` but `stats`/`utils` were not declared in `DESCRIPTION` `Imports`, which `R CMD check` flags and which breaks dependency-closure tooling (`renv::dependencies()`, `pak`). (Note: `check_fst_columns()` already correctly guards `fst` with `requireNamespace("fst", quietly = TRUE)`, so the CRAN-Suggests-runtime-use concern the agent also raised does **not** apply — that part of the original finding was already satisfied by existing code and needed no change.)
  **Fix**: Added `stats` and `utils` to `Imports` in `DESCRIPTION`.
  **Status**: ✅ Fixed this session. `devtools::check()` still 0 errors / 0 warnings after the change.
  **Tag**: [safe_auto] — applied.

- **[P1.3]** [cg-reproducibility] `R/assign.R` — `sort()`/`order()` on character schema IDs and folder names used R's default locale-dependent collation (not byte/C-locale), so the same data and same rules could sort differently across OS/locale combinations, undermining "same data + same rules => same output" across machines even though same-session byte-identical output is already tested.
  **Fix**: Switched to `method = "radix"` (locale-independent, byte-wise ordering) in `normalize_schema_for_output()`'s `folders` sort, the `dirs` sort in `assign_schemas()`, and the `schemas_sorted` `order()` call.
  **Status**: ✅ Fixed this session. Full suite still passes (90/90).
  **Tag**: [safe_auto] — applied. *(Follow-up idea, not applied: a cross-locale regression test via `withr::with_locale()` would strengthen this further — logged as advisory follow-up, not added now due to portability uncertainty across Windows/Linux R builds.)*

- **[P1.4]** [cg-testing] `.cg-docs/plans/2026-10-09-named-check-schemas.md:153` (Testing Strategy: "Assert modification times... unchanged after classify **and after a failed assign**") was only partially covered: the unevaluable-check failure path had an mtime assertion, but the unmatched-folder and ambiguous-match failure paths did not.
  **Fix**: Added mtime-preservation assertions (snapshot before/after) to both `"assign_schemas writes nothing on unmatched folder"` and `"assign_schemas writes nothing on ambiguous match"` in `tests/testthat/test-assign.R`.
  **Status**: ✅ Fixed this session.
  **Tag**: [safe_auto] — applied.

- **[P1.5]** [cg-documentation] `R/assign.R`, `R/definitions.R`, `R/classify.R` — Missing `@examples` on all three exported functions (`assign_schemas()`, `read_definitions()`, `classify_folder()`), required by the project's documentation convention.
  **Why**: Package users have no runnable usage reference for the three public entry points.
  **Fix**: Add `@examples` (or `\dontrun{}`) blocks to each roxygen comment, e.g. for `read_definitions()`: `@examples \dontrun{ defs <- read_definitions("inst/schemas/definitions.yml") }`.
  **Tag**: [manual] — content authoring, left for explicit approval.

- **[P1.6]** [cg-documentation] `R/classify.R:6`, `R/assign.R:39` — `@return` docs for `classify_folder()` and `assign_schemas()` only describe the success path; neither mentions that the function `stop()`s on zero/multiple matches (`classify_folder`) or on missing `data_dir`, empty schema list, no child directories, or per-folder classification failure (`assign_schemas`) — even though "writes nothing if classification is invalid" is advertised as a core contract in README.
  **Fix**: Extend each `@return` (or add a `@section Errors:`) to enumerate the error conditions.
  **Tag**: [manual] — content authoring, left for explicit approval.

- **[P1.7]** [cg-version-control] (whole working tree) — This diff mixes three unrelated logical changes: (1) the phase-3 feature (`R/assign.R`, new `man/*.Rd`, `test-assign.R`, `inst/schemas/definitions.yml`, `NEWS.md`), (2) the check-registry refactor (`R/checks.R`, `R/definitions.R` dispatch wiring, `test-definitions.R` registry test), and (3) documentation/process fixes (`README.Rmd`/`README.md`, `DESCRIPTION`, `.cg-docs/*`, `roadmap.json`).
  **Why**: A single commit spanning a feature, an internal refactor, and doc/process bookkeeping makes `git bisect`/review/revert harder.
  **Fix**: Split into at least 3 commits when committing, e.g. `refactor(checks): replace switch dispatch with check registry`, `feat(assign): add schema assignment and folder classification`, `docs: update README and roadmap status for phase 3 completion`.
  **Tag**: [manual] — process recommendation for the next commit, not a code change.

### P2 — IMPORTANT (should fix)

- **[P2.1]** [cg-data-quality] `R/definitions.R` (`validate_check()`), `R/assign.R` (`normalize_schema_for_output()`) — No scalar/type validation for `check$path`/`extension`/`columns` or `schema$description`; a malformed YAML value (e.g. a sequence instead of a scalar) previously passed required-field presence checks and could silently vectorize downstream (garbled multi-element error messages, a `"the condition has length > 1"` crash on newer R, or a vacuous always-pass for `fst_columns` when `columns: []`).
  **Fix**: Added `field_shape_validators` + `validate_field_shapes()` in `R/definitions.R` (enforces scalar non-empty `path`/`extension`, scalar logical `present`, non-empty character `columns`), a stricter scalar/non-empty check on `description` in `read_definitions()`, and a matching defensive guard in `normalize_schema_for_output()` for callers that bypass `read_definitions()`. Added 4 new tests covering non-scalar `description`, non-scalar `path`, empty `columns`, and the `assign_schemas()`-level bypass guard.
  **Status**: ✅ Fixed this session. Full suite passes (90/90); error messages still name the file, schema id, and field per existing convention.
  **Tag**: [safe_auto] — applied (base R only, no new dependency).

- **[P2.2]** [cg-testing] `tests/testthat/test-assign.R` — No test for an empty `data_dir` (zero child directories), even though `assign.R` has an explicit, untested error path for it.
  **Fix**: Added `"assign_schemas errors for empty data_dir before write"`.
  **Status**: ✅ Fixed this session.
  **Tag**: [safe_auto] — applied.

- **[P2.3]** [cg-testing] `tests/testthat/test-assign.R` — No test for nested/multi-level subfolders under `data_dir` confirming the plan's "listing is one level deep" constraint and that deeper nesting inside a vintage folder doesn't break path resolution for checks like `dir_extension`.
  **Fix**: Add a test with a nested subdirectory inside a vintage folder and a sibling test confirming only immediate children of `data_dir` are enumerated.
  **Tag**: [advisory] — logged, not applied (coverage gap, not a bug).

- **[P2.4]** [cg-documentation] `NEWS.md` — Omits the check-registry refactor (and its `pipschema.check_registry_override` extension point) and the now-mandatory schema `description` field as a validation-behavior change.
  **Fix**: Add bullets describing the registry refactor and the mandatory `description` field. (Should be revisited once P0.1's resolution direction is chosen, since the override mechanism's final shape may change what NEWS.md should say.)
  **Tag**: [manual] — content authoring, left for explicit approval; depends on P0.1's outcome.

- **[P2.5]** [cg-code-quality] `R/checks.R:56-86` — `check_file_exists` and `check_dir_exists` are near-duplicate implementations (same present/expected logic, differing only in the existence predicate and noun).
  **Fix**: Extract a shared `check_presence(check, base_path, exists_fn, noun)` helper.
  **Tag**: [advisory] — logged, not applied (refactor, not a correctness fix).

- **[P2.6]** [cg-code-quality] `R/checks.R:94-95` and formerly `R/assign.R:24-27` — Duplicated "list dirs/files and filter by `isdir`" pattern. The `R/assign.R` copy (`safe_child_dirs()`) was simplified this session (see P2.9); `check_dir_extension()`'s copy in `R/checks.R` remains and still duplicates the idiom.
  **Fix**: Factor a small shared helper for directory-content listing, used by both.
  **Tag**: [advisory] — logged, not applied.

- **[P2.7]** [cg-code-quality] `R/definitions.R:12` — `missing_fields <- required[!vapply(required, function(f) !is.null(check[[f]]), logical(1))]` used a double negation, reducing readability.
  **Fix**: Simplified to `required[vapply(required, function(f) is.null(check[[f]]), logical(1))]`.
  **Status**: ✅ Fixed this session.
  **Tag**: [safe_auto] — applied.

- **[P2.8]** [cg-performance] `R/checks.R:33-54` — `get_check_registry()` rebuilds the full registry (4 closures, `getOption()`, conditional `modifyList()`) on every single check call, inside the innermost loop of folders × schemas × checks.
  **Why**: At realistic PIP vintage-folder scale (tens to low hundreds), the absolute cost is low, but it's unnecessary repeated work and will compound once this mechanism is reworked per P0.1.
  **Fix**: Hoist the registry lookup to once per `classify_folder()` (or once per `assign_schemas()`) call and pass it down as a parameter — naturally falls out of the P0.1 fix if the explicit-parameter approach is chosen.
  **Tag**: [advisory] — logged, not applied; revisit together with P0.1.

- **[P2.9]** [cg-performance] `R/assign.R:24-27` (`safe_child_dirs()`) — `list.dirs(..., recursive = FALSE)` already returns only directories by contract; the subsequent `dirs[file.info(dirs)$isdir %in% TRUE]` filter was a redundant, expensive re-stat of paths already known to be directories.
  **Fix**: Removed the redundant filter; `safe_child_dirs()` now returns `list.dirs(data_dir, full.names = TRUE, recursive = FALSE)` directly.
  **Status**: ✅ Fixed this session. Full suite passes (90/90).
  **Tag**: [safe_auto] — applied.

- **[P2.10]** [cg-architecture] `R/assign.R:9-27` — `normalize_schema_for_output()` (output-shaping for a parsed schema) and `safe_child_dirs()` (generic filesystem listing) arguably belong next to `read_definitions()` in `R/definitions.R` and in a generic utility module, respectively, rather than in `R/assign.R`.
  **Fix**: Consider moving `normalize_schema_for_output()` to `R/definitions.R` and `safe_child_dirs()` to a new `R/utils.R`, renamed to something describing its actual contract (e.g. `list_subdirectories()`).
  **Tag**: [advisory] — logged, not applied (organizational, no behavior change).

### P3 — MINOR (nice to have)

- **[P3.1]** [cg-code-quality] `R/checks.R:140-142` — `run_check()` is now a one-line pass-through wrapper around `run_check_with_registry()` with no added behavior.
  **Fix**: Inline, or document the intended future seam.
  **Tag**: [advisory] — logged, not applied.

- **[P3.2]** [cg-code-quality] `R/checks.R:33-54` — Variable name `node` for a registry entry was non-descriptive.
  **Fix**: Renamed to `check_def` in `required_fields_for_check_type()` and `run_check_with_registry()`.
  **Status**: ✅ Fixed this session.
  **Tag**: [safe_auto] — applied.

- **[P3.3]** [cg-code-quality] `R/assign.R` (`normalize_schema_for_output()`) — Conditional key-reordering (`out <- out[c("id","description","checks","folders")]`) duplicates the literal key list and is fragile if a new field is added later. (Partially touched this session while adding the description-shape guard; the underlying reorder pattern itself is unchanged.)
  **Fix**: Build the full desired key list up front, or add a comment explaining the YAML-ordering intent.
  **Tag**: [advisory] — logged, not applied.

- **[P3.4]** [cg-adversarial] `R/checks.R:88-110` (`check_dir_extension`) — Both the actual file extension and the configured `extension` are lowercased before comparison, so `.FST`/`.fst` are treated as identical with no documented case-sensitivity contract.
  **Fix**: Document the case-insensitive behavior explicitly in roxygen/README, or add an optional `case_sensitive` check field.
  **Tag**: [advisory] — logged, not applied.

- **[P3.5]** [cg-documentation] `DESCRIPTION:6` — The new `Description:` field addition isn't mentioned in `NEWS.md` (minor metadata-only change; NEWS.md otherwise itemizes fine-grained changes).
  **Fix**: Optional one-line NEWS.md bullet if full-diff NEWS coverage is desired.
  **Tag**: [advisory] — logged, not applied.

- **[P3.6]** [cg-performance] `R/classify.R:26-32` — No early-exit once a schema is known to have failed; all remaining checks in that schema still run (intentional, for complete diagnostic failure reasons).
  **Fix**: None recommended; informational only.
  **Tag**: [advisory] — no action needed.

### ✅ Passed / confirmed safe

- `cg-code-quality`: No P0/P1 correctness, security, or data-integrity issues.
- `cg-documentation`: README's "Add a check type" wording, "Why these two schemas separate" section, and PROD-only statement are all verified consistent with `inst/schemas/definitions.yml` and the actual registry/loader code — no dual-edit trap exists for adding a check type.
- `cg-version-control`: No credentials/secrets found. `man/*.Rd` and `README.md` being tracked is correct and expected for an R package (confirmed `devtools::document()` was run; `NAMESPACE` is in sync). No protected files were recommended for deletion/rename/move.
- `cg-reproducibility`: No non-seeded randomness; `assign_schemas()` writes only relative folder basenames and relative schema paths, never absolute/machine-specific paths; `withr`/`testthat` Suggests declarations match actual test-only usage.
- `cg-performance`: No full-table loads; `check_fst_columns()` correctly uses header-only `fst::metadata_fst()`. Nested-loop structure (folders × schemas × checks) will scale acceptably at realistic PIP vintage-folder counts.
- `cg-architecture`: Confirmed the charter requirement "adding a kind of check adds one function to a small catalog" is genuinely met structurally — `R/checks.R`'s registry is the single source of truth for check types; `R/definitions.R` no longer needs editing to add a type (modulo the P0.1 override-mechanism caveat).
- `cg-data-quality`: YAML-injection round-trip fidelity for `description` (colons, dashes, embedded newlines, list markers) verified safe via `yaml::as.yaml()`/`yaml::yaml.load()`.
- `cg-learnings-researcher`: No drift back toward the explicitly rejected closed-inventory design (`.cg-docs/brainstorms/2026-10-07-closed-schema-design.md`) — no inventory list, ignore list, tracked skeleton, or core `_aux` guard present anywhere in this diff. No PROD/INT/TEST filter reintroduced. `.cg-docs/solutions/` has no relevant prior entries (all placeholders).
- `cg-adversarial`: Confirmed safe: YAML round-trip injection (description field), write-atomicity (no partial file on failure), test-order/`withr` scoping for the registry-override test, and no closed-inventory regression via the new check-type registry.

### ⚠️ Incomplete Reviews

None — all 10 agents returned usable, on-topic output referencing the changed files.

---

## Autofix Summary

**Applied this session (safe_auto, 8 findings)**: P1.2, P1.3, P1.4, P2.1, P2.2, P2.7, P2.9, P3.2.
Verification: `devtools::document()` + `devtools::test()` → **90/90 PASS**; `devtools::check(error_on = 'warning')` → **0 errors, 0 warnings, 3 notes** (same pre-existing environmental/repo-shape notes as before this review; unrelated to the fixes).

**Remaining manual findings requiring your decision before I apply anything further**:
- **P0.1** — how to fix the global check-registry override (remove entirely vs. explicit parameter vs. `local_mocked_bindings()`-based test seam). This also determines whether the registry-override test in `test-definitions.R` needs rewriting.
- **P1.1** — where to centralize path-traversal validation (in `R/checks.R` runners vs. at parse time in `R/definitions.R`, or both).
- **P1.5, P1.6, P2.4** — documentation content (examples, error-behavior `@return` text, NEWS.md updates); low-ambiguity but left for your sign-off since they're prose, not mechanical fixes.
- **P1.7** — commit-splitting recommendation for when you commit this work (no code change).

**Advisory (noted, not applied)**: P2.3, P2.5, P2.6, P2.8, P2.10, P3.1, P3.3, P3.4, P3.5, P3.6.
