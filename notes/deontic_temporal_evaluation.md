# Evaluation of Combined Deontic-Temporal Tableau Proposal

## What the document gets right

1. **Labeled prefixes (Option B)** — extending `Prefix` with a `labels` vector is the right call. It's backwards-compatible and avoids a parallel type hierarchy.

2. **Phasing out past operators and Since/Until** — deferring these to Phase 2/3 is wise. Past-predecessor creation is architecturally awkward (prefixes are tree-shaped, predecessors break that), and clinical use cases mostly need future temporal reasoning.

3. **Independent relations over commuting frames** — correct for clinical guidelines. Obligations *do* change over time; commuting deontic/temporal relations would impose an unrealistic persistence.

4. **Starting without temporal linearity** — branching time is a sound overapproximation. Linearity constraints add significant complexity for marginal benefit at this stage.

## Concerns

### 1. The `EpistemicFrame` precedent is underused

The document proposes a new `MultiRelationalFrame`, but `src/epistemic.jl` already implements multi-relational frames via `EpistemicFrame` with `Dict{Symbol, Dict{Symbol, Set{Symbol}}}`. Rather than creating yet another frame type, the right move is to generalize `EpistemicFrame` into a shared `MultiRelationalFrame` that both epistemic and deontic-temporal logic can use. This avoids architectural divergence.

### 2. `_collect_atoms!` doesn't recurse into temporal formulas

The document doesn't mention this, but `extract_countermodel` will silently produce incomplete valuations for any formula containing temporal operators. This needs fixing regardless of tableau rules.

### 3. The `_apply_all_rules` modification is undersized

The document suggests temporal world-creating rules go into `witness_rules` at Priority 2c. But temporal rules have their own priority concerns — `FutureBox`-true (propagation to existing temporal children) must fire *before* `FutureBox`-false (creating new temporal children), just as `Box`-true fires before `Box`-false. The current two-slot `TableauSystem` (`used_prefix_rules` + `witness_rules`) may not have enough granularity. Consider whether a third slot or a typed rule dispatch is needed.

### 4. Loop checking is critical, not optional

The document lists `max_steps` as a fallback, but `G`-true propagation creates genuinely infinite branches without blocking. `max_steps` gives you *unsound termination* (the tableau may close or stay open incorrectly due to truncation). A proper blocking condition — "if prefix σ has the same formula set as an ancestor, stop" — should be Phase 1, not Phase 2.

### 5. The `FutureBox`-true rule conflates base rule with frame condition

The document's `FutureBox`-true rule propagates `G(A)` to children. This is the standard approach for transitive temporal relations, but it conflates the frame condition (transitivity) with the base rule. For consistency with Gamen.jl's architectural principle of *frame conditions as separate rules*, the base `FutureBox`-true rule should only add `A` at temporal children, and a separate temporal-4 rule should propagate `G(A)`. This keeps the system composable — you could have a temporal logic without transitivity.

## Recommended Phase 1 scope

1. **Fix `_collect_atoms!`** to recurse into temporal operator subformulas. Small, independent, unblocks everything else.

2. **Add relation labels to `Prefix`** (Option B). Update `extend`, `fresh_prefix`, `parent_prefix`. Ensure all existing tests still pass with default `:none` labels.

3. **Add `children_by_relation` and `parents_by_relation` helpers.** The current code does child-detection inline by comparing prefix sequences — factor this out.

4. **Implement FutureBox/FutureDiamond tableau rules only** (4 functions). No past operators yet. Keep the base rules clean (no transitivity propagation baked in) and add temporal reflexivity/transitivity as separate frame condition rules.

5. **Add loop checking / blocking** to `_apply_all_rules`. Without this, any formula containing `G` will diverge. This is not deferrable.

6. **Generalize `EpistemicFrame` into `MultiRelationalFrame`** rather than creating a third frame type. The epistemic and deontic-temporal cases have the same shape: multiple named accessibility relations over the same world set.

7. **Define `TABLEAU_KDt`** and write the test cases from the document.
