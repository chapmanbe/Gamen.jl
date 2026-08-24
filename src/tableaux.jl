# Chapter 6: Modal Tableaux (B&D)
#
# Architecture overview:
#
# This file implements prefixed signed tableau systems for modal logic,
# following Goré (1999) "Tableau Methods for Modal and Temporal Logics"
# (in Handbook of Tableau Methods).
#
# Key types:
#   Prefix          — a world name in the tableau (e.g., 1, 1.2, 1.3)
#   Sign            — T (true) or F (false)
#   PrefixedFormula — a formula tagged with a prefix and sign: T 1: □p
#   TableauBranch   — a single branch: list of prefixed formulas + closure status
#   Tableau         — the full proof tree: a list of branches
#   TableauSystem   — configuration: name + operator pairs + expansion rules
#                     + witness rules; standard systems are derived from
#                     their ModalSystem via the Sahlqvist table
#   OperatorPair    — the (box, diamond) operator types a rule set serves;
#                     rules are generic over the pair, so 𝐆/𝐅 reuse the □/◇
#                     rule bodies instead of duplicating them
#
# Expansion algorithm (_apply_all_rules):
#   Priority 0: propositional rules (no branching or world creation)
#   Priority 1: modal rules that reuse existing prefixes (e.g., T□ at prefix σ
#               adds T formulas at all successors of σ)
#   Priority 2: world-creating rules (e.g., F□ at prefix σ creates a new
#               successor σ.n and adds F formula there)
#
# Blocking (for transitive/temporal logic termination):
#   Ancestor-based blocking prevents infinite expansion. Only systems with
#   uses_blocking=true (K4, S4, S5, KDt) use it — these are exactly the
#   systems whose used-prefix rules re-inject an unstripped boxed formula
#   into a descendant world. A prefix σ is blocked when an ancestor labels
#   an identical set of signed formulas — the subtableau from σ would be
#   isomorphic. Recomputed fresh on every rule application (not cached), so
#   a prefix can also become unblocked if its content later diverges from
#   every ancestor. See CLAUDE.md for details.
#
# Countermodel extraction:
#   extract_countermodel reads an open (non-closed) branch and builds a
#   KripkeModel from the prefixes (worlds) and their formulas (valuation).
#
# Systems: TABLEAU_K, TABLEAU_KT, TABLEAU_KD, TABLEAU_KB, TABLEAU_K4,
#          TABLEAU_S4, TABLEAU_S5, TABLEAU_KDt (deontic-temporal)

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
- `blocked`: `Set{Prefix}` of prefixes currently blocked by ancestor equality — a
  prefix σ is blocked when an ancestor σ' labels an identical set of signed
  formulas, so the subtableau from σ would be isomorphic and need not be
  expanded. Only populated for systems with `uses_blocking = true`; recomputed
  from scratch on every rule application, not accumulated (see `_should_block`)
