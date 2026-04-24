# Human Validation Guide for Gamen.jl

## Why human validation matters

Gamen.jl has three layers of validation, each catching different kinds of errors:

- **Compiler / runtime**: Julia checks types, parses the syntax, and surfaces `MethodError` at runtime when a dispatch is missing. Unlike Haskell's GHC, Julia does **not** exhaustively check pattern matches — if you add a 9th `Formula` subtype, `satisfies` will only fail at runtime on the path that exercises it. This makes the "silent gap" risk higher than in gamen-hs.
- **Tests**: 518 `@test`s across 18 top-level `@testset`s in `test/runtests.jl` verify specific evaluations against known answers. But the tests were largely generated alongside the code, so they can encode the same misunderstandings — a self-consistent semantics + self-consistent tests can still be wrong.
- **Human review**: Whether the semantics *actually match B&D*. This is what neither the Julia runtime nor the test suite can verify.

A concrete example from the sister project: a multi-model code review of gamen-hs found that the `Since` and `Until` operators had their argument roles reversed from the standard temporal-logic convention. The code was internally consistent (all tests passed) but disagreed with Definition 14.5. The corresponding fix in Gamen.jl was straightforward once the paper was held next to the code — but only because a human did that side-by-side read. `fact-check-notebook` can help for notebooks, but the source code still needs human eyes.

## 1. Paper-to-code audit (highest value)

Pick one module at a time. Open `notes/bd-screen.pdf` alongside the source file and check each definition.

| Module                 | Paper reference                         | Key definitions to verify |
|------------------------|-----------------------------------------|---------------------------|
| `formulas.jl`          | B&D Def 1.1, 1.3                        | Constructor set matches the syntax; `Bottom`/`Top` duality; `Iff` abbreviation |
| `kripke.jl`            | B&D Def 1.4, 1.6                        | `KripkeFrame`, `KripkeModel`, `accessible` — relation stored `w => w'` means `wRw'` |
| `semantics.jl`         | B&D Def 1.7, 1.9, 1.23                  | `satisfies` clauses 1–8 (especially `Box`/`Diamond` quantifiers), `is_true_in`, `entails` |
| `frame_properties.jl`  | B&D Ch. 2, frd.\* (Table 2.1 / 2.2)     | `is_reflexive`, `is_symmetric`, `is_transitive`, `is_serial`, `is_euclidean`, `is_weakly_connected`, `is_weakly_directed` |
| `fol.jl`               | B&D Def frd.15 (standard translation)   | `standard_translation` of □/◇ uses the correct guarded quantifiers over Rxy |
| `axioms.jl`            | B&D Ch. 3, Table 3.1                    | Axiom schemas K, Dual, T, D, B, 4, 5; `ModusPonens`, `Necessitation`; system constants match the Sahlqvist table |
| `completeness.jl`      | B&D Ch. 4                               | `is_consistent`, `is_complete_consistent`, `lindenbaum_extend`, `canonical_model`, `truth_lemma_holds` |
| `filtrations.jl`       | B&D Ch. 5 (Def 5.13, Thm 5.17)          | `finest_filtration`, `coarsest_filtration`, `symmetric_filtration`, `transitive_filtration`, `has_finite_model_property`, `is_decidable_within` |
| `tableaux.jl`          | B&D Ch. 6, Tables 6.1–6.4; Fitting 1999 | Propositional rules (Table 6.1); □/◇ rules (6.2); T/D/B/4/5 rules (6.3); branch closure, prefix management, countermodel extraction |
| `temporal.jl`          | B&D Def 14.2–14.5, Table 14.1           | H/P/G/F quantifiers over predecessors vs successors; `Since`/`Until` argument roles (recently re-verified in gamen-hs); frame conditions; `TABLEAU_KDt` |
| `epistemic.jl`         | B&D Ch. 15                              | `Knowledge`, `Announce`, `restrict_model`, `group_knows`, `common_knowledge`, `is_bisimulation` |

**Method**: For each definition in B&D, find the corresponding function and check that the quantifiers (`all` vs `any`), accessibility direction, and logical structure match exactly. In Julia, pay special attention to:

- `accessible(frame, w)` returns successors of `w` (worlds `w'` with `wRw'`). Past-temporal operators (`PastBox`, `PastDiamond`, `Since`) iterate *all worlds* and check the predecessor condition — a subtle easy-to-invert pattern worth re-reading in `temporal.jl:157–217`.
- `satisfies(::KripkeModel, ::Symbol, ::Bottom)` *must* return `false` unconditionally. Check that every new formula type has its own `satisfies` method — Julia will not warn you if one is missing.

