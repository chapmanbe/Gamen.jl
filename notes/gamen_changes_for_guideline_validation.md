# Gamen.jl Changes for Guideline Validation (2026-04-09)

## Summary

Two commits to Gamen.jl `main` address issues found during guideline validation work and add the combined deontic-temporal proof system needed by the research plan.

## Commit 1: SplitRule Bug Fix (`5f3b460`)

### Problem

The tableau prover had a soundness bug: it falsely reported satisfiable formula sets as inconsistent when a `SplitRule` (from `Or`, `Implies`, or `Iff`) produced one branch whose formulas were already present on the tableau. The open branch was discarded and only the (potentially closing) alternative was kept.

This affected any consistency check involving conditional formulas -- central to clinical guideline validation. For example:

```julia
# These were all incorrectly reported as inconsistent:
tableau_consistent(TABLEAU_KD, Formula[Implies(p, q), Not(q)])  # false (WRONG, p=F q=F satisfies)
tableau_consistent(TABLEAU_KD, Formula[Or(p, q), Not(q)])       # false (WRONG, p=T q=F satisfies)

# Clinical example:
g4 = Implies(Atom(:active_bleeding), Box(Not(Atom(:thrombolytic))))
g7 = Box(Atom(:thrombolytic))
tableau_consistent(TABLEAU_KD, Formula[g4, g7])  # false (WRONG, active_bleeding=false satisfies)
```

### Fix

In `_apply_all_rules` (`src/tableaux.jl`), when one arm of a split adds formulas already present on the branch, the code now skips re-splitting (`continue`) instead of discarding the current branch. The unchanged branch IS the open arm of a previous split.

### Impact

All tableau systems are affected (K, KT, KD, KB, K4, S4, S5). After this fix, conditional obligations like "must not X if Y" are correctly handled. Seven regression tests added.

## Commit 2: Combined Deontic-Temporal Tableau (`c9de52e`)

### What's new

`TABLEAU_KDt` -- a tableau system for combined deontic-temporal logic:
- Deontic operators (Box/Diamond) with serial frames (D axiom)
- Temporal operators (FutureBox/FutureDiamond) with reflexive + transitive frames

This enables automated consistency checking and theorem proving for formulas mixing obligation/permission with always/eventually:

```julia
using Gamen
p = Atom(:p)

# "Obligatory that p eventually holds" + "Obligatory that p never holds" -> inconsistent
!tableau_consistent(TABLEAU_KDt, Formula[Box(FutureDiamond(p)), Box(FutureBox(Not(p)))])  # true

# "Always obligatory p" implies "currently obligatory p" (temporal reflexivity)
tableau_proves(TABLEAU_KDt, Formula[], Implies(FutureBox(Box(p)), Box(p)))  # true

# D axiom preserved: O(Fp) -> P(Fp)
tableau_proves(TABLEAU_KDt, Formula[], Implies(Box(FutureDiamond(p)), Diamond(FutureDiamond(p))))  # true

# Conditional + temporal: consistent when condition can be false
tableau_consistent(TABLEAU_KDt,
    Formula[Implies(p, Box(FutureBox(Not(q)))), Box(FutureDiamond(q))])  # true
```

### Design decisions

- **Shared relation**: Phase 1 uses the same accessibility relation for deontic and temporal operators, matching the existing `TemporalModel = KripkeModel` semantics. Multi-relational prefixes (distinguishing R_deontic from R_temporal) are deferred.
- **Separated frame conditions**: Base temporal rules (propagate to/create children) are separate from frame condition rules (reflexivity, transitivity), per the project's architectural principles.
- **Witness guards**: World-creating rules now check whether a witness already exists before creating a new child. Without this, `diamond_true` would fire repeatedly on the same formula, creating infinite siblings and starving deeper formulas of processing time. This fix applies to both existing modal rules and new temporal rules.

### New functions (src/temporal.jl)

