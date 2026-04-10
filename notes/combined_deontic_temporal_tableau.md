# Combined Deontic-Temporal Tableau Proving in Gamen.jl

## Goal

Implement a combined deontic-temporal proof system (TABLEAU_KDt) that can reason about formulas mixing deontic operators (Box/Diamond as obligation/permission) with temporal operators (FutureBox/FutureDiamond/PastBox/PastDiamond). This enables automated detection of conflicts like:

- `O(𝐅p) ∧ 𝐆(¬p)` — "obligatory that p eventually holds" but "p never holds" → inconsistent
- `𝐆(O(p)) → O(p)` — "always obligatory implies currently obligatory" → provable (with temporal reflexivity)
- Clinical: "blood cultures must be drawn before antibiotics" + "antibiotics must be given immediately" → temporal conflict

## Current Architecture

### What exists

The tableau prover uses **prefixed formulas** — pairs of a `Prefix` (world name) and a signed formula. Prefixes are sequences of positive integers (`[1]`, `[1,2]`, `[1,2,3]`) encoding an accessibility tree. Parent-child relationships in the prefix tree represent the single accessibility relation R.

**Key structures** (`src/tableaux.jl`):

- `Prefix` (line 14): `struct Prefix; seq::Vector{Int}; end`
- `extend(σ, n)` (line 28): creates child prefix `σ.n`
- `fresh_prefix(branch, σ)` (line 161): finds unused child `σ.n`
- `parent_prefix(σ)` (line 45): returns parent of `σ.n`

**Rule types:**
- `StackRule`: adds formulas to current branch (non-branching)
- `SplitRule`: creates two branches (disjunctive)
- `NoRule`: no rule applies

**Modal rules** (all use single implicit relation):
- `apply_box_true_rule` (line 280): `σ T □A` → add `σ.n T A` for existing children
- `apply_box_false_rule` (line 305): `σ F □A` → create fresh child `τ`, add `τ F A`
- `apply_diamond_true_rule` (line 319): `σ T ◇A` → create fresh child `τ`, add `τ T A`
- `apply_diamond_false_rule` (line 333): `σ F ◇A` → add `σ.n F A` for existing children

**Frame condition rules:**
- T (reflexivity): `σ T □A` → `σ T A` (line 359)
- B (symmetry): `σ.n T □A` → `σ T A` via parent (line 412)
- 4 (transitivity): `σ T □A` → `σ.n T □A` for children (line 442)
- D (seriality): `σ T □A` → `σ T ◇A` as witness rule (line 386)

**TableauSystem** (line 567):
```julia
struct TableauSystem
    name::Symbol
    used_prefix_rules::Vector{Function}   # frame conditions (T, B, 4)
    witness_rules::Vector{Function}       # world-creating conditions (D)
end
```

**Systems defined:**
- `TABLEAU_K` (line 579): no extra rules
- `TABLEAU_KD` (line 596): witness rules `[apply_D_box_rule, apply_D_diamond_rule]`
- `TABLEAU_KT` (line 587): used-prefix rules `[apply_T_box_rule, apply_T_diamond_rule]`
- `TABLEAU_S4` (line 624): T + 4 rules

**Rule priority in `_apply_all_rules`** (line 652):
1. Propositional + used-prefix modal rules (non-world-creating)
2a. Box-false rules (world-creating)
2b. Diamond-true rules (world-creating)
2c. Witness rules (D seriality)

### What temporal operators have now

Temporal types (`src/temporal.jl`): `FutureBox`, `FutureDiamond`, `PastBox`, `PastDiamond`, `Since`, `Until` — all are `<: Formula`.

They have:
- Semantic evaluation via `satisfies()` — works on Kripke models
- No tableau rules whatsoever

The `satisfies` implementations (`src/temporal.jl:157-217`) use the **same single accessibility relation** as Box/Diamond. `FutureBox`/`FutureDiamond` check successors (like Box/Diamond), while `PastBox`/`PastDiamond` check predecessors (reverse direction).

### The gap

1. No tableau rules for temporal operators → can't prove temporal theorems
2. Single accessibility relation → can't distinguish deontic from temporal accessibility
3. No multi-relational prefix system → can't track which relation created each world

## Design: Labeled Prefixes (Approach A)

### Core idea

Extend the prefix system so each step carries a **relation label**. Currently `[1, 2, 3]` is an unlabeled chain. With labels: `[(1,:root), (2,:d), (3,:t)]` — world 2 is a deontic successor of 1, world 3 is a temporal successor of 2.