- `scan_start`: where the Priority 1 scan resumes (formulas before this index
  returned NoRule and haven't been invalidated by new child prefixes)
"""
struct TableauBranch
    formulas::Vector{PrefixedFormula}
    formula_set::Set{PrefixedFormula}
    prefix_set::Set{Prefix}
    expanded::BitSet
    blocked::Set{Prefix}
    scan_start::Int
end

function TableauBranch(formulas::Vector{PrefixedFormula}, scan_start::Int)
    fset = Set{PrefixedFormula}(formulas)
    pset = Set{Prefix}(pf.prefix for pf in formulas)
    TableauBranch(formulas, fset, pset, BitSet(), Set{Prefix}(), scan_start)
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
and formula A (Definition 6.2, B&D), or if it contains σ T ⊥ for some
prefix σ. B&D implicitly assumes ⊥-free inputs; since ⊥ is semantically
equivalent to φ ∧ ¬φ, closing on σ T ⊥ is the same closure condition
(issue #10).
"""
function is_closed(branch::TableauBranch)
    for pf in branch.formulas
        if pf.sign isa TrueSign
            pf.formula isa Bottom && return true
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
    TableauBranch(new_formulas, new_fset, new_pset, copy(branch.expanded),
                  copy(branch.blocked), branch.scan_start)
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

# ── Operator pairs ──

"""
    OperatorPair

A dual pair of modal operators the tableau rules are generic over: `box` is
the universal operator's type, `diamond` its existential dual. The base pair
is (□, ◇); `TABLEAU_KDt` adds the temporal pair (𝐆, 𝐅). Internal — not
exported until a second consumer (e.g. an epistemic tableau) exists.

Each modal rule below takes a pair as its third argument (defaulting to
`BASE_PAIR`) and reads the operator types from it, so one rule body serves
every operator family. See `plans/tableau-parametrization.md`.
"""
struct OperatorPair
    box::DataType       # e.g. Box, FutureBox — the universal operator
    diamond::DataType   # e.g. Diamond, FutureDiamond — its existential dual
end

const BASE_PAIR = OperatorPair(Box, Diamond)

"""
    BoundRule <: Function

A tableau rule partially applied to an `OperatorPair`: calling
`BoundRule(rule, pair)(pf, branch)` runs `rule(pf, branch, pair)`. Used by
`TableauSystem` construction so `used_prefix_rules`/`witness_rules` keep
their two-argument calling convention. A struct rather than an anonymous
closure so two identical bindings compare `==` — the derived-vs-hand-built
equivalence tests depend on that.
"""
struct BoundRule <: Function
    rule::Function
    pair::OperatorPair
end

(br::BoundRule)(pf::PrefixedFormula, branch::TableauBranch) = br.rule(pf, branch, br.pair)

Base.show(io::IO, br::BoundRule) = print(io, nameof(br.rule), "[", nameof(br.pair.box), "]")
Base.show(io::IO, ::MIME"text/plain", br::BoundRule) = show(io, br)

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
    apply_box_true_rule(pf, branch, pair=BASE_PAIR) -> RuleResult

□T rule for K: σ T □A → σ.n T A, for each used child prefix σ.n on the branch.
Only applies to `σ T □A`. Returns a `StackRule` with all applicable conclusions,
or `NoRule()` if no used child prefix σ.n exists yet (Table 6.2, B&D).

Generic over the operator pair: `pair.box` plays □ (e.g. 𝐆 for the temporal
pair), and likewise for every modal rule below.
"""
function apply_box_true_rule(pf::PrefixedFormula, branch::TableauBranch,
                             pair::OperatorPair=BASE_PAIR)
    pf.sign isa TrueSign && pf.formula isa pair.box || return NoRule()
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
    apply_box_false_rule(pf, branch, pair=BASE_PAIR) -> RuleResult

□F rule for K: σ F □A → σ.n F A, for a new prefix σ.n not on the branch.
Only applies to `σ F □A` (Table 6.2, B&D).
"""
function apply_box_false_rule(pf::PrefixedFormula, branch::TableauBranch,
                              pair::OperatorPair=BASE_PAIR)
    pf.sign isa FalseSign && pf.formula isa pair.box || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    _has_witness(branch, σ, F_SIGN, A) && return NoRule()
    τ = fresh_prefix(branch, σ)
    StackRule([pf_false(τ, A)])
end

"""
    apply_diamond_true_rule(pf, branch, pair=BASE_PAIR) -> RuleResult

◇T rule for K: σ T ◇A → σ.n T A, for a new prefix σ.n not on the branch.
Only applies to `σ T ◇A` (Table 6.2, B&D).
"""
function apply_diamond_true_rule(pf::PrefixedFormula, branch::TableauBranch,
                                 pair::OperatorPair=BASE_PAIR)
    pf.sign isa TrueSign && pf.formula isa pair.diamond || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    _has_witness(branch, σ, T_SIGN, A) && return NoRule()
    τ = fresh_prefix(branch, σ)
    StackRule([pf_true(τ, A)])
end

"""
    apply_diamond_false_rule(pf, branch, pair=BASE_PAIR) -> RuleResult

◇F rule for K: σ F ◇A → σ.n F A, for each used child prefix σ.n on the branch.
Only applies to `σ F ◇A` (Table 6.2, B&D).
"""
function apply_diamond_false_rule(pf::PrefixedFormula, branch::TableauBranch,
                                  pair::OperatorPair=BASE_PAIR)
    pf.sign isa FalseSign && pf.formula isa pair.diamond || return NoRule()
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
    apply_T_box_rule(pf, branch, pair=BASE_PAIR) -> RuleResult

T□ rule (reflexive models): σ T □A → σ T A.
Adds σ T A directly (reflexivity: Rσσ) (Table 6.3, B&D).
"""
function apply_T_box_rule(pf::PrefixedFormula, branch::TableauBranch,
                          pair::OperatorPair=BASE_PAIR)
    pf.sign isa TrueSign && pf.formula isa pair.box || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    new_pf = pf_true(σ, A)
    new_pf ∈ branch.formula_set ? NoRule() : StackRule([new_pf])
end

"""
    apply_T_diamond_rule(pf, branch, pair=BASE_PAIR) -> RuleResult

T◇ rule (reflexive models): σ F ◇A → σ F A.
"""
function apply_T_diamond_rule(pf::PrefixedFormula, branch::TableauBranch,
                              pair::OperatorPair=BASE_PAIR)
    pf.sign isa FalseSign && pf.formula isa pair.diamond || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    new_pf = pf_false(σ, A)
    new_pf ∈ branch.formula_set ? NoRule() : StackRule([new_pf])
end

"""
    apply_D_box_rule(pf, branch, pair=BASE_PAIR) -> RuleResult

D□ rule (serial models): σ T □A → σ T ◇A.
"""
function apply_D_box_rule(pf::PrefixedFormula, branch::TableauBranch,
                          pair::OperatorPair=BASE_PAIR)
    pf.sign isa TrueSign && pf.formula isa pair.box || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    new_pf = pf_true(σ, pair.diamond(A))
    new_pf ∈ branch.formula_set ? NoRule() : StackRule([new_pf])
end

"""
    apply_D_diamond_rule(pf, branch, pair=BASE_PAIR) -> RuleResult

D◇ rule (serial models): σ F ◇A → σ F □A.
"""
function apply_D_diamond_rule(pf::PrefixedFormula, branch::TableauBranch,
                              pair::OperatorPair=BASE_PAIR)
    pf.sign isa FalseSign && pf.formula isa pair.diamond || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    new_pf = pf_false(σ, pair.box(A))
    new_pf ∈ branch.formula_set ? NoRule() : StackRule([new_pf])
end

"""
    apply_B_box_rule(pf, branch, pair=BASE_PAIR) -> RuleResult

B□ rule (symmetric models): σ.n T □A → σ T A (σ = parent of σ.n).
"""
function apply_B_box_rule(pf::PrefixedFormula, branch::TableauBranch,
                          pair::OperatorPair=BASE_PAIR)
    pf.sign isa TrueSign && pf.formula isa pair.box || return NoRule()
    length(pf.prefix.seq) < 2 && return NoRule()
    σ_n = pf.prefix
    σ = parent_prefix(σ_n)
    A = pf.formula.operand
    new_pf = pf_true(σ, A)
    new_pf ∈ branch.formula_set ? NoRule() : StackRule([new_pf])
end

"""
    apply_B_diamond_rule(pf, branch, pair=BASE_PAIR) -> RuleResult

B◇ rule (symmetric models): σ.n F ◇A → σ F A.
"""
function apply_B_diamond_rule(pf::PrefixedFormula, branch::TableauBranch,
                              pair::OperatorPair=BASE_PAIR)
    pf.sign isa FalseSign && pf.formula isa pair.diamond || return NoRule()
    length(pf.prefix.seq) < 2 && return NoRule()
    σ_n = pf.prefix
    σ = parent_prefix(σ_n)
    A = pf.formula.operand
    new_pf = pf_false(σ, A)
    new_pf ∈ branch.formula_set ? NoRule() : StackRule([new_pf])
end

"""
    apply_4_box_rule(pf, branch, pair=BASE_PAIR) -> RuleResult

4□ rule (transitive models): σ T □A → σ.n T □A, for each used prefix σ.n.
"""
function apply_4_box_rule(pf::PrefixedFormula, branch::TableauBranch,
                          pair::OperatorPair=BASE_PAIR)
    pf.sign isa TrueSign && pf.formula isa pair.box || return NoRule()
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
    apply_4_diamond_rule(pf, branch, pair=BASE_PAIR) -> RuleResult

4◇ rule (transitive models): σ F ◇A → σ.n F ◇A, for each used prefix σ.n.
Symmetric counterpart to 4□ (Table 6.3, B&D).
"""
function apply_4_diamond_rule(pf::PrefixedFormula, branch::TableauBranch,
                              pair::OperatorPair=BASE_PAIR)
    pf.sign isa FalseSign && pf.formula isa pair.diamond || return NoRule()
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
    apply_4T_box_rule(pf, branch, pair=BASE_PAIR) -> RuleResult

4T□ rule (euclidean models): σ.n T □A → σ T □A.
"""
function apply_4T_box_rule(pf::PrefixedFormula, branch::TableauBranch,
                           pair::OperatorPair=BASE_PAIR)
    pf.sign isa TrueSign && pf.formula isa pair.box || return NoRule()
    length(pf.prefix.seq) < 2 && return NoRule()
    σ_n = pf.prefix
    σ = parent_prefix(σ_n)
    new_pf = pf_true(σ, pf.formula)
    new_pf ∈ branch.formula_set ? NoRule() : StackRule([new_pf])
end

"""
    apply_4T_diamond_rule(pf, branch, pair=BASE_PAIR) -> RuleResult

4T◇ rule (euclidean models): σ.n F ◇A → σ.m F ◇A for used σ.m.
"""
function apply_4T_diamond_rule(pf::PrefixedFormula, branch::TableauBranch,
                               pair::OperatorPair=BASE_PAIR)
    pf.sign isa FalseSign && pf.formula isa pair.diamond || return NoRule()
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
whose prefix is already on the branch (no new world created). Each rule is
generic over an `OperatorPair` (third argument, default □/◇); system
construction binds the pair via `BoundRule`.

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
- `operator_pairs`: the `OperatorPair`s this system has rules for. The base
  □/◇ rules fire for each declared pair; a modal operator whose type appears
  in no pair is *unsupported* and rejected by `build_tableau` rather than
  silently treated as an atom.
- `used_prefix_rules`: rules that fire on existing prefixes (reflexivity,
  symmetry, transitivity, euclideanness — T□/T◇, B□/B◇, 4□/4◇, 4T□/4T◇),
  each bound to its operator pair via `BoundRule`
- `witness_rules`: rules that create new prefixes to ensure a successor
  exists (seriality — D□/D◇)
- `uses_blocking`: whether ancestor-equality blocking (loop-checking) applies
  to this system. Only needed when a used-prefix rule re-injects an
  *unstripped* boxed formula into a descendant world (transitivity: 4□/4◇,
  and the temporal analogue) — that is the only shape of rule that can force
  unbounded world creation. See Goré (1999), *Tableau Methods for Modal and
  Temporal Logics*, in *Handbook of Tableau Methods*, §6.6.
- `schemas`: the `AxiomSchema`s this system was derived from (empty for
  hand-assembled systems like `TABLEAU_KDt`). Metadata carried so that any
  future per-system frame lookup (e.g. closing an extracted countermodel's
  frame into the system's frame class) derives from the Sahlqvist table
  instead of a second hand-maintained encoding.

Prefer deriving a system from a `ModalSystem` via
`TableauSystem(ms::ModalSystem)` over hand-assembling rule vectors — the
standard constants below are all derivations, which makes drift between a
system's axioms and its rules structurally impossible (the KB unsoundness of
issue #10 was exactly such drift).
"""
struct TableauSystem
    name::Symbol
    operator_pairs::Vector{OperatorPair}
    used_prefix_rules::Vector{Function}
    witness_rules::Vector{Function}
    uses_blocking::Bool
    schemas::Vector{AxiomSchema}
end

TableauSystem(name, used_prefix_rules, witness_rules;
              uses_blocking=false, operator_pairs=[BASE_PAIR], schemas=AxiomSchema[]) =
    TableauSystem(name, operator_pairs, used_prefix_rules, witness_rules,
                  uses_blocking, schemas)

"""
    TableauSystem(ms::ModalSystem; operator_pairs=[BASE_PAIR]) -> TableauSystem

Derive a tableau system from a Hilbert-style `ModalSystem`: each of the
system's axiom schemas contributes its rules via [`tableau_rules`](@ref) /
[`tableau_witness_rules`](@ref) (the Sahlqvist correspondence, BdRV Ch.3),
bound to each operator pair. `uses_blocking` is set iff the schema set
contains `Schema4` — transitivity's 4□/4◇ are the only rule shape that
re-injects unstripped boxed formulas into descendants (see the struct
docstring). The schemas are retained as metadata in `.schemas`.

This is the approved `ModalSystem` ↔ `TableauSystem` connection
(`plans/tableau-parametrization.md`, Option A): derivation goes through
`tableau_rules(::AxiomSchema)` only — no reverse derivation, no automatic
frame-condition synthesis.
"""
function TableauSystem(ms::ModalSystem;
                       operator_pairs::Vector{OperatorPair}=[BASE_PAIR])
    used = Function[]
    witness = Function[]
    for pair in operator_pairs, schema in ms.schemas
        append!(used,    BoundRule(r, pair) for r in tableau_rules(schema))
        append!(witness, BoundRule(r, pair) for r in tableau_witness_rules(schema))
    end
    TableauSystem(Symbol(ms.name), operator_pairs, used, witness,
                  any(s -> s isa Schema4, ms.schemas), copy(ms.schemas))
end

"""
    TABLEAU_K

Tableau system for the minimal normal modal logic K. No frame conditions;
only propositional rules and the basic □/◇ modal rules (Table 6.2, B&D).
Derived from [`SYSTEM_K`](@ref).
"""
const TABLEAU_K  = TableauSystem(SYSTEM_K)

"""
    TABLEAU_KT

Tableau system for KT (reflexive frames). Adds the T□ and T◇ rules
corresponding to the T axiom □p → p (Table 6.3, B&D).
Derived from [`SYSTEM_KT`](@ref).
"""
const TABLEAU_KT = TableauSystem(SYSTEM_KT)

"""
    TABLEAU_KD

Tableau system for KD (serial frames). Adds the D□ and D◇ witness rules
corresponding to the D axiom □p → ◇p (Table 6.3, B&D).
Derived from [`SYSTEM_KD`](@ref).
"""
const TABLEAU_KD = TableauSystem(SYSTEM_KD)

"""
    TABLEAU_KB

Tableau system for KB (symmetric frames). Adds the B□ and B◇ rules
corresponding to the B axiom p → □◇p (Table 6.3, B&D).
Derived from [`SYSTEM_KB`](@ref).

Earlier versions wrongly included the T□/T◇ (reflexivity) rules, making the
system prove KT-theorems such as □p → p that are invalid on symmetric
frames (issue #10) — hand-assembly drift the derivation now rules out.
"""
const TABLEAU_KB = TableauSystem(SYSTEM_KB)

"""
    TABLEAU_K4

Tableau system for K4 (transitive frames). Adds the 4□ and 4◇ rules
corresponding to the 4 axiom □p → □□p (Table 6.3, B&D).
Derived from [`SYSTEM_K4`](@ref); `Schema4` also switches on
ancestor-equality blocking.
"""
const TABLEAU_K4 = TableauSystem(SYSTEM_K4)

"""
    TABLEAU_S4

Tableau system for S4 (reflexive + transitive frames). Combines T□/T◇
and 4□/4◇ rules (Table 6.4, B&D). Derived from [`SYSTEM_S4`](@ref).
"""
const TABLEAU_S4 = TableauSystem(SYSTEM_S4)

"""
    TABLEAU_S5

Tableau system for S5 (equivalence relation frames). Combines T□/T◇,
B□/B◇, 4□/4◇, and 4T□/4T◇ rules (Table 6.4, B&D).

B&D's S5 *calculus* (Table 6.4) uses rules for all four of T, B, 4, and 5,
i.e. the KTB45 presentation of S5, whereas the *axiom system*
[`SYSTEM_S5`](@ref) is B&D's Definition 3.9 presentation KT5. The two are
deductively equivalent; the derivation below spells out the KTB45
presentation so the derived rule set matches Table 6.4 exactly.
"""
const TABLEAU_S5 = TableauSystem(
    ModalSystem("S5", [SchemaK(), SchemaDual(), SchemaT(), SchemaB(),
                       Schema4(), Schema5()]))

# ── Blocking for temporal tableaux ──

"""
    _prefix_content(branch::TableauBranch, σ::Prefix) -> Set{Tuple{Type,Formula}}

The formula content of prefix σ: the set of (sign_type, formula) pairs at σ.
Used to determine whether a prefix is subsumed by an ancestor.
"""
function _prefix_content(branch::TableauBranch, σ::Prefix)
    Set{Tuple{Type,Formula}}(
        (typeof(pf.sign), pf.formula)
        for pf in branch.formulas
        if pf.prefix == σ
    )
end

"""
    _ancestors(σ::Prefix) -> Vector{Prefix}

Return all proper ancestor prefixes of σ, from root to parent.

# Example

```julia
_ancestors(Prefix([1,2,3]))  # [Prefix([1]), Prefix([1,2])]
```
"""
function _ancestors(σ::Prefix)
    [Prefix(σ.seq[1:k]) for k in 1:(length(σ.seq)-1)]
end

"""
    _should_block(branch::TableauBranch, σ::Prefix) -> Bool

Return `true` if prefix σ should be blocked because an ancestor labels an
*identical* set of signed formulas — σ's subtableau would be isomorphic to
the ancestor's, so expanding it further is redundant.

This is a pure function of the branch's current content: it is recomputed
from scratch on every call (see `_compute_blocked_set`), not cached, because
a prefix's content — and hence its blocked status — can change as further
rules fire (e.g. an ancestor's `apply_4_box_rule` pushing new content into a
descendant). A prefix that no longer matches any ancestor must stop being
blocked.

Blocking on exact equality (rather than subset) follows Goré (1999),
*Tableau Methods for Modal and Temporal Logics*, in *Handbook of Tableau
Methods*, §6.6; see also Fitting (1983), Ch. 9, for the general loop-checking
framework, and Wolper (1985) for temporal tableaux.
"""
function _should_block(branch::TableauBranch, σ::Prefix)
    length(σ.seq) <= 1 && return false  # root is never blocked
    σ_content = _prefix_content(branch, σ)
    any(anc -> σ_content == _prefix_content(branch, anc), _ancestors(σ))
end

"""
    _compute_blocked_set(branch::TableauBranch) -> Set{Prefix}

Recompute the full set of blocked prefixes on `branch` from its current
content. Called once per `_apply_all_rules` invocation for systems with
`uses_blocking = true`; see that function's docstring.
"""
function _compute_blocked_set(branch::TableauBranch)
    Set{Prefix}(σ for σ in branch.prefix_set if _should_block(branch, σ))
end

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

    # Recomputed fresh for whichever branch is about to be returned — blocking
    # status must be re-derived from current content on every rule application
    # (not just world-creating ones), since e.g. a used-prefix rule can push
    # new content into an already-blocked descendant and distinguish it from
    # its ancestors. Disabled entirely for systems with uses_blocking=false.
    finalize_blocked(b::TableauBranch) = system.uses_blocking ? _compute_blocked_set(b) : Set{Prefix}()

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
        pf.prefix ∈ branch.blocked && continue  # Strategy B: skip blocked prefixes

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
                                  new_branch.prefix_set, new_branch.expanded,
                                  finalize_blocked(new_branch), i)]
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
                                  left.prefix_set, left_exp,
                                  finalize_blocked(left), i),
                    TableauBranch(right.formulas, right.formula_set,
                                  right.prefix_set, right_exp,
                                  finalize_blocked(right), i)]
        end
    end

    # Priority 2a: □F-shape rules first (before ◇T-shape) — ensures worlds are
    # named before diamond-true rules fire on them. Each declared operator
    # pair contributes its own □F rule (𝐆F via the temporal pair).
    # World-creating rules reset scan_start to 1: new children mean old
    # Box-true/Diamond-false rules may need to propagate again.
    for pf in branch.formulas
        pf.prefix ∈ branch.blocked && continue  # Strategy A: skip blocked prefixes
        pf.sign isa FalseSign || continue
        for pair in system.operator_pairs
            pf.formula isa pair.box || continue
            r = apply_box_false_rule(pf, branch, pair)
            r isa StackRule || continue
            new_branch = branch
            for addition in r.additions
                addition ∈ new_branch.formula_set && continue
                new_branch = append_formula(new_branch, addition)
            end
            new_branch == branch && continue
            return [TableauBranch(new_branch.formulas, new_branch.formula_set,
                                  new_branch.prefix_set, BitSet(), finalize_blocked(new_branch), 1)]
        end
    end

    # Priority 2b: ◇T-shape rules (𝐅T via the temporal pair)
    for pf in branch.formulas
        pf.prefix ∈ branch.blocked && continue  # Strategy A: skip blocked prefixes
        pf.sign isa TrueSign || continue
        for pair in system.operator_pairs
            pf.formula isa pair.diamond || continue
            r = apply_diamond_true_rule(pf, branch, pair)
            r isa StackRule || continue
            new_branch = branch
            for addition in r.additions
                addition ∈ new_branch.formula_set && continue
                new_branch = append_formula(new_branch, addition)
            end
            new_branch == branch && continue
            return [TableauBranch(new_branch.formulas, new_branch.formula_set,
                                  new_branch.prefix_set, BitSet(), finalize_blocked(new_branch), 1)]
        end
    end

    # Priority 2c: witness-creation rules (seriality, etc.)
    if !isempty(system.witness_rules)
        for pf in branch.formulas
            pf.prefix ∈ branch.blocked && continue  # Strategy A: skip blocked prefixes
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
                                  new_branch.prefix_set, BitSet(), finalize_blocked(new_branch), 1)]
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

    # Base K-shape used-prefix rules (□T, ◇F) for each declared operator
    # pair (e.g. 𝐆T/𝐅F via the temporal pair in TABLEAU_KDt)
    for pair in system.operator_pairs
        r = apply_box_true_rule(pf, branch, pair)
        r isa NoRule || return r
        r = apply_diamond_false_rule(pf, branch, pair)
        r isa NoRule || return r
    end

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

