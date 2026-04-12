# Chapter 6: Modal Tableaux (B&D)

# ── Prefixes (Definition 6.1) ──

"""
    Prefix

A non-empty sequence of positive integers naming a world in a prefixed tableau.
Written as `1`, `1.2`, `1.2.3`, etc. (Definition 6.1, B&D).

Prefixes are the keys that connect signed formulas to worlds: if σ names a world,
then σ.n names a world accessible from σ.
"""
struct Prefix
    seq::Vector{Int}

    function Prefix(seq::Vector{Int})
        isempty(seq) && throw(ArgumentError("Prefix must be non-empty"))
        all(x -> x > 0, seq) || throw(ArgumentError("Prefix elements must be positive integers"))
        new(seq)
    end
end

Prefix(n::Int) = Prefix([n])
Prefix(ns::Int...) = Prefix(collect(ns))

"""
    extend(σ::Prefix, n::Int) -> Prefix

Return the prefix σ.n (σ extended with positive integer n).
"""
function extend(σ::Prefix, n::Int)
    n > 0 || throw(ArgumentError("Extension must be a positive integer"))
    Prefix([σ.seq; n])
end

function Base.show(io::IO, σ::Prefix)
    print(io, join(σ.seq, "."))
end

Base.:(==)(a::Prefix, b::Prefix) = a.seq == b.seq
Base.hash(σ::Prefix, h::UInt) = hash(σ.seq, h)

"""
    parent_prefix(σ::Prefix) -> Prefix

Return the prefix of length n-1 (parent of σ = τ.k is τ).
Requires length(σ.seq) > 1.
"""
function parent_prefix(σ::Prefix)
    length(σ.seq) > 1 || throw(ArgumentError("Root prefix has no parent"))
    Prefix(σ.seq[1:end-1])
end

# ── Signed prefixed formulas (Definition 6.1) ──

"""
    Sign

Truth sign: `TrueSign` (T) or `FalseSign` (F).
"""
abstract type Sign end
struct TrueSign  <: Sign end
struct FalseSign <: Sign end

const T_SIGN = TrueSign()
const F_SIGN = FalseSign()

function Base.show(io::IO, ::TrueSign);  print(io, "T"); end
function Base.show(io::IO, ::FalseSign); print(io, "F"); end

"""
    PrefixedFormula

A signed prefixed formula σ S A, where σ is a `Prefix`, S is a `Sign`
(T or F), and A is a `Formula` (Definition 6.1, B&D).
"""
struct PrefixedFormula
    prefix::Prefix
    sign::Sign
    formula::Formula
end

function Base.show(io::IO, pf::PrefixedFormula)
    print(io, pf.prefix, " ", pf.sign, " ", pf.formula)
end

Base.:(==)(a::PrefixedFormula, b::PrefixedFormula) =
    a.prefix == b.prefix && typeof(a.sign) == typeof(b.sign) && a.formula == b.formula
Base.hash(pf::PrefixedFormula, h::UInt) =
    hash(pf.prefix, hash(typeof(pf.sign), hash(pf.formula, h)))

# Convenience constructors
"""
    pf_true(σ::Prefix, A::Formula) -> PrefixedFormula

Construct the prefixed signed formula `σ T A` ("A is true at world σ").
"""
pf_true(σ::Prefix, A::Formula)  = PrefixedFormula(σ, T_SIGN, A)

"""
    pf_false(σ::Prefix, A::Formula) -> PrefixedFormula

Construct the prefixed signed formula `σ F A` ("A is false at world σ").
"""
pf_false(σ::Prefix, A::Formula) = PrefixedFormula(σ, F_SIGN, A)

# ── Tableau branches ──

"""
    TableauBranch

A branch in a prefixed tableau: an ordered list of `PrefixedFormula`s.
A branch is *closed* if it contains σ T A and σ F A for some σ, A.

Fields:
- `formulas`: ordered list of prefixed formulas (for iteration and indexing)
- `formula_set`: `Set{PrefixedFormula}` for O(1) membership checks
- `prefix_set`: `Set{Prefix}` for O(1) used-prefix queries
- `expanded`: `BitSet` tracking which formula indices have been fully processed
  by Priority 1 rules and need not be re-checked
- `scan_start`: where the Priority 1 scan resumes (formulas before this index
  returned NoRule and haven't been invalidated by new child prefixes)
"""
struct TableauBranch
    formulas::Vector{PrefixedFormula}
    formula_set::Set{PrefixedFormula}
    prefix_set::Set{Prefix}
    expanded::BitSet
    scan_start::Int
end

function TableauBranch(formulas::Vector{PrefixedFormula}, scan_start::Int)
    fset = Set{PrefixedFormula}(formulas)
    pset = Set{Prefix}(pf.prefix for pf in formulas)
    TableauBranch(formulas, fset, pset, BitSet(), scan_start)
end

TableauBranch(formulas::Vector{PrefixedFormula}) = TableauBranch(formulas, 1)
TableauBranch() = TableauBranch(PrefixedFormula[], 1)

