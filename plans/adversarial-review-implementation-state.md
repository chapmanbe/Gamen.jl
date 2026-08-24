# Implementation Plan: Adversarial-review refactor — continuation (post-PR #17)
*Written 2026-07-16 at the close of an implementation session. Read this once; implement against it. Companion to `plans/adversarial-review-refactor.md` (the master plan — its Decisions section still binds). Supersedes the post-PR #16 version of this file.*

## Objective

Finish the master plan's tasks 7–9: Phase 3 (decomposition + performance),
Phase 4 (API polish), and the validation-log ⚠ → ✓ re-confirmation loop with
sntownsend. The formerly gated tableau work is DONE (PR #17). Definition of
done per phase: all tests pass (731 as of PR #17), regression tests for each
behavior change, validation-log rows for B&D-semantic changes.

## Current state (verify before starting)

Stacked PR chain, each green, merge in order:

| PR | branch | contents |
|----|--------|----------|
| #12 | `phase0-adjudicated-fixes` | adjudicated logic fixes |
| #13 | `phase0-validation` | §M1/M3/M10 validation |
| #14 | `phase0-honest-contracts` | §C7 NamedTuple checkers, §M7/M8, fol.jl |
| #15 | `phase1-traversal` | `children`/`similar_node` protocol |
| #16 | `phase2-configurations` | shared satisfies, `EpistemicSystem`, aliases |
| #17 | `phase2-tableau-parametrization` | ADR-0001 Option A (see below) |

Check `gh pr list --repo chapmanbe/Gamen.jl`; branch the next phase off the
stack tip (currently `phase2-tableau-parametrization`) or off `main` if the
stack has landed.

**ADR-0001 is Accepted** (Brian, 2026-07-14; `decisions/ADR-0001`, committed
in #17). The `ModalSystem` → `TableauSystem` connection exists and goes
through `tableau_rules(::AxiomSchema)` ONLY — no reverse derivation, no
automatic frame-condition synthesis. Do not extend it without a new ADR.

## Decisions made during implementation (do not relitigate)

All prior decisions in the master plan and the post-#16 session stand
(C7 checkers never wrapped in Bool compat; `_successors` non-copying internal
convention; EPISTEMIC validation is a check function; jupyter regeneration
deferred). New in PR #17:

- **`OperatorPair` is internal/unexported** (design-note Q3 as recommended);
  `BASE_PAIR` lives in `tableaux.jl`, `TEMPORAL_PAIR` in `temporal.jl`.
- **Rules take the pair as a 3rd positional arg with `BASE_PAIR` default** —
  2-arg calls still work everywhere.
- **`BoundRule <: Function` struct, not anonymous closures** (deviation from
  the design note's sketch): identical bindings compare `==` via egal, which
  is what makes the derived-vs-hand-built equivalence testset possible.
- **`TableauSystem` fields**: `name, operator_pairs, used_prefix_rules,
  witness_rules, uses_blocking, schemas`. The old 3-positional + kwargs
  convenience constructor is preserved. Derivation constructor
  `TableauSystem(ms::ModalSystem; operator_pairs=[BASE_PAIR])` sets
  `uses_blocking = any(isa Schema4)` and retains `.schemas` as metadata.
- **`TABLEAU_S5` derives from an inline KTB45 `ModalSystem` presentation**
  (≡ KT5; Table 6.4's calculus uses T/B/4/4T rules), NOT from `SYSTEM_S5`.
  Same move for `EPISTEMIC_S5` (KT45 → reflexive+transitive+euclidean,
  Table 15.1). Both flagged to Jeremiah in the PR and validation log — if he
  objects, that's a discussion, not a silent revert.
- **`TABLEAU_KDt` stays hand-assembled** (B&D has no temporal schema
  objects): explicit `uses_blocking=true`, `operator_pairs=[BASE_PAIR,
  TEMPORAL_PAIR]`, empty `.schemas`.
- **`_check_tableau_supported(f, system)` is generic via `children()`** and
  rejects ANY formula type outside {atoms, propositional connectives, types
  in a declared pair}. Deliberate behavior widening beyond the design note:
  `Knowledge`/`Announce` fed to a tableau now throw (was: silent opaque-atom
  treatment — same unsoundness class as C6). Q2 resolved as recommended
  (throw, don't silently apply).
- **`EpistemicSystem(name, ms::ModalSystem)` derivation**: condition names
  come from stripping the `is_` prefix off `nameof(frame_predicate(schema))`.
- **`extract_countermodel` frame-closure gap is NOT fixed** — deliberate.
  It's a semantic change needing Jeremiah's ruling on the closure lemma
  (does closing the extracted frame per-system preserve branch truth — Goré/
  Fitting say yes for T/B/4, but B&D proves Thm 6.19 for K only). Docstring
  caveat added; ⚠ open row in `notes/validation-log.md`; the fix, when
  approved, derives closure operators from `TableauSystem.schemas` — never
  from a per-system-name dispatch (that's gamen-hs's `closeForSystem`
  dual-encoding mistake, the thing the audit existed to prevent).
- **`plans/` stays untracked/local; `decisions/` is committed.**

## Architecture / Interfaces

Read the code, not summaries: `src/tableaux.jl` (OperatorPair, BoundRule,
derivation constructor — all near the top and the "Tableau system" section),
`src/traversal.jl` (protocol), `src/completeness.jl` (C7 NamedTuple shapes,
unchanged since #14). C7 shapes for reference:

```julia
is_consistent(system, Γ)   -> (consistent = true|missing, witness, world)
is_entailed_by(system, Γ, φ) -> (entailed = false|missing, countermodel, world)
tableau_proves / tableau_consistent -> Union{Bool,Missing}
```

## Constraints

- Everything in repo `CLAUDE.md` binds (max_worlds ≤ 4, frame conditions as
  data, blocking settled, Unicode docs, B&D refs). Note CLAUDE.md's blocking
  section was extended in #17 (uses_blocking derived iff Schema4, ADR-0001)
  — the Phase 3 file split must keep that section pointing at the right
  files.
- **Phase 3 split placement**: the new OperatorPair/BoundRule section
  belongs with the rules (`tableau/rules.jl`), the derivation constructor
  with the systems (`tableau/systems.jl`). Pure file moves first, separate
  commit, zero behavior change.
- Test file top-level defines `M2ProbeFormula` before the outer testset —
  the test split must keep such definitions in the shared entry file.
- `notes/validation-log.md` now has EIGHT rows awaiting sntownsend: five
  from 2026-07-12/13 (PRs #13–#16) + three from 2026-07-14 (PR #17: two
  ⚠ → ✓, one ⚠ open for the extract_countermodel gap).
- Cross-project: next release notes must mention the `.consistent === true`
  migration for `guideline-cds-simulation` / legacy `guideline-validation`.

## Non-goals / rejected alternatives

- All master-plan non-goals stand (no temporal tableau rules for 𝐇/𝐏/Since/
  Until, no max_worlds increase).
- **Rejected: fixing extract_countermodel closure in #17** — semantic change
  without a ruling; see Decisions above for the approved fix shape.
- **Rejected: exporting OperatorPair** — wait for a second consumer (e.g. an
  epistemic K_a tableau).
- **Rejected: a `TableauSystem`-level per-name closure map** — that is the
  dual-encoding anti-pattern; anything per-system derives from `.schemas`.

## Open questions for the implementer

- [ ] Issue tracking: fresh issues vs reopening #10 for Phases 3–4 —
      Brian's call, ask before opening Phase 3 PRs.
- [ ] `pluto_to_jupyter.jl` divergence (drops mandated Pkg.activate cell) —
      Brian's call, still pending.
- [ ] extract_countermodel closure lemma — Jeremiah's ruling; only then
      implement per-system closure from `.schemas`.

## Task list (ordered)

1. Confirm which stack PRs have merged; rebase/retarget as needed (the
   stack is now six deep — if #12–#14 have landed, retarget the rest).
2. Phase 3 PR(s) per master plan task 7: `tableaux.jl` split along section
   markers → `tableau/prefixes.jl`, `rules.jl`, `systems.jl`, `engine.jl`,
   `countermodel.jl` (pure moves first, separate commit; keep CLAUDE.md's
   blocking section in sync), then test split + Aqua.jl + Makie ext CI
   smoke test, then perf items with before/after allocation numbers in the
   PR body.
3. Phase 4 PR per master plan task 8: `KripkeModel(frame)` convenience
   ctor, ext decoupling, `==`/`hash`/`show` for frames/models,
   `Atom(0)==Atom(:p0)` documentation.
4. Ping sntownsend for ⚠ → ✓ re-confirmation of the eight validation-log
   rows once PRs merge; the ⚠ open extract_countermodel row doubles as the
   closure-lemma question for him.

## Suggested implementer model

Sonnet — Julia fails silently, so don't go below it, but Phases 3–4 are
file moves, test plumbing, and measured perf fixes; the subtle design work
(traversal protocol, tableau parametrization) is done. Escalate to
Opus-class only if the extract_countermodel closure work gets unblocked
mid-session.