A prefixed tableau: a set of branches, each either closed or expanded as far
as the search went. A tableau is *closed* when all branches are closed
(Definition 6.2, B&D).

`complete` is `true` when the search terminated on its own — every branch
either closed or saturated (no more rules apply) — and `false` when it was
cut off by `max_steps`. An *open incomplete* tableau carries no verdict: its
open branches might still have closed with more steps, and
`extract_countermodel` requires an open **complete** branch (Theorem 6.19).
"""
struct Tableau
    branches::Vector{TableauBranch}
    complete::Bool
end

function Base.show(io::IO, t::Tableau)
    status = is_closed(t) ? "CLOSED" :
             (t.complete ? "open" : "open, INCOMPLETE (max_steps exhausted)")
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
    _check_tableau_supported(f::Formula, system::TableauSystem)

Throw `ArgumentError` if `f` contains a modal operator `system` has no rules
for — a non-propositional node whose type appears in none of the system's
operator pairs. Silently treating an unsupported operator as an opaque atom
returns unsound verdicts (it made valid Kt-formulas like p → 𝐆(𝐏p)
unprovable — issue #10), so unsupported operators are rejected up front.

This covers the quarantined temporal operators (𝐇/PastBox, 𝐏/PastDiamond,
Since, Until — B&D provides no temporal tableau rules and no system declares
a pair for them), base systems fed operators they lack rules for (e.g.
`TABLEAU_K` given a 𝐆 formula), and formula types with no tableau treatment
at all (e.g. epistemic `Knowledge`).
"""
function _check_tableau_supported(f::Formula, system::TableauSystem)
    supported = f isa Atom || f isa Bottom ||
                f isa Not || f isa And || f isa Or || f isa Implies || f isa Iff ||
                any(pair -> f isa pair.box || f isa pair.diamond,
                    system.operator_pairs)
    if !supported
        detail = f isa PastBox || f isa PastDiamond || f isa Since || f isa Until ?
            "B&D provides no temporal tableau rules; see issue #10" :
            "the system declares no operator pair covering it"
        throw(ArgumentError("no tableau rules exist for $(nameof(typeof(f))) " *
                            "in system $(system.name): $detail"))
    end
    for c in children(f)
        _check_tableau_supported(c, system)
    end
