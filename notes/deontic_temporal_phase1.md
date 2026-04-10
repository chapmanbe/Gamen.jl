# Combined Deontic-Temporal Tableau: Phase 1 Implementation

## What was implemented

Phase 1 adds FutureBox (G) and FutureDiamond (F) tableau rules to Gamen.jl, enabling automated consistency and provability checking for formulas mixing deontic operators (Box/Diamond) with temporal operators.

### Design decision: shared relation

Phase 1 uses the same single accessibility relation for both deontic and temporal operators. This matches the existing `TemporalModel = KripkeModel` semantics where `satisfies` for FutureBox/FutureDiamond checks the same successors as Box/Diamond. Multi-relational prefixes (distinguishing R_d from R_t) are deferred to Phase 2.

### New tableau system

`TABLEAU_KDt` — deontic-temporal logic with:
- Deontic: serial frames (D axiom via existing `apply_D_box_rule`/`apply_D_diamond_rule`)
- Temporal: reflexive + transitive frames (T and 4 axioms for G/F)

### Files changed

**`src/temporal.jl`** — 8 new rule functions + TABLEAU_KDt definition:

| Function | Rule | Pattern |
|----------|------|---------|
| `apply_futurebox_true_rule` | sigma T GA -> sigma.n T A (existing children) | like `apply_box_true_rule` |
| `apply_futurebox_false_rule` | sigma F GA -> fresh sigma.n, sigma.n F A | like `apply_box_false_rule` |
| `apply_futurediamond_true_rule` | sigma T FA -> fresh sigma.n, sigma.n T A | like `apply_diamond_true_rule` |
| `apply_futurediamond_false_rule` | sigma F FA -> sigma.n F A (existing children) | like `apply_diamond_false_rule` |
| `apply_temporal_T_futurebox_rule` | sigma T GA -> sigma T A (reflexivity) | like `apply_T_box_rule` |
| `apply_temporal_T_futurediamond_rule` | sigma F FA -> sigma F A (reflexivity) | like `apply_T_diamond_rule` |
| `apply_temporal_4_futurebox_rule` | sigma T GA -> sigma.n T GA (transitivity) | like `apply_4_box_rule` |
| `apply_temporal_4_futurediamond_rule` | sigma F FA -> sigma.n F FA (transitivity) | like `apply_4_diamond_rule` |

Frame conditions are separated from base rules per the project's architectural principle.

**`src/tableaux.jl`** — Engine changes:

- `_collect_atoms!` now handles all temporal formula types (FutureBox, FutureDiamond, PastBox, PastDiamond, Since, Until)
- `_try_priority1_rules` dispatches `apply_futurebox_true_rule` and `apply_futurediamond_false_rule`
- Priority 2a handles `FutureBox`-false alongside `Box`-false
- Priority 2b handles `FutureDiamond`-true alongside `Diamond`-true
- New `_has_witness` helper + witness guards on all four world-creating rules (see below)

**`src/Gamen.jl`** — Exports `TABLEAU_KDt`

**`test/runtests.jl`** — 8 new test cases in "Combined deontic-temporal (TABLEAU_KDt)" testset

### Witness guard fix

During implementation, an unplanned but necessary fix was required: world-creating rules (`apply_box_false_rule`, `apply_diamond_true_rule`, and their temporal counterparts) now check whether a witness already exists before creating a new child.

**Problem**: Without this guard, `sigma T diamond(A)` at a parent prefix would fire repeatedly at Priority 2b, creating children sigma.1, sigma.2, sigma.3, ... endlessly. Each iteration consumed a step, so formulas deeper in the branch (like `sigma.1 T F(B)`) were never expanded. For simple formulas this was harmless (max_steps stopped the loop, branch stayed open, correct answer returned). But for nested deontic-temporal formulas like `{Box(FutureDiamond(p)), Box(FutureBox(Not(p)))}`, it prevented the tableau from finding the contradiction.

**Fix**: `_has_witness(branch, sigma, sign, formula)` checks if any child of sigma already has the target formula with the given sign. If so, the world-creating rule returns `NoRule()`. This is sound because existential witnesses only need one instance.

This fix applies to both existing modal rules and new temporal rules. All 526 pre-existing tests continue to pass.

## What works now

```julia
using Gamen
p, q = Atom(:p), Atom(:q)

# Pure temporal theorems
tableau_proves(TABLEAU_KDt, Formula[], Implies(FutureBox(p), p))           # true (reflexivity)
tableau_proves(TABLEAU_KDt, Formula[], Implies(FutureBox(p), FutureDiamond(p)))  # true

# Combined deontic-temporal
!tableau_consistent(TABLEAU_KDt,
    Formula[Box(FutureDiamond(p)), Box(FutureBox(Not(p)))])  # true (inconsistent)

# Deontic through temporal nesting
tableau_proves(TABLEAU_KDt, Formula[], Implies(FutureBox(Box(p)), Box(p)))  # true

# D axiom preserved
tableau_proves(TABLEAU_KDt, Formula[],
    Implies(Box(FutureDiamond(p)), Diamond(FutureDiamond(p))))  # true

# Conditional + temporal (exercises SplitRule fix from earlier commit)
tableau_consistent(TABLEAU_KDt,
    Formula[Implies(p, Box(FutureBox(Not(q)))), Box(FutureDiamond(q))])  # true
```

## What remains (Phase 2+)

See `notes/deontic_temporal_evaluation.md` for full assessment. Key items:

- **Multi-relational prefixes** — labeled prefix system to distinguish deontic from temporal accessibility
- **Past operator rules** — PastBox/PastDiamond tableau rules (requires predecessor creation)
- **Loop checking / blocking** — proper termination guarantee for temporal logics beyond max_steps
- **MultiRelationalFrame** — generalize EpistemicFrame into shared multi-relational type
- **Since/Until rules** — complex binary temporal operators
- **Countermodel extraction** — extend to distinguish temporal from deontic edges