function Base.show(io::IO, b::TableauBranch)
    if is_closed(b)
        println(io, "Branch (CLOSED, $(length(b.formulas)) formulas):")
    else
        println(io, "Branch (open, $(length(b.formulas)) formulas):")
    end
    for (i, pf) in enumerate(b.formulas)
        println(io, "  $i. $pf")
    end
end

"""
    is_closed(branch::TableauBranch) -> Bool

A branch is closed if it contains both σ T A and σ F A for some prefix σ
and formula A (Definition 6.2, B&D).
"""
function is_closed(branch::TableauBranch)
    for pf in branch.formulas
        if pf.sign isa TrueSign
            companion = PrefixedFormula(pf.prefix, F_SIGN, pf.formula)
            if companion ∈ branch.formula_set
                return true
            end
        end
    end
    false
end

"""
    used_prefixes(branch::TableauBranch) -> Set{Prefix}

Return the set of all prefixes that appear on this branch.
"""
function used_prefixes(branch::TableauBranch)
    branch.prefix_set
end

"""
    fresh_prefix(branch::TableauBranch, σ::Prefix) -> Prefix

Return a new prefix σ.n not yet used on the branch.
"""
function fresh_prefix(branch::TableauBranch, σ::Prefix)
    used = used_prefixes(branch)
    n = 1
    while extend(σ, n) ∈ used
        n += 1
    end
    extend(σ, n)
end

"""
    _has_witness(branch::TableauBranch, σ::Prefix, target::PrefixedFormula) -> Bool

Return `true` if some child prefix τ of σ already has a formula matching
`target` (with τ substituted for the prefix). Used to guard world-creating
rules against redundant witness creation.
"""
function _has_witness(branch::TableauBranch, σ::Prefix, sign::Sign, formula::Formula)
    # Check if any child prefix of σ has the given signed formula
    for pf in branch.formulas
        τ = pf.prefix
        length(τ.seq) == length(σ.seq) + 1 && τ.seq[1:end-1] == σ.seq || continue
        typeof(pf.sign) == typeof(sign) && pf.formula == formula && return true
    end
    false
end

"""
    append_formula(branch::TableauBranch, pf::PrefixedFormula) -> TableauBranch

Return a new branch with pf appended (non-mutating).
"""
function append_formula(branch::TableauBranch, pf::PrefixedFormula)
    new_formulas = [branch.formulas; pf]
    new_fset = union(branch.formula_set, Set([pf]))
    new_pset = union(branch.prefix_set, Set([pf.prefix]))
    TableauBranch(new_formulas, new_fset, new_pset, copy(branch.expanded), branch.scan_start)
end

Base.:(==)(a::TableauBranch, b::TableauBranch) = a.formula_set == b.formula_set

# ── Tableau rules (Tables 6.1–6.2 and 6.3) ──

"""
    RuleApplication

Result of applying a tableau rule to a branch.
- `single`: zero or one branch results (stacking rules)
- `split`: two branches result (branching rules)
"""
abstract type RuleResult end

struct NoRule       <: RuleResult end   # rule does not apply
struct StackRule    <: RuleResult       # adds formulas to one branch
    additions::Vector{PrefixedFormula}
end
struct SplitRule    <: RuleResult       # branches into two
    left::Vector{PrefixedFormula}
    right::Vector{PrefixedFormula}
end

# ── Propositional rules (Table 6.1) ──

"""
    apply_propositional_rule(pf::PrefixedFormula, branch::TableauBranch) -> RuleResult

Apply the appropriate propositional tableau rule to pf, or return `NoRule()`.
All propositional rules preserve the prefix (Definition 6.2, B&D).

Stacking rules (add to same branch):
- ¬T: σ T ¬A  →  σ F A
- ¬F: σ F ¬A  →  σ T A
- ∧T: σ T A∧B →  σ T A, σ T B
- ∨F: σ F A∨B →  σ F A, σ F B
- →F: σ F A→B →  σ T A, σ F B
- ↔T: σ T A↔B →  σ T A, σ T B  (left) | σ F A, σ F B (right)... actually →T is branching
Actually: →T: σ T A→B → σ F A | σ T B

Branching rules (split into two branches):
- ∧F: σ F A∧B →  left: σ F A  |  right: σ F B
- ∨T: σ T A∨B →  left: σ T A  |  right: σ T B
- →T: σ T A→B →  left: σ F A  |  right: σ T B
- ↔F: σ F A↔B →  left: σ T A, σ F B  |  right: σ F A, σ T B
- ↔T: σ T A↔B →  left: σ T A, σ T B  |  right: σ F A, σ F B
"""
function apply_propositional_rule(pf::PrefixedFormula, branch::TableauBranch)
    σ = pf.prefix
    A = pf.formula

    if pf.sign isa TrueSign
        if A isa Not
            # ¬T: σ T ¬B  →  σ F B
            return StackRule([pf_false(σ, A.operand)])
        elseif A isa And
            # ∧T: σ T A∧B  →  σ T A, σ T B
            return StackRule([pf_true(σ, A.left), pf_true(σ, A.right)])
        elseif A isa Or
            # ∨T: σ T A∨B  →  σ T A | σ T B
            return SplitRule([pf_true(σ, A.left)], [pf_true(σ, A.right)])
        elseif A isa Implies
            # →T: σ T A→B  →  σ F A | σ T B
            return SplitRule([pf_false(σ, A.antecedent)], [pf_true(σ, A.consequent)])
        elseif A isa Iff
            # ↔T: σ T A↔B  →  (σ T A, σ T B) | (σ F A, σ F B)
            return SplitRule(
                [pf_true(σ, A.left), pf_true(σ, A.right)],
                [pf_false(σ, A.left), pf_false(σ, A.right)]
            )
        end
    else  # FalseSign
        if A isa Not
            # ¬F: σ F ¬B  →  σ T B
            return StackRule([pf_true(σ, A.operand)])
        elseif A isa And
            # ∧F: σ F A∧B  →  σ F A | σ F B
            return SplitRule([pf_false(σ, A.left)], [pf_false(σ, A.right)])
        elseif A isa Or
            # ∨F: σ F A∨B  →  σ F A, σ F B
            return StackRule([pf_false(σ, A.left), pf_false(σ, A.right)])
        elseif A isa Implies
            # →F: σ F A→B  →  σ T A, σ F B
            return StackRule([pf_true(σ, A.antecedent), pf_false(σ, A.consequent)])
        elseif A isa Iff
            # ↔F: σ F A↔B  →  (σ T A, σ F B) | (σ F A, σ T B)
            return SplitRule(
                [pf_true(σ, A.left), pf_false(σ, A.right)],
                [pf_false(σ, A.left), pf_true(σ, A.right)]
            )
        end
    end
    NoRule()
