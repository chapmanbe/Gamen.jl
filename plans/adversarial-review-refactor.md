# Implementation Plan: Adversarial-review refactor (post-PR #12)
*Written 2026-07-10 at the close of a design session. Read this once; implement against it.*

## Objective

Implement the remaining findings from `notes/adversarial-review-2026-07-08.md`
(the full review report — cite its § numbers when you need detail). The
adjudicated logic bugs (§C1–C6, Until/Since endpoints) are ALREADY FIXED:
C2 in commit 852c392 on main, the rest in PR #12 (branch
`phase0-adjudicated-fixes`). Do not redo them. What remains: the engineering
correctness items no one disputed, then the architectural refactor.
Definition of done per phase: all tests pass (592+ as of PR #12), new
regression tests for each behavior change, validation-log rows added for
anything touching B&D semantics.

## Current state (verify before starting)

- Check whether PR #12 is merged (`gh pr view 12 --repo chapmanbe/Gamen.jl`).
  If merged: branch off `main`. If not: branch off `phase0-adjudicated-fixes`
  or wait — do NOT re-implement its contents.
- Jeremiah Chapman (GitHub `sntownsend`) is the logic reviewer/co-author. Any
  change with B&D semantic content goes through a PR he can review, and gets
  a row in `notes/validation-log.md` (format documented in that file).

## Decisions (do not relitigate)

- **Temporal tableau is QUARANTINED** — Jeremiah's ruling (issue #10): B&D
  provides no temporal tableau rules; the 𝐆/𝐅 rules are unsourced analogies.
  Do NOT add rules for 𝐇/𝐏/Since/Until until a published rule set is adopted.
  They throw `ArgumentError` — that is the intended behavior, not a stub.
- **Blocking design is settled** (852c392, Goré 1999 §6.6): ancestor-equality,
  per-system `uses_blocking` flag, recomputed per rule application. Don't
  redesign it.
- **B axiom is `p → □◇p`** (Jeremiah confirmed); `□p → ◇□p` is KTB, not KB.
- **`common_knowledge` = transitive closure** (Def 15.6), a deliberate no-op
  on reflexive frames — do not "simplify" it back to seeding with the world.
- **Bounded checkers stay bounded** — `max_worlds ≤ 4` is a documented
  complexity wall (see CLAUDE.md). The fix direction is *honest reporting*
  (witness / `missing`), never a bigger bound.
- **Phases land in order, each as its own PR** with tests green before the
  next starts. Phase 1 (generic traversal) precedes Phase 2 because Phase 2's
  deletions depend on it.

## Architecture

### Phase 0 remainder — validation & honest contracts (no restructuring)
- `src/kripke.jl`: inner constructor for `KripkeFrame` enforcing nonempty
  worlds, sources AND targets of the relation ∈ worlds, uniform
  `ArgumentError`s (report §M1 — currently dangling targets make
  `is_universal`/`is_serial` return wrong answers and `is_true_in(m, ⊥)`
  true on an empty model). Validate `V(p) ⊆ W` in `KripkeModel`. Mirror in
  `EpistemicFrame` (`src/epistemic.jl`).
- `src/kripke.jl`: `accessible` must stop leaking the internal `Set` (§M3) —
  return a copy; hoist the eagerly-allocated empty-set default
  (`get(() -> ..., ...)` or a shared const AFTER the copy change).
- `src/completeness.jl`: `is_entailed_by` / `is_consistent` return richer
  results (§C7) — see Interfaces below. Keep `Bool`-compatible wrappers or
  update all call sites (filtrations.jl, tests, notebooks reference these).
- `src/tableaux.jl`: `max_steps` exhaustion must be distinguishable from a
  countermodel (§M7); fix the unused-`all_saturated` dead code so returned
  tableaux don't hand `extract_countermodel` an unexpanded branch (§M10).
- `src/filtrations.jl`: fix or remove `has_finite_model_property` (returns
  `true` on both branches, §M8); re-document `modal_closure` as the one-step
  extension it is (§M8 — B&D's closure is infinite, `is_modally_closed` can
  only ever be true for ∅ on finite input).
- `src/fol.jl`: fresh-variable capture in `standard_translation` (§M4 — a
  caller-supplied free `y₁` gets captured; skip colliding names or gensym);
  structural `==`/`hash` for FO types (§M5) — or fold into Phase 1 generics.
- `src/semantics.jl`: add `is_valid(f, m::KripkeModel)` singleton method
  (§M10 — currently `MethodError: iterate`).

### Phase 1 — generic formula traversal (enables all Phase 2 deletions)
New file `src/traversal.jl` (include early in `src/Gamen.jl`, after
formulas.jl and the variant-type definitions): a two-method protocol per
Formula node — `children(φ)` and a reconstructor. Then derive generically:
`atoms`, `subformulas`, `substitute`, `is_modal_free`, structural
`==`/`hash`. This kills the N×M matrix (§A3: ~7 functions × 9+ constructors,
hand-written) and fixes §M9 (temporal/epistemic formulas crash all Ch4/5
machinery with `MethodError`) and §M2 (the `==(::Formula,::Formula)=false`
catch-all violates reflexivity for subtypes that forget `==`). Delete the
per-type methods the generic versions replace; keep behavior identical
(existing tests are the safety net; §M9 gets NEW tests: `subformulas`/`atoms`
/`substitute` on `FutureBox`, `Knowledge`, `Since`).

### Phase 2 — logic variants as configurations (GATED, see Open questions)
- Pluggable accessibility in `satisfies` so `Knowledge` = Box indexed by
  agent; delete the duplicated boolean clauses in `src/epistemic.jl:154-182`
  (§A1 — already diverged: `satisfies(::EpistemicModel, w, ::Box)` is a
  MethodError). `EpistemicModel` should wrap/alias `KripkeModel` the way
  `TemporalModel = KripkeModel` already does.
- Promote `EPISTEMIC_K/KT/S4/S5` from inert `Symbol`s to frame-condition
  bundles with a validator mirroring `SYSTEM_*` (§M6/F5 — veridicality is
  currently assumed, never enforced).
- Delete temporal duplicates: `is_transitive_frame` ≡ `is_transitive`,
  `is_unbounded_future` ≡ `is_serial`, `is_dense_frame` ≡ `is_weakly_dense`
  (§A2); alias the Ch. 2 predicates.
- Parametrize tableau rules over `(BoxT, DiamondT)` operator pairs so the
  temporal rule copies in `src/temporal.jl:235-379` and the hardcoded
  temporal `elseif` dispatch in the engine disappear (§A2/§F7). ⚠️ This item
  ONLY after the design note is approved — see Open questions.

### Phase 3 — decomposition & performance
- Split `src/tableaux.jl` (~1250 lines) along its existing section markers →
  `tableau/prefixes.jl`, `rules.jl`, `systems.jl`, `engine.jl`,
  `countermodel.jl` (§A4). Pure file moves + includes; zero behavior change.
- Split `test/runtests.jl` (~1980 lines) into per-chapter
  `test/test_chN_*.jl` includes; add Aqua.jl; add a Makie CI job with one ext
  smoke test (`visualize_model(model) isa Figure`) — §Tests: 23 of 172
  exports untested, ext has zero CI coverage and broke silently before
  (b81129d). Add `Test` compat in `[extras]`.
- Perf (all measured in report §4): batch-copy `append_formula` (O(n²)
  branch growth), children-prefix index `Dict{Prefix,Vector{Prefix}}`,
  incremental closure check, stop resetting `expanded` BitSet in Priority-2
  rules; machine-word bitmasks + reused buffers in `_enumerate_frames`/
  `_enumerate_valuations` (one `is_consistent` call = 2.57G allocs/79.6 GiB);
  drop the `_dummy` atom injection in `is_consistent`; truth-signature pass
  in `equivalence_classes`/`_coarsest_edge`.

### Phase 4 — API polish
`KripkeModel(frame)` convenience constructor in core so the ext stops
hardcoding valuation types (§A5 — ext line ~118 is the exact bug class of
b81129d); ext `positions` kwarg conversion + friendly missing-world error;
`==`/`hash`/`show` for `KripkeFrame`/`KripkeModel`; document the
`Atom(0) == Atom(:p0)` shared namespace.

## Interfaces / contracts

Phase 1 protocol (names negotiable, shape is not):

```julia
children(φ::Formula) -> Tuple{Vararg{Formula}}   # () for Atom/Bottom/Top
# reconstructor: rebuild the same node type around new children;
# non-Formula fields (Atom name, Knowledge agent) must survive the round trip
similar_node(φ::Formula, new_children::Tuple) -> Formula
# generic equality replacing the ==(::Formula,::Formula)=false catch-all:
# typeof(a) === typeof(b) && non-child fields == && children pairwise ==
```

Phase 0 honest-checker return (agreed direction, exact shape implementer's
call — keep it a NamedTuple):

```julia
is_consistent(system, Γ; max_worlds=4)
  -> (consistent::Union{Bool,Missing}, witness::Union{KripkeModel,Nothing})
# missing when the bound was exhausted without a verdict; docstrings must
# state one-sidedness either way
```

Tableau exhaustion (§M7): `build_tableau`/`tableau_proves` must expose
"ran out of steps" distinctly (e.g. a `complete::Bool` on `Tableau` checked
by callers, or `Union{Bool,Missing}`); silent `false` is the bug.

## Constraints

- Everything in the repo `CLAUDE.md` binds: `max_worlds ≤ 4` untouchable;
  frame conditions as data, never hardcoded; no `visualize_model` in `src/`;
  Unicode not LaTeX in docs; B&D definition numbers in docstrings; the
  ~80s Decidability testset is expected, don't "fix" it.
- The blocking section of CLAUDE.md was rewritten for 852c392 — keep it in
  sync if Phase 3 moves that code.
- JOSE submission target Summer 2026: notebooks under `notebooks/` call the
  public API — grep them before renaming/changing any exported signature
  (`is_entailed_by` rename history shows renames ripple into notebooks).
- Julia is a silent-failure language: every behavior change needs a test
  that fails on the old code.

## Non-goals / rejected alternatives

- **No 𝐇/𝐏/Since/Until tableau rules** — quarantined by Jeremiah's ruling
  until a published source is adopted (the original plan's "converse-prefix
  rules" item is superseded).
- **No `max_worlds` increase, no BigInt "fix"** for the enumeration wall —
  documented complexity bound; overflow guards (done in PR #12) are the fix.
- **No auto-derivation of `TableauSystem` from `ModalSystem`** without the
  approved design note (CLAUDE.md standing rule).
- **No `Set`-returning API changes to formula traversal semantics** — the
  generic layer must be a pure refactor of results, not a redesign.
- **Rejected: fixing findings by special-casing the current examples** — the
  review exists because the package must generalize (CLAUDE.md principles).

## Open questions for the implementer

- [ ] **Phase 2 gate**: CLAUDE.md forbids connecting `ModalSystem` ↔
      `TableauSystem` without a written, approved plan. Before the tableau
      parametrization item, write `plans/tableau-parametrization.md`
      (operator-pair design, whether system constants get derived from
      schemas) and get Brian's explicit approval. The rest of Phase 2
      (epistemic satisfies dedup, EPISTEMIC_* validators, predicate aliases)
      is NOT gated.
- [ ] **EPISTEMIC_* enforcement semantics**: validate at `EpistemicModel`
      construction (rejects legitimate non-S5 teaching examples?) or via an
      explicit `is_valid_epistemic_model(model, system)` check function?
      Flag to Brian/Jeremiah on the PR; default to the check function
      (non-breaking).
- [ ] **Issue tracking**: PR #12 says "Closes #10". Confirm with Brian
      whether remaining phases get fresh issues (proposed) or #10 reopens.
- [ ] Report §M10 lists small ambiguous items (e.g. `Atom(0)==Atom(:p0)`:
      document vs. separate namespaces) — pick the non-breaking option and
      note it in the PR.

## Task list (ordered)

1. Verify PR #12 status; branch accordingly (see Current state).
2. Phase 0 remainder, one PR: frame/model constructor validation (§M1) +
   `accessible` copy (§M3) + `is_valid` singleton (§M10) + regression tests.
   Expect some existing tests/notebooks to construct sloppy frames — fix
   them, don't weaken the validation.
3. Phase 0 remainder, second PR: honest checkers (§C7 interface above) +
   tableau exhaustion signal (§M7) + `all_saturated` dead code (§M10) +
   `has_finite_model_property` / `modal_closure` (§M8) + fol.jl capture and
   equality (§M4/M5). Validation-log rows for C7/M8.
4. Phase 1 PR: `src/traversal.jl` protocol, generic derivations, delete
   superseded per-type methods, new §M9 regression tests (temporal/epistemic
   formulas through `subformulas`/`atoms`/`substitute`/`==`).
5. Phase 2 PR (ungated half): epistemic `satisfies` dedup via pluggable
   accessibility, `EPISTEMIC_*` validators, temporal predicate dealiasing.
6. Write + get approval on `plans/tableau-parametrization.md`; then Phase 2
   gated half (operator-pair rules, derive system constants from schemas).
7. Phase 3 PR(s): tableaux.jl file split (pure move first, separate commit),
   test split + Aqua + ext CI job, then the perf items with before/after
   allocation numbers in the PR body.
8. Phase 4 PR: ext decoupling + API polish.
9. After each semantic phase: validation-log rows; ping `sntownsend` for
   re-confirmation (⚠ → ✓ discipline).

## Suggested implementer model

Sonnet minimum — Julia fails silently (method-dispatch gaps and type
mismatches surface as wrong answers, not errors; the review's Set-mutation
and `==`-catch-all findings are exactly that class). Phase 1's generic
traversal and the Phase 2 design note are the subtle parts — use Opus-class
for those two; Phases 3–4 (file moves, test splits, mechanical perf fixes)
are fine on Sonnet. Not Haiku: too much load-bearing dispatch.