end

"""
    build_tableau(assumptions::Vector{PrefixedFormula},
                  system::TableauSystem; max_steps::Int=1000) -> Tableau

Construct a tableau for the given set of assumptions using the rules
of `system`. The tableau search terminates when all branches are
closed or no more rules apply (Definition 6.17, Proposition 6.18, B&D).

`max_steps` bounds the number of rule applications to prevent non-termination
for non-theorems in systems without the finite model property. When the bound
is hit before every branch closes or saturates, the returned tableau has
`complete == false` and its open branches carry no verdict.

Throws `ArgumentError` if any assumption contains a modal operator `system`
has no rules for: the quarantined temporal operators 𝐇, 𝐏, `Since`, `Until`
(B&D presents no temporal tableau rules), and any operator outside the
system's declared operator pairs (e.g. 𝐆 fed to `TABLEAU_K`). Silently
treating such operators as atoms would return unsound provability verdicts
(issue #10).
"""
function build_tableau(assumptions::Vector{PrefixedFormula},
                       system::TableauSystem; max_steps::Int=1000)
    for pf in assumptions
        _check_tableau_supported(pf.formula, system)
    end
    branches = [TableauBranch(copy(assumptions))]
    steps = 0
    saturated = Set{Int}()  # indices of branches no rule applies to
    complete = true

    while true
        # Find first open branch not yet known to be saturated
        idx = 0
        for i in eachindex(branches)
            if !(i in saturated) && !is_closed(branches[i])
                idx = i
                break
            end
        end
        idx == 0 && break  # every branch closed or saturated: complete

        if steps >= max_steps
            complete = false
            break
        end

        branch = branches[idx]
        new_branches = _apply_all_rules(branch, system)

        if length(new_branches) == 1 && new_branches[1] == branch
            # Saturated — no more rules apply; move on to the other open
            # branches instead of abandoning them (they must be expanded
            # too, or extract_countermodel on them would violate its
            # open-complete-branch precondition)
            push!(saturated, idx)
            continue
        end

        branches[idx] = new_branches[1]
        for k in 2:length(new_branches)
            push!(branches, new_branches[k])
        end

        steps += 1
    end

    Tableau(branches, complete)
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