end

# ── Modal rules for K (Table 6.2) ──

"""
    apply_box_true_rule(pf::PrefixedFormula, branch::TableauBranch) -> RuleResult

□T rule for K: σ T □A → σ.n T A, for each used child prefix σ.n on the branch.
Only applies to `σ T □A`. Returns a `StackRule` with all applicable conclusions,
or `NoRule()` if no used child prefix σ.n exists yet (Table 6.2, B&D).
"""
function apply_box_true_rule(pf::PrefixedFormula, branch::TableauBranch)
    pf.sign isa TrueSign && pf.formula isa Box || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    used = used_prefixes(branch)

    additions = PrefixedFormula[]
    for τ in used
        τ == σ && continue  # reflexive case handled by T□
        is_child = length(τ.seq) == length(σ.seq) + 1 && τ.seq[1:end-1] == σ.seq
        is_child || continue
        new_pf = pf_true(τ, A)
        new_pf ∉ branch.formula_set && push!(additions, new_pf)
    end

    isempty(additions) ? NoRule() : StackRule(additions)
end

"""
    apply_box_false_rule(pf::PrefixedFormula, branch::TableauBranch) -> RuleResult

□F rule for K: σ F □A → σ.n F A, for a new prefix σ.n not on the branch.
Only applies to `σ F □A` (Table 6.2, B&D).
"""
function apply_box_false_rule(pf::PrefixedFormula, branch::TableauBranch)
    pf.sign isa FalseSign && pf.formula isa Box || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    _has_witness(branch, σ, F_SIGN, A) && return NoRule()
    τ = fresh_prefix(branch, σ)
    StackRule([pf_false(τ, A)])
end

"""
    apply_diamond_true_rule(pf::PrefixedFormula, branch::TableauBranch) -> RuleResult

◇T rule for K: σ T ◇A → σ.n T A, for a new prefix σ.n not on the branch.
Only applies to `σ T ◇A` (Table 6.2, B&D).
"""
function apply_diamond_true_rule(pf::PrefixedFormula, branch::TableauBranch)
    pf.sign isa TrueSign && pf.formula isa Diamond || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    _has_witness(branch, σ, T_SIGN, A) && return NoRule()
    τ = fresh_prefix(branch, σ)
    StackRule([pf_true(τ, A)])
end

"""
    apply_diamond_false_rule(pf::PrefixedFormula, branch::TableauBranch) -> RuleResult

◇F rule for K: σ F ◇A → σ.n F A, for each used child prefix σ.n on the branch.
Only applies to `σ F ◇A` (Table 6.2, B&D).
"""
function apply_diamond_false_rule(pf::PrefixedFormula, branch::TableauBranch)
    pf.sign isa FalseSign && pf.formula isa Diamond || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    used = used_prefixes(branch)

    additions = PrefixedFormula[]
    for τ in used
        τ == σ && continue
        is_child = length(τ.seq) == length(σ.seq) + 1 && τ.seq[1:end-1] == σ.seq
        is_child || continue
        new_pf = pf_false(τ, A)
        new_pf ∉ branch.formula_set && push!(additions, new_pf)
    end

    isempty(additions) ? NoRule() : StackRule(additions)
end

# ── Additional rules for extended systems (Table 6.3) ──

"""
    apply_T_box_rule(pf::PrefixedFormula, branch::TableauBranch) -> RuleResult

T□ rule (reflexive models): σ T □A → σ T A.
Adds σ T A directly (reflexivity: Rσσ) (Table 6.3, B&D).
"""
function apply_T_box_rule(pf::PrefixedFormula, branch::TableauBranch)
    pf.sign isa TrueSign && pf.formula isa Box || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    new_pf = pf_true(σ, A)
    new_pf ∈ branch.formula_set ? NoRule() : StackRule([new_pf])
