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
pf_true(σ::Prefix, A::Formula)  = PrefixedFormula(σ, T_SIGN, A)
pf_false(σ::Prefix, A::Formula) = PrefixedFormula(σ, F_SIGN, A)

# ── Tableau branches ──

"""
    TableauBranch

A branch in a prefixed tableau: an ordered list of `PrefixedFormula`s.
A branch is *closed* if it contains σ T A and σ F A for some σ, A.
"""
struct TableauBranch
    formulas::Vector{PrefixedFormula}
end

TableauBranch() = TableauBranch(PrefixedFormula[])

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
            if companion ∈ branch.formulas
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
    Set{Prefix}(pf.prefix for pf in branch.formulas)
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
    append_formula(branch::TableauBranch, pf::PrefixedFormula) -> TableauBranch

Return a new branch with pf appended (non-mutating).
"""
function append_formula(branch::TableauBranch, pf::PrefixedFormula)
    TableauBranch([branch.formulas; pf])
end

Base.:(==)(a::TableauBranch, b::TableauBranch) = a.formulas == b.formulas

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
    apply_box_true_rule(pf::PrefixedFormula, branch::TableauBranch,
                        all_prefixes::Bool=false) -> RuleResult

□T rule for K: σ T □A → σ.n T A, for each used prefix σ.n on the branch.
Only applies to `σ T □A`. Returns a `StackRule` with all applicable conclusions,
or `NoRule()` if no used prefix σ.n exists yet (Table 6.2, B&D).

When `all_prefixes=true` (for simplified S5), considers all used prefixes.
"""
function apply_box_true_rule(pf::PrefixedFormula, branch::TableauBranch,
                              all_prefixes::Bool=false)
    pf.sign isa TrueSign && pf.formula isa Box || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    used = used_prefixes(branch)

    additions = PrefixedFormula[]
    for τ in used
        τ == σ && continue  # reflexive case handled by T□
        is_child = length(τ.seq) == length(σ.seq) + 1 && τ.seq[1:end-1] == σ.seq
        if all_prefixes || is_child
            new_pf = pf_true(τ, A)
            new_pf ∉ branch.formulas && push!(additions, new_pf)
        end
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
    τ = fresh_prefix(branch, σ)
    StackRule([pf_false(τ, A)])
end

"""
    apply_diamond_true_rule(pf::PrefixedFormula, branch::TableauBranch,
                            all_prefixes::Bool=false) -> RuleResult

◇T rule for K: σ T ◇A → σ.n T A, for a new prefix σ.n not on the branch.
Only applies to `σ T ◇A` (Table 6.2, B&D).

When `all_prefixes=true` (simplified S5), additionally generates conclusions
for all used prefixes (used-prefix mode), and falls back to new prefix only
if all conclusions are already on the branch.
"""
function apply_diamond_true_rule(pf::PrefixedFormula, branch::TableauBranch,
                                  all_prefixes::Bool=false)
    pf.sign isa TrueSign && pf.formula isa Diamond || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand

    if all_prefixes
        # S5: fire for all used prefixes (universal accessibility)
        # Only use existing prefixes — do NOT create new ones in this mode
        used = used_prefixes(branch)
        additions = PrefixedFormula[]
        for τ in used
            τ == σ && continue
            new_pf = pf_true(τ, A)
            new_pf ∉ branch.formulas && push!(additions, new_pf)
        end
        isempty(additions) ? NoRule() : StackRule(additions)
    else
        τ = fresh_prefix(branch, σ)
        StackRule([pf_true(τ, A)])
    end
end