Each operator only sees successors created by its own relation:
- `Box`/`Diamond` see `:deontic` children
- `FutureBox`/`FutureDiamond` see `:temporal` children
- `PastBox`/`PastDiamond` see `:temporal` parents

### Implementation plan

#### 1. Prefix system changes (`src/tableaux.jl`)

```julia
# Option A: New type alongside existing Prefix
struct LabeledPrefix
    seq::Vector{Tuple{Int, Symbol}}  # [(world_id, relation_label), ...]
end

# Option B: Extend existing Prefix (backwards compatible)
struct Prefix
    seq::Vector{Int}
    labels::Vector{Symbol}  # same length as seq, :none for unlabeled
end
```

Option B is better for backwards compatibility — existing single-relation systems use `:none` labels everywhere and behave identically to today.

New operations needed:
```julia
extend(σ::Prefix, n::Int, relation::Symbol) -> Prefix
fresh_prefix(branch, σ, relation::Symbol) -> Prefix
children_by_relation(branch, σ, relation::Symbol) -> Vector{Prefix}
parents_by_relation(branch, σ, relation::Symbol) -> Vector{Prefix}
```

The existing `extend(σ, n)` should default to `extend(σ, n, :none)` for backwards compatibility.

#### 2. Modify existing modal rules

`apply_box_true_rule` and `apply_diamond_false_rule` currently check all children. In multi-relational mode, they must filter:

```julia
function apply_box_true_rule(pf::PrefixedFormula, branch::TableauBranch)
    pf.sign isa TrueSign && pf.formula isa Box || return NoRule()
    σ = pf.prefix
    relation = :none  # default for single-relation systems
    # Only check children created via the matching relation
    children = children_by_relation(branch, σ, relation)
    # ... rest of logic unchanged
end
```

For TABLEAU_KDt, `Box` rules use `:deontic` and temporal rules use `:temporal`. This can be parameterized through the `TableauSystem`.

#### 3. New temporal tableau rules

Eight new rule functions, following the same pattern as the existing modal rules:

**Future operators (analogous to Box/Diamond but for temporal relation):**

```julia
# 𝐆-true: σ T 𝐆A → add σ.n_t T A for each temporal child σ.n_t
#          also add σ.n_t T 𝐆A (propagation for transitivity)
function apply_futurebox_true_rule(pf, branch)
    pf.sign isa TrueSign && pf.formula isa FutureBox || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    additions = PrefixedFormula[]
    for τ in children_by_relation(branch, σ, :temporal)
        pf_A = pf_true(τ, A)
        pf_GA = pf_true(τ, FutureBox(A))  # propagate for transitivity
        pf_A ∈ branch.formulas || push!(additions, pf_A)
        pf_GA ∈ branch.formulas || push!(additions, pf_GA)
    end
    isempty(additions) ? NoRule() : StackRule(additions)
end

# 𝐆-false: σ F 𝐆A → create fresh temporal child τ, add τ F A
function apply_futurebox_false_rule(pf, branch)
    pf.sign isa FalseSign && pf.formula isa FutureBox || return NoRule()
    σ = pf.prefix
    τ = fresh_prefix(branch, σ, :temporal)
    StackRule([pf_false(τ, pf.formula.operand)])
end

# 𝐅-true: σ T 𝐅A → create fresh temporal child τ, add τ T A
function apply_futurediamond_true_rule(pf, branch)
    pf.sign isa TrueSign && pf.formula isa FutureDiamond || return NoRule()
    σ = pf.prefix
    τ = fresh_prefix(branch, σ, :temporal)
    StackRule([pf_true(τ, pf.formula.operand)])
end

# 𝐅-false: σ F 𝐅A → add σ.n_t F A and σ.n_t F 𝐅A for each temporal child
function apply_futurediamond_false_rule(pf, branch)
    pf.sign isa FalseSign && pf.formula isa FutureDiamond || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    additions = PrefixedFormula[]
    for τ in children_by_relation(branch, σ, :temporal)
        pf_A = pf_false(τ, A)
        pf_FA = pf_false(τ, FutureDiamond(A))  # propagate
        pf_A ∈ branch.formulas || push!(additions, pf_A)
        pf_FA ∈ branch.formulas || push!(additions, pf_FA)
    end
    isempty(additions) ? NoRule() : StackRule(additions)
end
```