end

"""
    apply_T_diamond_rule(pf::PrefixedFormula, branch::TableauBranch) -> RuleResult

T◇ rule (reflexive models): σ F ◇A → σ F A.
"""
function apply_T_diamond_rule(pf::PrefixedFormula, branch::TableauBranch)
    pf.sign isa FalseSign && pf.formula isa Diamond || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    new_pf = pf_false(σ, A)
    new_pf ∈ branch.formula_set ? NoRule() : StackRule([new_pf])
end

"""
    apply_D_box_rule(pf::PrefixedFormula, branch::TableauBranch) -> RuleResult

D□ rule (serial models): σ T □A → σ T ◇A.
"""
function apply_D_box_rule(pf::PrefixedFormula, branch::TableauBranch)
    pf.sign isa TrueSign && pf.formula isa Box || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    new_pf = pf_true(σ, Diamond(A))
    new_pf ∈ branch.formula_set ? NoRule() : StackRule([new_pf])
end

"""
    apply_D_diamond_rule(pf::PrefixedFormula, branch::TableauBranch) -> RuleResult

D◇ rule (serial models): σ F ◇A → σ F □A.
"""
function apply_D_diamond_rule(pf::PrefixedFormula, branch::TableauBranch)
    pf.sign isa FalseSign && pf.formula isa Diamond || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    new_pf = pf_false(σ, Box(A))
    new_pf ∈ branch.formula_set ? NoRule() : StackRule([new_pf])
end

"""
    apply_B_box_rule(pf::PrefixedFormula, branch::TableauBranch) -> RuleResult

B□ rule (symmetric models): σ.n T □A → σ T A (σ = parent of σ.n).
"""
function apply_B_box_rule(pf::PrefixedFormula, branch::TableauBranch)
    pf.sign isa TrueSign && pf.formula isa Box || return NoRule()
    length(pf.prefix.seq) < 2 && return NoRule()
    σ_n = pf.prefix
    σ = parent_prefix(σ_n)
    A = pf.formula.operand
    new_pf = pf_true(σ, A)
    new_pf ∈ branch.formula_set ? NoRule() : StackRule([new_pf])
end

"""
    apply_B_diamond_rule(pf::PrefixedFormula, branch::TableauBranch) -> RuleResult

B◇ rule (symmetric models): σ.n F ◇A → σ F A.
"""
function apply_B_diamond_rule(pf::PrefixedFormula, branch::TableauBranch)
    pf.sign isa FalseSign && pf.formula isa Diamond || return NoRule()
    length(pf.prefix.seq) < 2 && return NoRule()
    σ_n = pf.prefix
    σ = parent_prefix(σ_n)
    A = pf.formula.operand
    new_pf = pf_false(σ, A)
    new_pf ∈ branch.formula_set ? NoRule() : StackRule([new_pf])
end

"""
    apply_4_box_rule(pf::PrefixedFormula, branch::TableauBranch) -> RuleResult

4□ rule (transitive models): σ T □A → σ.n T □A, for each used prefix σ.n.
"""
function apply_4_box_rule(pf::PrefixedFormula, branch::TableauBranch)
    pf.sign isa TrueSign && pf.formula isa Box || return NoRule()
    σ = pf.prefix
    used = used_prefixes(branch)

    additions = PrefixedFormula[]
    for τ in used
        if length(τ.seq) == length(σ.seq) + 1 && τ.seq[1:end-1] == σ.seq
            new_pf = pf_true(τ, pf.formula)
            new_pf ∉ branch.formula_set && push!(additions, new_pf)
        end
    end

    isempty(additions) ? NoRule() : StackRule(additions)
end

"""
    apply_4_diamond_rule(pf::PrefixedFormula, branch::TableauBranch) -> RuleResult

4◇ rule (transitive models): σ F ◇A → σ.n F ◇A, for each used prefix σ.n.
Symmetric counterpart to 4□ (Table 6.3, B&D).
"""
function apply_4_diamond_rule(pf::PrefixedFormula, branch::TableauBranch)
    pf.sign isa FalseSign && pf.formula isa Diamond || return NoRule()
    σ = pf.prefix
    used = used_prefixes(branch)

    additions = PrefixedFormula[]
    for τ in used
        if length(τ.seq) == length(σ.seq) + 1 && τ.seq[1:end-1] == σ.seq
            new_pf = pf_false(τ, pf.formula)
            new_pf ∉ branch.formula_set && push!(additions, new_pf)
        end
    end

    isempty(additions) ? NoRule() : StackRule(additions)
end

"""
    apply_4T_box_rule(pf::PrefixedFormula, branch::TableauBranch) -> RuleResult

4T□ rule (euclidean models): σ.n T □A → σ T □A.
"""
function apply_4T_box_rule(pf::PrefixedFormula, branch::TableauBranch)
    pf.sign isa TrueSign && pf.formula isa Box || return NoRule()
    length(pf.prefix.seq) < 2 && return NoRule()
    σ_n = pf.prefix
    σ = parent_prefix(σ_n)
    new_pf = pf_true(σ, pf.formula)
    new_pf ∈ branch.formula_set ? NoRule() : StackRule([new_pf])