⚠️ **Frame class caveat**: B&D proves Theorem 6.19 for K only, and the
returned model's accessibility relation is the raw prefix tree — it is *not*
closed into the frame class of the system the tableau was built with. A
branch from an open KT tableau satisfies its formulas by virtue of the T-rule
propagations, but the extracted frame is not literally reflexive. Closing the
frame per the system's schemas (reflexive/symmetric/transitive closure, as
the completeness proofs for extended systems require) is future work; until
then, treat the extracted model as a K-countermodel witnessing the branch's
formulas, not as a member of the stricter frame class. The `schemas` field
on `TableauSystem` carries the metadata this closure will derive from.
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
                   conclusion::Formula; max_steps::Int=1000) -> Union{Bool,Missing}

Return `true` if there is a closed tableau showing `premises ⊢ conclusion`
in `system`. Constructs the initial assumptions
  1 T B₁, …, 1 T Bₙ, 1 F conclusion
and checks whether the resulting tableau closes (Definition 6.2, B&D).

Returns `false` only when the tableau saturated without closing (a genuine
open complete tableau, i.e. a countermodel exists). Returns `missing` when
the search hit `max_steps` before every branch closed or saturated — no
verdict either way; retry with a larger `max_steps`.

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
    is_closed(t) && return true
    t.complete ? false : missing
end

"""
    tableau_consistent(system::TableauSystem, formulas::Vector{Formula};
                       max_steps::Int=1000) -> Union{Bool,Missing}

Return `true` if `formulas` is satisfiable in `system` (i.e., the tableau
for `1 T A₁, …, 1 T Aₙ` saturates without closing), `false` if the tableau
closes, and `missing` when the search hit `max_steps` before every branch
closed or saturated — no verdict either way; retry with a larger `max_steps`.
"""
function tableau_consistent(system::TableauSystem, formulas::Vector{Formula};
                             max_steps::Int=1000)
    root = Prefix([1])
    assumptions = [pf_true(root, A) for A in formulas]
    t = build_tableau(assumptions, system; max_steps=max_steps)
    is_closed(t) && return false
    t.complete ? true : missing
end