**Past operators (reverse direction — check temporal parents):**

```julia
# 𝐇-true: σ T 𝐇A → add σ' T A and σ' T 𝐇A for each temporal parent σ'
function apply_pastbox_true_rule(pf, branch)
    pf.sign isa TrueSign && pf.formula isa PastBox || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    additions = PrefixedFormula[]
    for τ in parents_by_relation(branch, σ, :temporal)
        pf_A = pf_true(τ, A)
        pf_HA = pf_true(τ, PastBox(A))
        pf_A ∈ branch.formulas || push!(additions, pf_A)
        pf_HA ∈ branch.formulas || push!(additions, pf_HA)
    end
    isempty(additions) ? NoRule() : StackRule(additions)
end

# 𝐇-false: σ F 𝐇A → create fresh temporal predecessor, add τ F A
# Note: "temporal predecessor" means τ such that τ --temporal--> σ
# This requires creating a new world and adding σ as its temporal child
function apply_pastbox_false_rule(pf, branch)
    pf.sign isa FalseSign && pf.formula isa PastBox || return NoRule()
    # Implementation requires reverse prefix creation — see discussion below
end

# 𝐏-true: σ T 𝐏A → create fresh temporal predecessor, add τ T A
function apply_pastdiamond_true_rule(pf, branch)
    pf.sign isa TrueSign && pf.formula isa PastDiamond || return NoRule()
    # Same reverse prefix issue
end

# 𝐏-false: σ F 𝐏A → add σ' F A and σ' F 𝐏A for each temporal parent σ'
function apply_pastdiamond_false_rule(pf, branch)
    pf.sign isa FalseSign && pf.formula isa PastDiamond || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    additions = PrefixedFormula[]
    for τ in parents_by_relation(branch, σ, :temporal)
        pf_A = pf_false(τ, A)
        pf_PA = pf_false(τ, PastDiamond(A))
        pf_A ∈ branch.formulas || push!(additions, pf_A)
        pf_PA ∈ branch.formulas || push!(additions, pf_PA)
    end
    isempty(additions) ? NoRule() : StackRule(additions)
end
```

**Past predecessor creation**: The H-false and P-true rules need to create temporal predecessors — a world `τ` such that `τ →_t σ`. In a prefix tree, this is unnatural (children are successors, not predecessors). Two options:
- Store an explicit relation table `temporal_edges::Set{Tuple{Prefix,Prefix}}` alongside the prefix tree
- Create `τ` as a fresh root-level prefix and record the edge separately

#### 4. Temporal frame condition rules

```julia
# Temporal reflexivity (T axiom for time): σ T 𝐆A → σ T A
function apply_temporal_reflexivity_box(pf, branch)
    pf.sign isa TrueSign && pf.formula isa FutureBox || return NoRule()
    addition = pf_true(pf.prefix, pf.formula.operand)
    addition ∈ branch.formulas ? NoRule() : StackRule([addition])
end

# Temporal reflexivity dual: σ F 𝐅A → σ F A
function apply_temporal_reflexivity_diamond(pf, branch)
    pf.sign isa FalseSign && pf.formula isa FutureDiamond || return NoRule()
    addition = pf_false(pf.prefix, pf.formula.operand)
    addition ∈ branch.formulas ? NoRule() : StackRule([addition])
end
```

Transitivity is handled by the propagation in the G-true and F-false rules (they add `𝐆A`/`𝐅A` at children, which then propagate further).

#### 5. Define TABLEAU_KDt

```julia
TABLEAU_KDt = TableauSystem(
    :KDt,
    Function[
        # Deontic frame conditions (none for K; D is a witness rule)
        # Temporal frame conditions
        apply_temporal_reflexivity_box,
        apply_temporal_reflexivity_diamond,
        # Temporal used-prefix rules (analogous to Box-true/Diamond-false)
        apply_futurebox_true_rule,
        apply_futurediamond_false_rule,
        apply_pastbox_true_rule,
        apply_pastdiamond_false_rule,
    ],
    Function[
        # Deontic seriality (D axiom)
        apply_D_box_rule,
        apply_D_diamond_rule,
        # Temporal world-creating rules
        apply_futurebox_false_rule,
        apply_futurediamond_true_rule,
        apply_pastbox_false_rule,
        apply_pastdiamond_true_rule,
    ]
)
```

This may require adjusting `_apply_all_rules` priority so temporal world-creating rules slot in alongside box-false/diamond-true at Priority 2.