end

"""
    apply_4T_diamond_rule(pf::PrefixedFormula, branch::TableauBranch) -> RuleResult

4T◇ rule (euclidean models): σ.n F ◇A → σ.m F ◇A for used σ.m.
"""
function apply_4T_diamond_rule(pf::PrefixedFormula, branch::TableauBranch)
    pf.sign isa FalseSign && pf.formula isa Diamond || return NoRule()
    length(pf.prefix.seq) < 2 && return NoRule()
    σ_n = pf.prefix
    σ = parent_prefix(σ_n)
    new_pf = pf_false(σ, pf.formula)
    new_pf ∈ branch.formula_set ? NoRule() : StackRule([new_pf])
end

# ── Sahlqvist correspondence: axiom schema → tableau rules ──

"""
    tableau_rules(schema::AxiomSchema) -> Vector{Function}

Return the used-prefix tableau rules corresponding to `schema` (BdRV Ch.3
Sahlqvist correspondence, B&D Table 6.3). These rules fire on formulas
whose prefix is already on the branch (no new world created).

- SchemaT → T□, T◇   (reflexivity: σ T □A → σ T A)
- SchemaB → B□, B◇   (symmetry:   σ.n T □A → σ T A)
- Schema4 → 4□, 4◇   (transitivity: σ T □A → σ.n T □A)
- Schema5 → 4T□, 4T◇ (euclideanness: σ.n T □A → σ T □A)
- All others → []
"""
tableau_rules(::AxiomSchema)  = Function[]
tableau_rules(::SchemaT)      = Function[apply_T_box_rule, apply_T_diamond_rule]
tableau_rules(::SchemaB)      = Function[apply_B_box_rule, apply_B_diamond_rule]
tableau_rules(::Schema4)      = Function[apply_4_box_rule, apply_4_diamond_rule]
tableau_rules(::Schema5)      = Function[apply_4T_box_rule, apply_4T_diamond_rule]

"""
    tableau_witness_rules(schema::AxiomSchema) -> Vector{Function}

Return the witness-creation (new-prefix) tableau rules corresponding to
`schema` (B&D Table 6.3). These rules fire only when no used-prefix rule
applies — they create a new world to satisfy a seriality requirement.

- SchemaD → D□, D◇   (seriality: σ T □A → σ T ◇A)
- All others → []
"""
tableau_witness_rules(::AxiomSchema)  = Function[]
tableau_witness_rules(::SchemaD)      = Function[apply_D_box_rule, apply_D_diamond_rule]

# ── Tableau system ──

"""
    TableauSystem

Specifies which rules to use for a given modal system (Definition 6.2,
Table 6.4, B&D). A system is a configuration of frame-condition rules,
following the Sahlqvist correspondence (BdRV Ch.3): each axiom schema
contributes a set of tableau rules that encode its first-order frame
condition.

Fields:
- `name`: display name (Symbol)
- `used_prefix_rules`: rules that fire on existing prefixes (reflexivity,
  symmetry, transitivity, euclideanness — T□/T◇, B□/B◇, 4□/4◇, 4T□/4T◇)
- `witness_rules`: rules that create new prefixes to ensure a successor
  exists (seriality — D□/D◇)

To define a new system, supply the appropriate rule vectors. No changes
to the tableau engine are required.
"""
struct TableauSystem
    name::Symbol
    used_prefix_rules::Vector{Function}
    witness_rules::Vector{Function}
end

"""
    TABLEAU_K

Tableau system for the minimal normal modal logic K. No frame conditions;
only propositional rules and the basic □/◇ modal rules (Table 6.2, B&D).
"""
const TABLEAU_K  = TableauSystem(:K,  Function[], Function[])

"""
    TABLEAU_KT

Tableau system for KT (reflexive frames). Adds the T□ and T◇ rules
corresponding to the T axiom □p → p (Table 6.3, B&D).
"""
const TABLEAU_KT = TableauSystem(:KT, Function[apply_T_box_rule, apply_T_diamond_rule],
                                       Function[])

"""
    TABLEAU_KD

Tableau system for KD (serial frames). Adds the D□ and D◇ witness rules
corresponding to the D axiom □p → ◇p (Table 6.3, B&D).
"""
const TABLEAU_KD = TableauSystem(:KD, Function[],
                                       Function[apply_D_box_rule, apply_D_diamond_rule])

"""
    TABLEAU_KB

Tableau system for KB (symmetric frames). Adds T□/T◇ and B□/B◇ rules
corresponding to the B axiom □p → ◇□p (Table 6.3, B&D).
"""
const TABLEAU_KB = TableauSystem(:KB, Function[apply_T_box_rule, apply_T_diamond_rule,
                                               apply_B_box_rule, apply_B_diamond_rule],
                                       Function[])

"""
    TABLEAU_K4

Tableau system for K4 (transitive frames). Adds the 4□ and 4◇ rules
corresponding to the 4 axiom □p → □□p (Table 6.3, B&D).
"""
const TABLEAU_K4 = TableauSystem(:K4, Function[apply_4_box_rule, apply_4_diamond_rule],
                                       Function[])

