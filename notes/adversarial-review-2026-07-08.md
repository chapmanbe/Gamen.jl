# Adversarial Code Review — Gamen.jl (2026-07-08)

Six parallel adversarial reviewers covered: core syntax/semantics, frame
properties/axioms, tableaux, completeness/filtrations, temporal/epistemic,
and FOL/extension/tests/architecture. Every correctness finding marked
CONFIRMED was demonstrated with a runnable Julia repro against the current
`main` (commit 1063128). Findings a repro disproved were dropped.

Sections: 1. Critical correctness · 2. Major correctness/API ·
3. Architecture · 4. Performance · 5. Tests & tooling ·
6. Refactoring plan · 7. Verified-correct list (for the validation log)

---

## 1. Critical correctness (silent wrong answers)

### C1. TABLEAU_KB is unsound — proves non-theorems of KB — CONFIRMED
`src/tableaux.jl:684-686`. The hand-built `TABLEAU_KB` constant includes the
reflexivity rules `apply_T_box_rule`/`apply_T_diamond_rule` alongside the B
rules. Result: `tableau_proves(TABLEAU_KB, Formula[], □p → p)` → `true` and
`□p → ◇p` → `true`, both invalid on symmetric frames (semantic check on
`[:w1=>:w2, :w2=>:w1]` with p only at w2 refutes □p→p at w1). The
Sahlqvist-derived `tableau_rules(::SchemaB)` at line 608 is correct — only
the constant is wrong. Fix verified safe: with only the B rules, the B axiom
`p → □◇p` still proves and `□p → p` correctly fails.