"""
    apply_diamond_false_rule(pf::PrefixedFormula, branch::TableauBranch,
                             all_prefixes::Bool=false) -> RuleResult

◇F rule for K: σ F ◇A → σ.n F A, for each used prefix σ.n on the branch.
Only applies to `σ F ◇A` (Table 6.2, B&D).

When `all_prefixes=true` (for simplified S5), considers all used prefixes.
"""
function apply_diamond_false_rule(pf::PrefixedFormula, branch::TableauBranch,
                                   all_prefixes::Bool=false)
    pf.sign isa FalseSign && pf.formula isa Diamond || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    used = used_prefixes(branch)

    additions = PrefixedFormula[]
    for τ in used
        τ == σ && continue
        is_child = length(τ.seq) == length(σ.seq) + 1 && τ.seq[1:end-1] == σ.seq
        if all_prefixes || is_child
            new_pf = pf_false(τ, A)
            new_pf ∉ branch.formulas && push!(additions, new_pf)
        end
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
    new_pf ∈ branch.formulas ? NoRule() : StackRule([new_pf])
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
    new_pf ∈ branch.formulas ? NoRule() : StackRule([new_pf])
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
    new_pf ∈ branch.formulas ? NoRule() : StackRule([new_pf])
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
    new_pf ∈ branch.formulas ? NoRule() : StackRule([new_pf])
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
    new_pf ∈ branch.formulas ? NoRule() : StackRule([new_pf])
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
    new_pf ∈ branch.formulas ? NoRule() : StackRule([new_pf])
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
            new_pf ∉ branch.formulas && push!(additions, new_pf)
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
            new_pf ∉ branch.formulas && push!(additions, new_pf)
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
    new_pf ∈ branch.formulas ? NoRule() : StackRule([new_pf])
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
    new_pf ∈ branch.formulas ? NoRule() : StackRule([new_pf])
end

# ── Tableau system ──

"""
    TableauSystem

Specifies which rules to use for a given modal system (Definition 6.2, Table 6.4, B&D).

Supported systems: `:K`, `:KT`, `:KD`, `:KB`, `:K4`, `:S4`, `:S5`
"""
struct TableauSystem
    name::Symbol
end

const TABLEAU_K  = TableauSystem(:K)
const TABLEAU_KT = TableauSystem(:KT)
const TABLEAU_KD = TableauSystem(:KD)
const TABLEAU_KB = TableauSystem(:KB)
const TABLEAU_K4 = TableauSystem(:K4)
const TABLEAU_S4 = TableauSystem(:S4)
const TABLEAU_S5 = TableauSystem(:S5)

# ── Automated tableau construction ──

"""
    _apply_all_rules(branch::TableauBranch, system::TableauSystem) -> Vector{TableauBranch}

Apply one rule to a branch, returning the resulting branch(es).
Rules are tried in priority order across all formulas:
1. Propositional and used-prefix modal rules (scan all formulas first)
2. New-prefix modal rules (only if no priority-1 rule applies)

Returns [branch] unchanged if no rule applies (saturated branch).
"""
function _apply_all_rules(branch::TableauBranch, system::TableauSystem)
    is_closed(branch) && return [branch]

    # Priority 1: propositional and used-prefix rules
    for pf in branch.formulas
        pf.formula isa Atom   && continue
        pf.formula isa Bottom && continue

        result = _try_priority1_rules(pf, branch, system)
        result isa NoRule && continue

        if result isa StackRule
            new_branch = branch
            for addition in result.additions
                addition ∈ new_branch.formulas && continue
                new_branch = append_formula(new_branch, addition)
            end
            new_branch == branch && continue
            return [new_branch]
        elseif result isa SplitRule
            function _add_unique(b, pfs)
                for pf in pfs
                    pf ∈ b.formulas && continue
                    b = append_formula(b, pf)
                end
                b
            end
            left  = _add_unique(branch, result.left)
            right = _add_unique(branch, result.right)
            # If both branches are identical to parent, all conclusions already present
            (left == branch && right == branch) && continue
            # If one side is same as parent (already saturated), only return changed side
            left  == branch && return [right]
            right == branch && return [left]
            return [left, right]
        end
    end

    # Priority 2a: □F rules first (before ◇T) — ensures worlds are named
    # before diamond-true rules fire on them
    for pf in branch.formulas
        pf.formula isa Box && pf.sign isa FalseSign || continue
        r = apply_box_false_rule(pf, branch)
        r isa NoRule && continue
        if r isa StackRule
            new_branch = branch
            for addition in r.additions
                addition ∈ new_branch.formulas && continue
                new_branch = append_formula(new_branch, addition)
            end
            new_branch == branch && continue
            return [new_branch]
        end
    end

    # Priority 2b: ◇T rules
    for pf in branch.formulas
        pf.formula isa Diamond && pf.sign isa TrueSign || continue
        r = apply_diamond_true_rule(pf, branch)
        r isa NoRule && continue
        if r isa StackRule
            new_branch = branch
            for addition in r.additions
                addition ∈ new_branch.formulas && continue
                new_branch = append_formula(new_branch, addition)
            end
            new_branch == branch && continue
            return [new_branch]
        end
    end

    # Priority 2c: D□/D◇ rules (KD only)
    if system.name == :KD
        for pf in branch.formulas
            pf.formula isa Atom   && continue
            pf.formula isa Bottom && continue
            r = _try_new_prefix_rules(pf, branch, system)
            r isa NoRule && continue
            if r isa StackRule
                new_branch = branch
                for addition in r.additions
                    addition ∈ new_branch.formulas && continue
                    new_branch = append_formula(new_branch, addition)
                end
                new_branch == branch && continue
                return [new_branch]
            end
        end
    end

    [branch]  # saturated