"""
    TABLEAU_S4

Tableau system for S4 (reflexive + transitive frames). Combines T□/T◇
and 4□/4◇ rules (Table 6.4, B&D).
"""
const TABLEAU_S4 = TableauSystem(:S4, Function[apply_T_box_rule, apply_T_diamond_rule,
                                               apply_4_box_rule, apply_4_diamond_rule],
                                       Function[])

"""
    TABLEAU_S5

Tableau system for S5 (equivalence relation frames). Combines T□/T◇,
B□/B◇, 4□/4◇, and 4T□/4T◇ rules (Table 6.4, B&D).
"""
const TABLEAU_S5 = TableauSystem(:S5, Function[apply_T_box_rule,  apply_T_diamond_rule,
                                               apply_B_box_rule,  apply_B_diamond_rule,
                                               apply_4_box_rule,  apply_4_diamond_rule,
                                               apply_4T_box_rule, apply_4T_diamond_rule],
                                       Function[])

# ── Automated tableau construction ──

"""
    _apply_all_rules(branch::TableauBranch, system::TableauSystem) -> Vector{TableauBranch}

Apply one rule to a branch, returning the resulting branch(es).
Rules are tried in priority order across all formulas:
1. Propositional and used-prefix modal rules (scan all formulas first)
2. New-prefix modal rules (only if no priority-1 rule applies)

Returns [branch] unchanged if no rule applies (saturated branch).
"""

# Helper: true if a formula is purely propositional (no modal/temporal operators).
# Propositional formulas can be marked as expanded after processing since their
# rules never depend on which worlds exist.
_is_propositional(f::Formula) = f isa Not || f isa And || f isa Or || f isa Implies || f isa Iff

function _apply_all_rules(branch::TableauBranch, system::TableauSystem)
    is_closed(branch) && return [branch]

    # Priority 1: propositional and used-prefix rules
    # Start scanning from scan_start — formulas before this index returned NoRule
    # on the previous call and haven't been invalidated by new child prefixes.
    # Skip formulas marked as expanded (propositional formulas that have been
    # fully processed and will never produce new results).
    n = length(branch.formulas)
    last_applied = n  # will become scan_start for returned branches
    for i in branch.scan_start:n
        i ∈ branch.expanded && continue
        pf = branch.formulas[i]
        pf.formula isa Atom   && continue
        pf.formula isa Bottom && continue

        result = _try_priority1_rules(pf, branch, system)
        if result isa NoRule
            # Mark propositional formulas as expanded — they won't produce
            # new results even after new worlds are created. Modal formulas
            # (Box, Diamond, FutureBox, etc.) are NOT marked because their
            # rules depend on which child prefixes exist.
            if _is_propositional(pf.formula)
                push!(branch.expanded, i)
            end
            continue
        end

        if result isa StackRule
            new_branch = branch
            for addition in result.additions
                addition ∈ new_branch.formula_set && continue
                new_branch = append_formula(new_branch, addition)
            end
            new_branch == branch && continue
            # Rule fired: mark propositional formulas as expanded
            if _is_propositional(pf.formula)
                push!(new_branch.expanded, i)
            end
            return [TableauBranch(new_branch.formulas, new_branch.formula_set,
                                  new_branch.prefix_set, new_branch.expanded, i)]
        elseif result isa SplitRule
            function _add_unique(b, pfs)
                for pf in pfs
                    pf ∈ b.formula_set && continue
                    b = append_formula(b, pf)
                end
                b
            end
            left  = _add_unique(branch, result.left)
            right = _add_unique(branch, result.right)
            # If both branches are identical to parent, all conclusions already present
            (left == branch && right == branch) && continue
            # If one arm is already present, this branch is the survivor of a
            # previous split — do not discard it by returning only the other arm.
            (left == branch || right == branch) && continue
            # Mark the split formula as expanded on both branches
            left_exp = copy(left.expanded)
            right_exp = copy(right.expanded)
            if _is_propositional(pf.formula)
                push!(left_exp, i)
                push!(right_exp, i)
            end
            return [TableauBranch(left.formulas, left.formula_set,
                                  left.prefix_set, left_exp, i),
                    TableauBranch(right.formulas, right.formula_set,
                                  right.prefix_set, right_exp, i)]
        end
    end

    # Priority 2a: □F and 𝐆F rules first (before ◇T/𝐅T) — ensures worlds are named
    # before diamond-true rules fire on them.
    # World-creating rules reset scan_start to 1: new children mean old
    # Box-true/Diamond-false rules may need to propagate again.
    for pf in branch.formulas
        if pf.formula isa Box && pf.sign isa FalseSign
            r = apply_box_false_rule(pf, branch)
        elseif pf.formula isa FutureBox && pf.sign isa FalseSign
            r = apply_futurebox_false_rule(pf, branch)
        else
            continue
        end
        r isa NoRule && continue
        if r isa StackRule
            new_branch = branch
            for addition in r.additions
                addition ∈ new_branch.formula_set && continue
                new_branch = append_formula(new_branch, addition)
            end
            new_branch == branch && continue
            return [TableauBranch(new_branch.formulas, new_branch.formula_set,
                                  new_branch.prefix_set, BitSet(), 1)]
        end
    end

    # Priority 2b: ◇T and 𝐅T rules
    for pf in branch.formulas
        if pf.formula isa Diamond && pf.sign isa TrueSign
            r = apply_diamond_true_rule(pf, branch)
        elseif pf.formula isa FutureDiamond && pf.sign isa TrueSign
            r = apply_futurediamond_true_rule(pf, branch)
        else
            continue
        end
        r isa NoRule && continue
        if r isa StackRule
            new_branch = branch
            for addition in r.additions
                addition ∈ new_branch.formula_set && continue
                new_branch = append_formula(new_branch, addition)
            end
            new_branch == branch && continue
            return [TableauBranch(new_branch.formulas, new_branch.formula_set,
                                  new_branch.prefix_set, BitSet(), 1)]
        end
    end

    # Priority 2c: witness-creation rules (seriality, etc.)
    if !isempty(system.witness_rules)
        for pf in branch.formulas
            pf.formula isa Atom   && continue
            pf.formula isa Bottom && continue
            r = _try_witness_rules(pf, branch, system)
            r isa NoRule && continue
            if r isa StackRule
                new_branch = branch
                for addition in r.additions
                    addition ∈ new_branch.formula_set && continue
                    new_branch = append_formula(new_branch, addition)
                end
                new_branch == branch && continue
                return [TableauBranch(new_branch.formulas, new_branch.formula_set,
                                  new_branch.prefix_set, BitSet(), 1)]
            end
        end
    end

    [branch]  # saturated