### C2. Ancestor blocking makes base-logic tableaux incomplete — CONFIRMED
`src/tableaux.jl:763-774, 889-895` (also 917-923, 942-948). Blocking is
applied in *every* system, is checked at world birth on single-formula
subset content, and the blocked set is sticky (never re-evaluated as the
prefix's content grows). Consequence in plain K:
`tableau_proves(TABLEAU_K, Formula[], ((p∧q) ∧ ◇(p∧q)) → ◇p)` → `false`
(valid — ◇-monotonicity). Branch dump shows `blocked = [1.1]` with
unexpanded `1.1 T (p∧q)` sitting open. Three root causes:
(a) blocking should be a system capability (temporal/transitive only), not
engine-global; (b) a blocked prefix whose content grows past its blocker
must be unblocked; (c) Fitting/Wolper block on subsumption *at saturation*,
not at creation.

### C3. `T ⊥` never closes a branch — CONFIRMED
`src/tableaux.jl:195-205` (leaf skip at 807-808). `is_closed` only detects
T A / F A pairs; Bottom is skipped as a leaf. `tableau_proves(TABLEAU_K,
Formula[], ⊥ → p)` → `false` (propositional theorem);
`tableau_consistent(TABLEAU_K, [Bottom()])` → `true`. Also poisons
`Top() = Not(Bottom())`. Fix: close on any `σ T ⊥` (F ⊤ falls out).

### C4. Int64 overflow family — enumeration loops go empty, return `true` — CONFIRMED
- `src/frame_properties.jl:206`: `n_valuations = (1 << n_worlds)^n_vars`
  wraps to 0 when `n_worlds × n_vars ≥ 63`; `is_valid_on_frame` then returns
  `true` for *any* formula. Reachable within the project's own limit:
  4 worlds × 16 atoms = 2^64 → 0. Repro: 64-atom disjunction on a 1-world
  irreflexive frame → "valid".
- `src/filtrations.jl:461`: `bound = min(2^n, 4)` with n = subformula count;
  n ≥ 63 → bound ≤ 0 → `is_decidable_within(SYSTEM_K, □^63 p)` returns
  `(valid = true, bound = 0, …)`. CONFIRMED.
- `src/axioms.jl:54`: same class in `is_tautology` (≥63 distinct atoms).
  PLAUSIBLE (less reachable).

### C5. `common_knowledge` computes the wrong closure — CONFIRMED
`src/epistemic.jl:257-274`. B&D Def 15.6 uses the **transitive** closure of
⋃R_b; the BFS seeds `visited` with the evaluation world, i.e. the
*reflexive*-transitive closure. Wrong answer on non-reflexive frames:
`W={w1,w2}`, `R_a={w1→w2, w2→w2}`, p at w2 only →
`common_knowledge(m, :w1, [:a], p)` returns `false`, should be `true`.
Invisible on S5 frames, which is why tests miss it.

### C6. Tableau engine silently ignores 𝐇/𝐏/Since/Until — CONFIRMED
`src/temporal.jl:221-404`, `src/tableaux.jl:876-977`. No rules exist for the
past/binary temporal operators; they are treated as opaque atoms with no
error. The Kt interaction axiom `p → 𝐆(𝐏p)`, valid on all temporal frames,
is unprovable: `tableau_proves(TABLEAU_KDt, Formula[], …)` → `false`, while
`𝐆p → p` proves fine. Should implement converse-prefix rules or throw
`ArgumentError("no tableau rules for PastBox")`.

### C7. `is_entailed_by`/`is_consistent` docstrings overclaim — CONFIRMED
`src/completeness.jl:58-60, 119-120`. These are one-sided bounded
approximations (sound for refutation within max_worlds only), but docstrings
claim they "coincide with syntactic derivability"/consistency. Repro: φ =
`◇(p∧q) ∧ ◇(p∧¬q) ∧ ◇(¬p∧q) ∧ ◇(¬p∧¬q) ∧ □□⊥` is satisfiable (minimal model
5 worlds) yet `is_consistent(SYSTEM_K, [φ])` → `false`. Cascades:
`lindenbaum_extend` throws on genuinely consistent Γ;
`canonical_model` can silently drop worlds; `has_finite_model_property`'s
"valid" branch is untrustworthy. The O(2^n²) bound is documented — the
completeness *claim* is not licensed by it. API fix preferred over prose
fix: return a witness/countermodel or `missing` when inconclusive.

---

## 2. Major correctness / API contract

### M1. `KripkeFrame` constructor admits ill-formed frames — CONFIRMED
`src/kripke.jl:7-22`. Three gaps, one choke point:
- Relation targets outside W accepted (`KripkeFrame([:w1],[:w1=>:w2])`) —
  violates R ⊆ W×W (B&D Def 1.6); semantics later crash with
  `ArgumentError`, and `is_universal`/`is_serial`
  (`src/frame_properties.jl:177-180, 64-66`) return wrong answers because
  the `length(accessible(w)) == n` shortcut counts non-worlds. CONFIRMED
  both ways (crash + `is_universal == true` on a frame where a does not
  access b).
- Empty W accepted despite Def 1.6 "nonempty": `is_true_in(m, Bottom())` →
  `true` (⊥ "true in a model"). CONFIRMED.
- Source world not in W surfaces as raw `KeyError` instead of
  `ArgumentError`. CONFIRMED.
- Companion: `KripkeModel` doesn't validate V(p) ⊆ W
  (`src/kripke.jl:51-57`). CONFIRMED. Same gap in `EpistemicFrame`
  (`src/epistemic.jl:83-85`). CONFIRMED.

### M2. `==(::Formula,::Formula) = false` catch-all breaks reflexivity — CONFIRMED
`src/formulas.jl:148`. Any Formula subtype lacking an explicit `==` is
unequal to *itself* → silent Set/Dict corruption in closure logic. All 16
in-repo subtypes currently define `==`, but the failure mode is silent for
the next contributor (repro: 1-line user subtype, `X() == X()` → `false`).

### M3. `accessible` leaks the frame's internal mutable Set — CONFIRMED
`src/kripke.jl:65-67`. `push!(accessible(f,:w1), :w1)` permanently mutates
the frame. Also the `get(…, Set{Symbol}())` default allocates a fresh empty
Set on every call, including inside the O(n³) frame-property loops.

### M4. `standard_translation` variable capture — CONFIRMED
`src/fol.jl:140-143, 182, 222-233`. `fresh_var!` draws from fixed `y₁, y₂,…`
with no collision check against the caller-supplied free variable.
`standard_translation(Box(p), FOVar(:y₁))` → `∀y₁ (Q(y₁,y₁) → P_p(y₁))` —
the free variable is captured. Fix: skip colliding names or gensym.

### M5. FO formula types have no structural `==`/`hash` — CONFIRMED
`src/fol.jl` (whole file). `standard_translation(◇p) ==
standard_translation(◇p)` → `false`; FO formulas can't be deduplicated or
tested except via `string(…)`.

### M6. `EPISTEMIC_K/KT/S4/S5` are inert Symbols — CONFIRMED
`src/epistemic.jl:364-389`. Bare `Symbol` constants consumed by nothing
(unlike `SYSTEM_S5::ModalSystem`); no validator enforces equivalence
relations, so veridicality fails silently on non-reflexive frames
(`K_a p` true while p false — CONFIRMED). Misleading in a teaching package.

### M7. `max_steps` exhaustion is indistinguishable from a countermodel — PLAUSIBLE
`src/tableaux.jl:1041, 1173-1182`. Hitting `max_steps=1000` returns an open
tableau; `tableau_proves` silently returns `false`. Latent false-negative
channel; needs an `:unknown`/exhausted flag.

### M8. Filtration-module doc/contract mismatches — CONFIRMED
- `has_finite_model_property` (`src/filtrations.jl:434-443`) returns `true`
  on both branches — dead logic that inherits C7's false verdicts.
- `modal_closure` (`:47-66`) computes a one-step modal extension but claims
  "the modally closed set"; `is_modally_closed(modal_closure(x))` is
  provably `false` for any nonempty finite input (B&D closure is infinite).
- `is_decidable_within` docstring promises `(valid, worlds_checked)`;
  returns `(valid, bound, subformula_count)` (`:456,464`).

### M9. Structural-recursion coverage gaps crash variant logics — CONFIRMED
`atoms`/`substitute`/`dual`/`_propositional_skeleton`
(`src/frame_properties.jl:8-16`, `src/axioms.jl:14-22,454-465`),
`subformulas` (`src/completeness.jl:12-20`), `standard_translation`
(`src/fol.jl:186-234`) each hand-enumerate the 9 base constructors.
`Knowledge`, `Announce`, `PastBox/PastDiamond`, `FutureBox/FutureDiamond`
raise raw `MethodError` — so all Ch4/5 machinery (formula_closure,
canonical_model, filtrations, is_decidable_within) crashes on
temporal/epistemic input. CONFIRMED (`subformulas(FutureBox(Atom(:p)))`,
`atoms(FutureBox(Atom(:p)))`, `substitute(Knowledge(…),σ)` all throw).

### M10. Minor API items — CONFIRMED unless noted
- `is_valid(f, model::KripkeModel)` (single model) throws
  `MethodError: iterate` while `entails` has the symmetric convenience
  overload (`src/semantics.jl:76-78` vs `99-101`).
- `Atom(0) == Atom(:p0)` — indexed and named atoms silently share one
  namespace (`src/formulas.jl:25`).
- No `==`/`hash`/`show` on `KripkeFrame`/`KripkeModel` — structurally
  identical frames compare unequal. PLAUSIBLE.
- Temporal `satisfies` for PastDiamond/Since/Until skips the
  world-membership check (bogus world → `false` instead of ArgumentError),
  inconsistent with Box/G (`src/temporal.jl:157,184,204`).
- Tableau engine: `all_saturated` computed and never used; unconditional
  `break` leaves other open branches unexpanded, so
  `extract_countermodel` on those branches violates its own "open
  complete branch" precondition (`src/tableaux.jl:1053-1063`).
- `Until`/`Since` unconditionally exclude endpoints from the C-check
  (`src/temporal.jl:192-193,210-211`); on reflexive frames this diverges
  from the literal Def 14.5 quantifier. Definition-dependent — check B&D's
  intent (strict ≺) and document either way.

---

## 3. Architecture

### A1. `epistemic.jl` is a parallel reimplementation of the base system
`src/epistemic.jl:154-182` re-implements every boolean `satisfies` clause
from `src/semantics.jl:10-46`; `EpistemicFrame`/`EpistemicModel` duplicate
the Kripke structs. Already diverged: `satisfies(::EpistemicModel, w, ::Box)`
is a MethodError (CONFIRMED), so mixed Box/Knowledge formulas crash. This
directly violates the "logic variants as configurations" principle.
`temporal.jl` does it right for models (`TemporalModel = KripkeModel`).

### A2. Temporal duplicates that have a correct original elsewhere
- `is_transitive_frame` ≡ `is_transitive`, `is_unbounded_future` ≡
  `is_serial` (byte-identical), `is_dense_frame` ≡ `is_weakly_dense`
  (`src/temporal.jl:415-491` vs `src/frame_properties.jl`).
- `apply_futurebox_*`/`apply_futurediamond_*`/`apply_temporal_T_*`/`_4_*`
  (`src/temporal.jl:235-379`) are verbatim copies of the base tableau rules
  differing only in type guard — while `src/tableaux.jl:876-977` hardcodes
  temporal `elseif` dispatch, so the "base" engine knows about temporal
  types (circular layering).

### A3. N×M structural recursion — no generic traversal
~7 functions × 9+ constructors each, hand-written per type (`is_modal_free`,
`substitute`, `subformulas`, `atoms`, `standard_translation`, `show`,
`==`/`hash`). Every new Formula subtype must touch ~7 files; missing methods
fail silently (M2) or loudly (M9). One `children(φ)`/reconstruct protocol
collapses the matrix to one method per node type.

### A4. God files
`src/tableaux.jl` (1197 lines) has clean section markers usable as file
boundaries: prefixes/signed formulas/branches (35, 87, 140), rules +
Sahlqvist (262, 591), system + blocking + construction (625, 719, 776),
completeness + prover (1077, 1154). `test/runtests.jl` (1869 lines, 111
testsets) splits along its chapter testsets.

### A5. Extension coupling
`ext/GamenMakieExt/GamenMakieExt.jl:118` hardcodes
`Dict{Atom,Set{Symbol}}()` — the exact class of bug fixed in b81129d, still
present at one site. Worlds-are-Symbol baked into five sites (lines 8-9, 23,
40, 122, 133). `positions` kwarg is a type assertion, not a conversion —
`Dict(:w1=>(0,1))` (Int tuple) throws `TypeError`; missing world → raw
KeyError.

---

## 4. Performance (beyond the documented exponential bound)

- `is_consistent` measured at **2.57G allocations / 79.6 GiB** for one call:
  BigInt bit-twiddling + fresh `Dict` per candidate model
  (`src/completeness.jl:393-425`). max_worlds ≤ 4 → edge masks fit UInt16,
  valuations ≤ 16 atoms fit UInt64; reuse buffers, apply `frame_filter` on
  the bitmask before materializing Dicts.
- `is_consistent` injects `Atom(:_dummy)` when Γ is atom-free → 16× wasted
  valuations at n=4 (`src/completeness.jl:129-131`);
  `_enumerate_valuations` already handles empty vars.
- Tableau `append_formula` copies the whole vector + two sets per single
  formula → O(n²) branch growth; `is_closed` full-scans every step; child
  prefix lookups (`_has_witness`, □T/◇F loops, countermodel pairing) rescan
  linearly — a `Dict{Prefix,Vector{Prefix}}` children index + incremental
  closure check fixes all three. Priority-2 rules also reset
  `expanded = BitSet()`, discarding marks the code's own comment says never
  need recomputation (`src/tableaux.jl:895,923,948`).
- `equivalence_classes` / `_coarsest_edge` / `_c3` re-run `satisfies` per
  world-pair per Γ-formula (`src/filtrations.jl:76-110, 262-288, 375-391`);
  one O(|W|·|Γ|) truth-signature pass serves both.
- `accessible`'s eager `Set{Symbol}()` default allocates on every call
  package-wide (`src/kripke.jl:66`); `is_weakly_directed`/`is_weakly_dense`
  recompute successor sets inside inner loops
  (`src/frame_properties.jl:113-121, 148-159`).
- Abstract `Formula` fields → dynamic dispatch/boxing in `satisfies`
  (measured 112 B/Box evaluation). Acceptable for teaching scale; listed
  for completeness.

---

## 5. Tests & tooling

- **23 of 172 exports never appear in runtests.jl**, including
  `TableauSystem`, `tableau_rules`, `Sign` types, `EPISTEMIC_*`,
  `SYSTEM_K4/K5`, `frame_predicate`, `modal_closure`, `AxiomSchema`,
  `ModalSystem`, `visualize_model`, and the `is_derivable_from` deprecation
  shim.
- **Zero extension tests** — b81129d's runtime MethodError shipped because
  nothing loads the ext in CI. One smoke test
  (`visualize_model(model) isa Figure`) in a Makie-enabled CI job catches
  the whole class.
- Monolithic `test/runtests.jl`: no per-chapter files, so the 80s
  Decidability testset always runs; no way to iterate on one chapter.
- `Project.toml`: `Test` in `[extras]` lacks a compat entry (Aqua/registry
  lint flags this); no Aqua.jl run; `CairoMakie = "0.15"` pins a fast-moving
  minor with no CI coverage to validate bumps.

---

## 6. Refactoring plan

Ordered so every phase lands green tests before the next; Phase 0 items are
independent hotfixes, each small enough for a single commit + regression
test. Phases 1–2 are the real architectural payoff; 3–4 are quality/perf.

### Phase 0 — Correctness hotfixes (do first, before any restructuring)
Each with a regression test reproducing the confirmed failure:
1. **TABLEAU_KB**: drop the T-rules (C1). One-line fix, verified safe.
2. **Close on `T ⊥`** (and dually F ⊤) in `is_closed` (C3).
3. **Blocking**: make it a `TableauSystem` capability (off for
   K/KT/KD/KB), and within blocking systems re-evaluate blocked prefixes
   when their content grows (or move the check to saturation) (C2). This is
   the trickiest Phase-0 item — write the failing K-theorems as tests
   first.
4. **Overflow guards**: replace `2^n`-style counts with checked arithmetic
   or restructured iteration (`Iterators.product` of per-variable subset
   iterators) in `is_valid_on_frame`, `is_tautology`,
   `is_decidable_within` (C4).
5. **common_knowledge**: seed the BFS with successors of w, not w itself
   (C5); add a non-reflexive-frame test.
6. **Unsupported tableau operators throw** instead of silently failing to
   prove (C6). (Real 𝐇/𝐏/Since/Until rules are Phase 2.)
7. **KripkeFrame inner constructor**: nonempty W, R ⊆ W×W, uniform
   `ArgumentError`s; validate V(p) ⊆ W in `KripkeModel`; same for
   `EpistemicFrame` (M1). This single choke point also fixes the
   `is_universal`/`is_serial` wrong answers.
8. **Honest bounded-checking API**: `is_entailed_by`/`is_consistent`
   docstrings state one-sidedness; preferably return a witness/countermodel
   or `missing` when the bound is inconclusive; `tableau_proves` signals
   `max_steps` exhaustion distinctly; fix/remove
   `has_finite_model_property`; rename/re-document `modal_closure`; fix
   `is_decidable_within` return doc (C7, M7, M8).
9. Small contract fixes: `accessible` returns a copy; `is_valid(f, m)`
   singleton method; temporal world-membership checks; fix the
   `all_saturated` dead code so returned tableaux have all branches
   completed or are marked partial (M3, M10).

### Phase 1 — Generic formula traversal (unlocks everything else)
Introduce a two-method protocol per Formula node: `children(φ)` and a
reconstructor (`similar_node(φ, new_children)`). Then derive **generically**:
`atoms`, `subformulas`, `substitute`, `is_modal_free`, structural
`==`/`hash` (replacing the M2 catch-all with
`typeof(a)===typeof(b) && children equal`), and `show` where feasible.
- Collapses the N×M matrix (A3): a new Formula subtype implements 2 methods
  and gets the whole Ch4/5 toolchain.
- Fixes M9 (temporal/epistemic MethodErrors) as a side effect.
- Pure addition + mechanical deletion; test suite is the safety net.

### Phase 2 — Logic variants as configurations (the CLAUDE.md principle)
1. **Pluggable accessibility**: make `satisfies` resolve accessibility
   through a hook (e.g. `accessible(model, world, operator)`); `Knowledge`
   becomes Box indexed by agent. Delete the duplicated boolean clauses in
   `epistemic.jl`; make `EpistemicModel` wrap or alias `KripkeModel` the way
   `TemporalModel` already does (A1). Mixed Box/Knowledge formulas start
   working.
2. **Parametrize tableau rules over operator pairs** `(BoxT, DiamondT)`:
   `apply_box_*`/`apply_T_*`/`apply_4_*` become one implementation;
   `TABLEAU_KDt` becomes a pure rule configuration; delete ~150 lines of
   `temporal.jl` copies and the hardcoded temporal `elseif` dispatch in the
   engine (A2). ⚠️ CLAUDE.md requires a written, approved plan before
   connecting `ModalSystem` and `TableauSystem` — this phase touches that
   boundary, so write that design note first and keep the two objects
   separate unless the note is approved.
3. **Real epistemic systems**: promote `EPISTEMIC_*` to frame-condition
   bundles with a validator mirroring `SYSTEM_*` (M6).
4. **Past/binary temporal rules**: converse-prefix ν/π rules for 𝐇/𝐏
   (+ Until/Since if in scope), replacing the Phase-0 throw (C6).
5. Delete `is_transitive_frame`/`is_dense_frame`/`is_unbounded_future`;
   alias the Chapter-2 predicates (A2).

### Phase 3 — Decomposition & performance
1. Split `src/tableaux.jl` along its existing section markers →
   `prefixes.jl` / `rules.jl` / `systems.jl` / `engine.jl` /
   `countermodel.jl` (A4). Extract the thrice-repeated world-creating-rule
   block in `_apply_all_rules` into one helper.
2. Split `test/runtests.jl` into per-chapter `test/test_chN_*.jl` includes;
   add Aqua.jl; add a Makie CI job with an ext smoke test; add compat for
   `Test` (Section 5).
3. Tableau branch structure: batch-copy `append_formula`, children index,
   incremental closure detection, stop resetting `expanded`.
4. Enumeration: UInt16/UInt64 bitmasks + reused buffers in
   `_enumerate_frames`/`_enumerate_valuations`; drop the `_dummy` atom;
   truth-signature pass in filtrations.

### Phase 4 — API polish
`KripkeModel(frame)` convenience constructor in core (decouples the ext from
valuation types, A5); FO `==`/`hash` (M5); `standard_translation` fresh-var
collision fix (M4 — arguably Phase 0 grade if the 2-arg form is used in
notebooks); ext `positions` kwarg conversion + friendly missing-world error;
`==`/`hash`/`show` for frames/models; document the `Atom(0)`/`Atom(:p0)`
namespace sharing.

### JOSE note
C1–C7 belong in `notes/validation-log.md` (the two-track audit trail): the
KB soundness bug and the blocking incompleteness are exactly the class of
disagreement-with-B&D the human-validation guide targets, and the standard
theorem/non-theorem battery that *does* pass (below) belongs on the
positive-confirmation track.

---

## 7. Verified correct (positive confirmations, dropped suspicions)

- Standard tableau battery passes: K axiom in K; T in KT; 4 in S4; 5 in S5;
  B in KB; D in KD; □p→p ⊬ K; p→□p ⊬ KT; 4 ⊬ K.
- Tableau branch copying: no cross-branch mutable aliasing found
  (`append_formula` and both rule paths copy before return).
- Frame-property quantifier structure (reflexive/symmetric/transitive/
  serial/euclidean, partial-functional/functional/weakly-dense/
  weakly-connected/weakly-directed) matches B&D Table frd.2, spot-checked
  positive and negative.
- Sahlqvist table T/D/B/4/5 (`axioms.jl:207-212`); all seven `is_instance`
  matchers incl. Dual both orderings; S4 = KT4, S5 = KT5; `dual` correct on
  all connectives; `substitute` capture-safe (no binders in modal language);
  skeleton-based tautological-instance check sound and complete for the
  base language.
- Canonical accessibility direction (□⁻¹Δ ⊆ Δ′) correct; finest/coarsest
  filtrations match B&D 5.7/5.9 and pass `filtration_lemma_holds`;
  frame/valuation bit-encoding complete, no double-count; local (not
  global) consequence per Def 3.36; C₁∧C₃ transitivity verified; truth
  lemma holds on repro.
- Past-operator direction in temporal semantics is correct (H/P use the
  converse relation).
- `_enumerate_frames` is the single frame-enumeration implementation (no
  duplication); semantics.jl is fully parametric — no frame conditions
  hardcoded in the core.