#### 6. Semantics changes

For semantic evaluation to match the tableau, `KripkeModel` needs multi-relational support:

```julia
struct MultiRelationalFrame
    worlds::Vector{Symbol}
    relations::Dict{Symbol, Vector{Pair{Symbol,Symbol}}}  # :deontic => [...], :temporal => [...]
end

# Or simpler: add a second relation to existing KripkeFrame
struct KripkeFrame
    worlds::Vector{Symbol}
    relations::Vector{Pair{Symbol,Symbol}}
    temporal_relations::Vector{Pair{Symbol,Symbol}}  # new
end
```

Then `satisfies` for `Box`/`Diamond` uses `relations` and `satisfies` for temporal operators uses `temporal_relations`.

#### 7. Countermodel extraction

`extract_countermodel` (line 878) builds a `KripkeModel` from an open branch. Must be extended to produce two relations by reading prefix labels:

```julia
function extract_countermodel(branch::TableauBranch)
    prefixes = used_prefixes(branch)
    worlds = [Symbol("w$(join(p.seq, '_'))") for p in prefixes]
    
    deontic_relations = Pair{Symbol,Symbol}[]
    temporal_relations = Pair{Symbol,Symbol}[]
    
    for p in prefixes
        for i in 1:(length(p.seq)-1)
            parent_world = ...
            child_world = ...
            if p.labels[i+1] == :deontic
                push!(deontic_relations, parent_world => child_world)
            elseif p.labels[i+1] == :temporal
                push!(temporal_relations, parent_world => child_world)
            end
        end
    end
    
    MultiRelationalModel(
        MultiRelationalFrame(worlds, 
            Dict(:deontic => deontic_relations, :temporal => temporal_relations)),
        valuation
    )
end
```

#### 8. `_apply_all_rules` changes

The current priority system needs temporal rules inserted:

1. Propositional + used-prefix rules (including temporal used-prefix rules)
2a. Box-false (deontic world creation)
2b. Diamond-true (deontic world creation)
2c. FutureBox-false / FutureDiamond-true (temporal world creation)
2d. PastBox-false / PastDiamond-true (temporal predecessor creation)
2e. Witness rules (D seriality for deontic)

The simplest approach: temporal world-creating rules go in `witness_rules` and are applied at Priority 2c alongside D-seriality. The existing dispatch already iterates all witness rules.

## Hard Problems

### Termination

The 𝐆-true rule propagates `𝐆A` to temporal children. Each new temporal child (from 𝐅-true or 𝐆-false) triggers 𝐆-true again. Without a blocking condition, this loops.

**Solution**: The existing `max_steps` parameter provides a coarse bound. For a proper solution, implement **loop checking** — if a prefix `σ.n_t` has the same set of formulas as an ancestor, stop expanding it (the subtableau would repeat). This is standard in temporal tableau implementations (Wolper 1985, Goré & Widmann 2009).

### Past operators and prefix direction

Prefix trees are naturally forward-looking (parent → child = accessible). Past operators need the reverse. Options:

1. **Track explicit edges**: Add `temporal_edges::Vector{Tuple{Prefix,Prefix}}` to `TableauBranch`. Past-predecessor creation adds an edge `(fresh, σ)` meaning "fresh is a temporal predecessor of σ."
2. **Bidirectional prefixes**: Allow "upward" extensions. Awkward but possible.
3. **Defer past operators**: Start without H/P rules. Many clinical guidelines only need future temporal reasoning ("do X before Y", "eventually reassess"). Add past operators in Phase 2.

### Since/Until

These binary temporal operators require tracking intervals, not just single successors. The tableau rules are significantly more complex:

- `σ T (A Until B)`: there exists a future `τ` where B holds, and A holds at all points between σ and τ
- This requires creating multiple new temporal worlds in sequence

**Recommendation**: Defer to Phase 3. Unary temporal operators (𝐆, 𝐅) cover most clinical guideline patterns.

### Interaction axioms

Should R_d and R_t commute? Two options:

1. **Independent** (no interaction): deontic and temporal worlds are orthogonal. `O(𝐅p)` means "in all deontically ideal worlds, p eventually holds" — the temporal and deontic dimensions don't interact.

2. **Commuting** (product frames): `O(𝐅p) ↔ 𝐅(O(p))`. Going to an ideal world then forward in time is the same as going forward in time then to an ideal world. This makes obligations persistent across time.