end

"""
    _try_priority1_rules(pf, branch, system) -> RuleResult

Try propositional rules and used-prefix modal rules (do not create new worlds).
Frame-condition rules are taken from `system.used_prefix_rules`, which encodes
the Sahlqvist correspondence for this system's axioms.
"""
function _try_priority1_rules(pf::PrefixedFormula, branch::TableauBranch, system::TableauSystem)
    # Propositional rules
    r = apply_propositional_rule(pf, branch)
    r isa NoRule || return r

    # Base K used-prefix rules (□T, ◇F)
    r = apply_box_true_rule(pf, branch)
    r isa NoRule || return r
    r = apply_diamond_false_rule(pf, branch)
    r isa NoRule || return r

    # Base temporal used-prefix rules (𝐆T, 𝐅F)
    r = apply_futurebox_true_rule(pf, branch)
    r isa NoRule || return r
    r = apply_futurediamond_false_rule(pf, branch)
    r isa NoRule || return r

    # Frame-condition used-prefix rules (T□/T◇, B□/B◇, 4□/4◇, 4T□/4T◇)
    for rule in system.used_prefix_rules
        r = rule(pf, branch)
        r isa NoRule || return r
    end

    NoRule()
end

"""
    _try_witness_rules(pf, branch, system) -> RuleResult

Try witness-creation rules from `system.witness_rules` (e.g., D□/D◇ for
seriality). These fire at priority 2c, after all used-prefix rules, because
they create new worlds rather than propagating into existing ones.
"""
function _try_witness_rules(pf::PrefixedFormula, branch::TableauBranch, system::TableauSystem)
    for rule in system.witness_rules
        r = rule(pf, branch)
        r isa NoRule || return r
    end
    NoRule()
end

"""
    Tableau

A completed prefixed tableau: a set of branches, each either closed or fully
expanded. A tableau is *closed* when all branches are closed (Definition 6.2, B&D).
"""
struct Tableau
    branches::Vector{TableauBranch}
end

function Base.show(io::IO, t::Tableau)
    status = is_closed(t) ? "CLOSED" : "open"
    println(io, "Tableau ($status, $(length(t.branches)) branches):")
    for (i, b) in enumerate(t.branches)
        println(io, "  Branch $i: $(is_closed(b) ? "closed" : "open") ($(length(b.formulas)) formulas)")
    end
end

"""
    is_closed(tableau::Tableau) -> Bool

A tableau is closed if all its branches are closed (Definition 6.2, B&D).
"""
is_closed(t::Tableau) = all(is_closed, t.branches)

"""
    build_tableau(assumptions::Vector{PrefixedFormula},
                  system::TableauSystem; max_steps::Int=1000) -> Tableau

Construct a tableau for the given set of assumptions using the rules
of `system`. The tableau search terminates when all branches are
closed or no more rules apply (Definition 6.17, Proposition 6.18, B&D).

`max_steps` bounds the number of rule applications to prevent non-termination
for non-theorems in systems without the finite model property.
"""
function build_tableau(assumptions::Vector{PrefixedFormula},
                       system::TableauSystem; max_steps::Int=1000)
    branches = [TableauBranch(copy(assumptions))]
    steps = 0

    while steps < max_steps
        # Find first open, non-saturated branch
        idx = findfirst(b -> !is_closed(b), branches)
        idx === nothing && break

        branch = branches[idx]
        new_branches = _apply_all_rules(branch, system)

        if length(new_branches) == 1 && new_branches[1] == branch
            # Branch is saturated — no more rules apply
            # Check if there are other open branches to process
            all_saturated = true
            for b in branches
                if !is_closed(b) && b != branch
                    all_saturated = false
                    break
                end
            end
            break
        end

        branches[idx] = new_branches[1]
        for k in 2:length(new_branches)
            push!(branches, new_branches[k])
        end

        steps += 1
    end

    Tableau(branches)