| Function | Rule |
|----------|------|
| `apply_futurebox_true_rule` | sigma T GA -> sigma.n T A (existing children) |
| `apply_futurebox_false_rule` | sigma F GA -> fresh sigma.n, sigma.n F A |
| `apply_futurediamond_true_rule` | sigma T FA -> fresh sigma.n, sigma.n T A |
| `apply_futurediamond_false_rule` | sigma F FA -> sigma.n F A (existing children) |
| `apply_temporal_T_futurebox_rule` | sigma T GA -> sigma T A (reflexivity) |
| `apply_temporal_T_futurediamond_rule` | sigma F FA -> sigma F A (reflexivity) |
| `apply_temporal_4_futurebox_rule` | sigma T GA -> sigma.n T GA (transitivity) |
| `apply_temporal_4_futurediamond_rule` | sigma F FA -> sigma.n F FA (transitivity) |

### Other fixes in this commit

- `_collect_atoms!` now recurses into temporal formula types (FutureBox, FutureDiamond, PastBox, PastDiamond, Since, Until). Previously, `extract_countermodel` silently dropped atoms nested inside temporal operators.

### Test results

534 tests pass (all 526 existing + 8 new deontic-temporal tests).

## What's NOT yet implemented

- **Past operator tableau rules** (PastBox, PastDiamond) -- requires predecessor creation in the prefix tree
- **Since/Until tableau rules** -- complex binary temporal operators
- **Multi-relational prefixes** -- needed to distinguish deontic from temporal accessibility
- **Loop checking / blocking** -- proper termination beyond `max_steps` for temporal formulas
- **Defeasible logic** -- exception handling ("normally obligatory but overridden by...")

## Next Steps for guideline-validation

### 1. Update Gamen.jl dependency

The `guideline-validation` Project.toml points to the GitHub Gamen.jl package. After these changes, either:
- Run `] up Gamen` in the guideline-validation environment to pull the latest, or
- Use `] dev ~/Code/Julia/Gamen.jl` for local development

### 2. Extend `load_guidelines` for temporal formulas

The YAML schema in `RESEARCH_PLAN.md` includes temporal fields (`temporal.type`, `temporal_op`, `anchor_atom`) but `load_guidelines` in `GuidelineValidation.jl` only constructs `Box`/`Diamond`/`Implies`. Add handling for:

```yaml
temporal:
  type: before
  anchor: initiate_antibiotics
formula:
  op: box
  atom: blood_cultures
  temporal_op: past_diamond
  anchor_atom: antibiotics
```

This means constructing formulas like `Box(Implies(Atom(:antibiotics), PastDiamond(Atom(:blood_cultures))))` from the YAML. Note: PastDiamond doesn't have tableau rules yet, but you can use the semantic evaluator (`satisfies`) on explicit models, or approximate "before" with future operators where possible.

For guidelines that only use "always" and "eventually" temporal constraints (no "before/after"), FutureBox and FutureDiamond are fully supported by `TABLEAU_KDt`.

### 3. Add a consistency checking function

`GuidelineValidation.jl` loads guidelines into `Guideline` structs but doesn't expose a function to check consistency. Add something like:

```julia
function check_consistency(guidelines::Vector{Guideline};
                           system::TableauSystem=TABLEAU_KD)
    formulas = Formula[g.formula for g in guidelines]
    tableau_consistent(system, formulas)
end
```

Use `TABLEAU_KD` for purely deontic guidelines, `TABLEAU_KDt` for guidelines with temporal constraints.

### 4. Test on existing YAML files

Run consistency checks on `data/guidelines.yaml` and `data/conflict_test.yaml` with both `TABLEAU_KD` and `TABLEAU_KDt`. The conflict test file (G6 vs G5, G7 vs thrombolytic restrictions) should now produce correct results after the SplitRule fix.

### 5. Then start the LLM extraction pipeline (Phase 2 of research plan)

The formal verification backend is ready for:
- Unconditional obligations/permissions/prohibitions
- Conditional obligations (if X then must Y)
- Temporal obligations (must always, must eventually)
- Combined (if X then must always Y)

The LLM pipeline can target this formula language for extraction from guideline PDFs.