Independent is simpler to implement (no extra rules) and probably more appropriate for clinical guidelines — obligations can change over time (a drug that was obligatory may be discontinued).

### Linearity of time

Clinical time is linear (totally ordered), not branching. Linearity means: for any temporal successors `σ.m_t` and `σ.n_t`, either `m` precedes `n` or `n` precedes `m`. Enforcing this in a tableau requires adding ordering constraints between temporal prefixes.

**Recommendation**: Start without linearity. Branching time is a sound overapproximation — anything consistent in linear time is consistent in branching time. Add linearity constraints in Phase 2 if needed for clinical sequencing validation.

## Test Cases

After implementation, these should work:

```julia
p, q = Atom(:p), Atom(:q)

# Pure temporal (should be provable with reflexive temporal frames)
@test tableau_proves(TABLEAU_KDt, Formula[], Implies(FutureBox(p), p))
@test tableau_proves(TABLEAU_KDt, Formula[], Implies(FutureBox(p), FutureDiamond(p)))

# Combined: temporal inside deontic
@test !tableau_consistent(TABLEAU_KDt, Formula[Box(FutureDiamond(p)), Box(FutureBox(Not(p)))])
# O(𝐅p) ∧ O(𝐆¬p) → inconsistent: obligated to eventually p AND obligated to always ¬p

@test tableau_consistent(TABLEAU_KDt, Formula[Box(FutureDiamond(p)), FutureBox(Not(p))])
# O(𝐅p) ∧ 𝐆(¬p) → this is actually inconsistent too if deontic worlds share temporal structure
# (depends on interaction axioms — test after deciding on frame interaction)

# Combined: deontic inside temporal
@test tableau_proves(TABLEAU_KDt, Formula[], Implies(FutureBox(Box(p)), Box(p)))
# 𝐆(O(p)) → O(p): always obligatory implies currently obligatory (temporal reflexivity)

# D axiom still works through temporal nesting
@test tableau_proves(TABLEAU_KDt, Formula[], Implies(Box(FutureDiamond(p)), Diamond(FutureDiamond(p))))
# O(𝐅p) → P(𝐅p)

# Clinical scenario: conditional obligation with temporal constraint
consent = Atom(:consent)
procedure = Atom(:procedure)
# "Consent must be obtained before any procedure" ≈ O(𝐏consent → procedure)
# + "Procedure must eventually happen" ≈ O(𝐅procedure)
# These should be consistent
@test tableau_consistent(TABLEAU_KDt, Formula[
    Box(Implies(PastDiamond(consent), procedure)),
    Box(FutureDiamond(procedure))
])
```

## Phased Implementation

### Phase 1 (minimum viable)
- [ ] Labeled prefix system (backwards compatible)
- [ ] `children_by_relation` / `parents_by_relation` helpers
- [ ] FutureBox/FutureDiamond tableau rules (4 functions)
- [ ] Temporal reflexivity frame condition rules
- [ ] `TABLEAU_KDt` definition
- [ ] Tests for combined deontic-temporal proving
- [ ] Modify `_apply_all_rules` to dispatch temporal rules

This gives you: `O(𝐅p)`, `𝐆(O(p))`, contradiction detection for mixed formulas.

### Phase 2
- [ ] PastBox/PastDiamond tableau rules (4 functions)
- [ ] Explicit temporal edge tracking (for predecessor creation)
- [ ] Temporal linearity constraints
- [ ] Multi-relational `KripkeFrame` and `satisfies` updates
- [ ] Countermodel extraction for multi-relational models
- [ ] Loop checking / blocking for termination

### Phase 3
- [ ] Since/Until tableau rules
- [ ] Bounded temporal operators (𝐅≤n for "within N days")
- [ ] Interaction axiom support (commuting frames option)
- [ ] Performance benchmarking on guideline-sized formula sets

## References

- Zach, R. (2025). *Boxes and Diamonds*, Chapter 14: Temporal Logic. Open Logic Project.
- Wolper, P. (1985). "The Tableau Method for Temporal Logic." *Logique et Analyse*.
- Goré, R. & Widmann, F. (2009). "Optimal Tableaux for Propositional Dynamic Logic with Converse." *IJCAR*.
- Fitting, M. (1983). *Proof Methods for Modal and Intuitionistic Logics*. Reidel. (Multi-relational tableaux)
- Governatori, G. et al. (2005). "Defeasible Logic versus Standard Deontic Logic." *Synthese*. (Deontic-temporal interaction)