end

# ── Completeness and countermodel extraction (§6.8–6.9, B&D) ──

"""
    extract_countermodel(branch::TableauBranch) -> KripkeModel

Construct the countermodel M(Δ) from an open complete branch Δ
(Theorem 6.19, §6.9, B&D).

The model is defined as:
- Worlds: the set of all prefixes appearing on the branch
- Accessibility: Rσσ' iff σ' = σ.n for some positive integer n
  (i.e., σ' is a direct child of σ in the prefix tree)
- Valuation: V(p) = {σ : σ T p ∈ Δ}

By the completeness proof (Theorem 6.19), if the branch is open and
complete, every σ T A ∈ Δ is true at σ in M(Δ), and every σ F A ∈ Δ
is false at σ in M(Δ).
"""
function extract_countermodel(branch::TableauBranch)
    # Worlds: all prefixes on the branch (as symbols for KripkeFrame)
    prefix_list = collect(used_prefixes(branch))
    worlds = [Symbol(string(σ)) for σ in prefix_list]
    prefix_to_world = Dict(σ => Symbol(string(σ)) for σ in prefix_list)

    # Accessibility: parent → child in prefix tree
    relations = Pair{Symbol,Symbol}[]
    for σ in prefix_list
        for τ in prefix_list
            if length(τ.seq) == length(σ.seq) + 1 && τ.seq[1:end-1] == σ.seq
                push!(relations, prefix_to_world[σ] => prefix_to_world[τ])
            end
        end
    end

    # Valuation: collect all propositional atoms appearing on the branch
    all_atoms = Symbol[]
    for pf in branch.formulas
        _collect_atoms!(all_atoms, pf.formula)
    end
    unique!(all_atoms)

    val_pairs = Pair{Symbol,Vector{Symbol}}[]
    for a in all_atoms
        true_worlds = Symbol[]
        for pf in branch.formulas
            pf.sign isa TrueSign || continue
            pf.formula == Atom(a) || continue
            push!(true_worlds, prefix_to_world[pf.prefix])
        end
        push!(val_pairs, a => true_worlds)
    end

    frame = KripkeFrame(worlds, relations)
    KripkeModel(frame, val_pairs)
end

function _collect_atoms!(out::Vector{Symbol}, f::Formula)
    if f isa Atom
        f.name isa Symbol && push!(out, f.name)
    elseif f isa Not
        _collect_atoms!(out, f.operand)
    elseif f isa And || f isa Or || f isa Iff
        _collect_atoms!(out, f.left)
        _collect_atoms!(out, f.right)
    elseif f isa Implies
        _collect_atoms!(out, f.antecedent)
        _collect_atoms!(out, f.consequent)
    elseif f isa Box || f isa Diamond
        _collect_atoms!(out, f.operand)
    elseif f isa FutureBox || f isa FutureDiamond || f isa PastBox || f isa PastDiamond
        _collect_atoms!(out, f.operand)
    elseif f isa Since || f isa Until
        _collect_atoms!(out, f.left)
        _collect_atoms!(out, f.right)
    end
end

# ── High-level proof checking ──

"""
    tableau_proves(system::TableauSystem, premises::Vector{Formula},
                   conclusion::Formula; max_steps::Int=1000) -> Bool

Return `true` if there is a closed tableau showing `premises ⊢ conclusion`
in `system`. Constructs the initial assumptions
  1 T B₁, …, 1 T Bₙ, 1 F conclusion
and checks whether the resulting tableau closes (Definition 6.2, B&D).

# Example

```julia
p = Atom(:p); q = Atom(:q)
# K ⊢ (□p ∧ □q) → □(p ∧ q)
tableau_proves(TABLEAU_K, Formula[], Implies(And(Box(p), Box(q)), Box(And(p, q))))
```
"""
function tableau_proves(system::TableauSystem, premises::Vector{Formula},
                        conclusion::Formula; max_steps::Int=1000)
    root = Prefix([1])
    assumptions = PrefixedFormula[
        [pf_true(root, B) for B in premises];
        pf_false(root, conclusion)
    ]
    t = build_tableau(assumptions, system; max_steps=max_steps)
    is_closed(t)
end

"""
    tableau_consistent(system::TableauSystem, formulas::Vector{Formula};
                       max_steps::Int=1000) -> Bool

Return `true` if `formulas` is satisfiable in `system` (i.e., the tableau
for `1 T A₁, …, 1 T Aₙ` does not close).
"""
function tableau_consistent(system::TableauSystem, formulas::Vector{Formula};
                             max_steps::Int=1000)
    root = Prefix([1])
    assumptions = [pf_true(root, A) for A in formulas]
    t = build_tableau(assumptions, system; max_steps=max_steps)
    !is_closed(t)
end