end

"""
    _try_priority1_rules(pf, branch, system) -> RuleResult

Try propositional rules and used-prefix modal rules (do not create new worlds).
"""
function _try_priority1_rules(pf::PrefixedFormula, branch::TableauBranch, system::TableauSystem)
    # Propositional rules
    r = apply_propositional_rule(pf, branch)
    r isa NoRule || return r

    sys = system.name
    # In S5, all worlds are universally accessible — use all prefixes for □T/◇F
    all_pfx = sys == :S5

    # Used-prefix modal rules
    r = apply_box_true_rule(pf, branch, all_pfx)
    r isa NoRule || return r
    r = apply_diamond_false_rule(pf, branch, all_pfx)
    r isa NoRule || return r
    # For S5: ◇T also fires for used prefixes (all worlds accessible)
    if all_pfx
        r = apply_diamond_true_rule(pf, branch, true)
        r isa NoRule || return r
    end

    if sys ∈ (:KT, :KB, :S4, :S5)
        r = apply_T_box_rule(pf, branch)
        r isa NoRule || return r
        r = apply_T_diamond_rule(pf, branch)
        r isa NoRule || return r
    end

    if sys ∈ (:KB, :S5)
        r = apply_B_box_rule(pf, branch)
        r isa NoRule || return r
        r = apply_B_diamond_rule(pf, branch)
        r isa NoRule || return r
    end

    if sys ∈ (:K4, :S4, :S5)
        r = apply_4_box_rule(pf, branch)
        r isa NoRule || return r
        r = apply_4_diamond_rule(pf, branch)
        r isa NoRule || return r
    end

    if sys == :S5
        r = apply_4T_box_rule(pf, branch)
        r isa NoRule || return r
        r = apply_4T_diamond_rule(pf, branch)
        r isa NoRule || return r
    end

    NoRule()
end

"""
    _try_new_prefix_rules(pf, branch, system) -> RuleResult

Try new-prefix modal rules (□F, ◇T, D□, D◇) — applied after priority-1 rules.
"""
function _try_new_prefix_rules(pf::PrefixedFormula, branch::TableauBranch, system::TableauSystem)
    r = apply_box_false_rule(pf, branch)
    r isa NoRule || return r
    r = apply_diamond_true_rule(pf, branch)
    r isa NoRule || return r

    if system.name == :KD
        r = apply_D_box_rule(pf, branch)
        r isa NoRule || return r
        r = apply_D_diamond_rule(pf, branch)
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