## 2. Hand-worked examples in the Julia REPL

Build small models by hand (pen and paper first), work out the truth values manually, then check against the code.

```bash
julia --project
```

```julia
using Gamen

# Build a model you've worked out on paper
fr = KripkeFrame([:w1, :w2], [:w1 => :w2, :w2 => :w1])
m  = KripkeModel(fr, Dict(:p => Set([:w1])))

# Check your hand-computed answers
satisfies(m, :w1, Box(Atom(:p)))      # you expect: ?
satisfies(m, :w2, Diamond(Atom(:p)))  # you expect: ?
```

For temporal models, try building something different from the test examples:

```julia
# A three-point linear time model: t1 ≺ t2 ≺ t3, with p only at t2
fr = KripkeFrame([:t1, :t2, :t3], [:t1 => :t2, :t2 => :t3, :t1 => :t3])
m  = TemporalModel(fr, Dict(:p => Set([:t2])))

satisfies(m, :t1, 𝐅(Atom(:p)))              # expect true  (eventually p)
satisfies(m, :t1, 𝐆(Atom(:p)))              # expect false (not always p)
satisfies(m, :t3, 𝐏(Atom(:p)))              # expect true  (previously p)
satisfies(m, :t1, Until(Atom(:p), Top()))   # expect true  (p is reachable)
```

The Figure 1.1 model in `runtests.jl` and the temporal/epistemic examples in the Pluto notebooks are good starting points before building your own. For deontic-temporal interaction, the `TABLEAU_KDt` system (`src/temporal.jl:391`) is worth exercising by hand on small examples — it is the newest piece and the one where Phase 1 collapses deontic and temporal accessibility into a single relation.

## 3. Countermodel inspection

When a tableau reports a formula is *not* valid, extract the countermodel and verify by hand that it really is a counterexample:

```julia
using Gamen
p = Atom(:p)
tab = build_tableau(TABLEAU_K, [pf_false(Prefix([1]), Implies(Box(p), p))]; max_steps=1000)
open_branches = filter(b -> !is_closed(b), tab.branches)
cm = extract_countermodel(first(open_branches))
# inspect: does this model actually falsify □p → p?
```

Draw the model's worlds and accessibility relation on paper. Check that `Box(p)` is true at the designated world but `p` is false there. If it doesn't work out, there's a bug in `extract_countermodel` or in the rule that closed (or failed to close) the branch. Visualization helps:

```julia
import CairoMakie, GraphMakie, Graphs
visualize_model(cm)
```

## 4. Known theorems as smoke tests

Validate that known logical relationships hold:

```julia
using Gamen
p, q = Atom(:p), Atom(:q)

# Modal logic schemas (all should be true)
tableau_proves(TABLEAU_K,  [], Implies(Box(Implies(p, q)), Implies(Box(p), Box(q))))  # K
tableau_proves(TABLEAU_KT, [], Implies(Box(p), p))                                    # T
tableau_proves(TABLEAU_S5, [], Implies(Diamond(p), Box(Diamond(p))))                  # 5
tableau_proves(TABLEAU_KD, [], Implies(Box(p), Diamond(p)))                           # D

# Consistency checks
tableau_consistent(TABLEAU_K,  [Box(p), Diamond(Not(p))])   # true  (satisfiable in K)
tableau_consistent(TABLEAU_KT, [Box(p), Diamond(Not(p))])   # false (unsatisfiable in KT)

# Temporal smoke tests (TABLEAU_KDt: reflexive + transitive for 𝐆/𝐅, serial for □/◇)
tableau_proves(TABLEAU_KDt, [], Implies(𝐆(p), p))            # expect true  (T for time)
tableau_proves(TABLEAU_KDt, [], Implies(𝐆(p), 𝐆(𝐆(p))))      # expect true  (4 for time)
tableau_proves(TABLEAU_KDt, [], Implies(Box(p), Diamond(p))) # expect true  (D for deontic)
```

Cross-check a few of the Sahlqvist correspondences against `frame_predicate` in `axioms.jl` — pick a small frame, evaluate the first-order predicate by hand, and confirm the schema is valid on that frame iff the predicate holds.

## 5. Cross-validate against gamen-hs

For modules that exist in both projects (basic modal logic, Kripke semantics, frame properties, tableau, K/T/D/B/4/5 systems), build the same model in both and compare:

```julia
# Julia (Gamen.jl)
fr = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w2 => :w3])
m  = KripkeModel(fr, Dict(:p => Set([:w1, :w2]), :q => Set([:w3])))
satisfies(m, :w1, Box(Atom(:p)))
```

```haskell
-- Haskell (gamen-hs)
let fr = mkFrame ["w1","w2","w3"] [("w1","w2"),("w2","w3")]
let m  = mkModel fr [("p",["w1","w2"]),("q",["w3"])]
satisfies m "w1" (Box (Atom "p"))
```

Any divergence is a bug in one or both. Note that gamen-hs extends beyond Gamen.jl (STIT phases 1–4, XSTIT mens rea, DeonticStit) — only cross-validate the overlapping modules. Conversely, Gamen.jl has modules with no Haskell counterpart (`completeness.jl` with canonical models, `filtrations.jl`, the standard translation in `fol.jl`) — those need paper-to-code audit rather than cross-validation.

## 6. Notebook validation (Gamen.jl-specific)

Pluto notebooks under `notebooks/pluto/` are a first-class artifact for the JOSE submission. They are validated separately:

- `/fact-check-notebook chN` runs the fact-check skill on a single chapter notebook — it checks logical correctness, notation consistency (e.g., wRw' convention), rendering, pedagogical completeness, and B&D alignment. Reports land in `notebooks/reviews/` (gitignored).
- Execute every notebook end-to-end in Pluto (not just the exported HTML) before a release — static rendering can hide cells that would error at runtime.
- Verify that `import CairoMakie, GraphMakie, Graphs` (not `using`) appears wherever visualization is called — the `using` form causes `Box`/`Bottom` ambiguity and is a frequent regression.
- Jupyter mirrors (`notebooks/jupyter/`) are generated from Pluto via `scripts/pluto_to_jupyter.jl`. Spot-check one or two after regeneration; conversion can silently drop reactive bindings.

## Priority order

1. **Paper-to-code audit** — highest value; only a human with domain expertise can do this.
2. **Hand-worked examples** — catches semantic errors that tests and paper-audit might both miss (especially past-temporal operators and `Since`/`Until`).
3. **Countermodel inspection** — validates the proof engine end-to-end.
4. **Known theorems** — quick smoke tests for system-level correctness.
5. **Cross-validation with gamen-hs** — catches porting and convention errors.
6. **Notebook validation** — required before the JOSE submission; lower urgency for day-to-day development.

## Modules most in need of review

- **`temporal.jl`** — past-temporal operators (`PastBox`, `PastDiamond`, `Since`) iterate all worlds and test the predecessor condition by hand; easy to invert. The `TABLEAU_KDt` system is newest and collapses deontic + temporal accessibility into a single relation as Phase 1; the Phase 2 plan for multi-relational prefixes is in `notes/combined_deontic_temporal_tableau.md`.
- **`tableaux.jl`** — 1,197 lines, the largest module. Ancestor-based blocking (see `CLAUDE.md` "Tableau Blocking") is subtle: Strategy A skips blocked prefixes during world creation, Strategy B skips formulas at blocked prefixes in the Priority-1 scan. Re-read `notes/tableau_splitrule_bug.md` for the known failure mode.
- **`completeness.jl`** — canonical model construction, `lindenbaum_extend`, and `truth_lemma_holds` are the most conceptually dense; any off-by-one in the closure construction shows up only as soundness or completeness failures on specific formulas.
- **`filtrations.jl`** — `is_decidable_within` is **O(2^(n²))** (see the CLAUDE.md performance warning). Verify the enumeration is actually exhaustive for the stated `max_worlds`, not silently truncated.

## What to report

If you find a discrepancy between the paper and the code:

1. Note the paper, definition/theorem number, and the specific quantifier or relation that differs.
2. Note the file, line number, and function name (e.g., `temporal.jl:182 satisfies(::TemporalModel, ::Symbol, ::Since)`).
3. Check whether the test for that function encodes the same error (likely yes — grep `test/runtests.jl` for the function name or the surrounding `@testset` title).
4. Check whether the corresponding Pluto notebook asserts or relies on the wrong behaviour.
5. Check whether gamen-hs has the same issue — a single fix may need to land in both repos.
6. File an issue or fix directly; reference B&D definition numbers in the commit message (project convention).
