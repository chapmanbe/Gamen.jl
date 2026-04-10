# Chapter 14: Temporal Logics (B&D)

# ── Formula types (Definition 14.2) ──

"""
    PastBox <: Formula

The "historically" (past necessity) operator H. M,t ⊩ HA iff M,t' ⊩ A for
every t' with t' ≺ t (Definition 14.4, item 8, B&D).

H is the past dual of G: HA abbreviates ¬P¬A.
"""
struct PastBox <: Formula
    operand::Formula
end

"""
    PastDiamond <: Formula

The "previously" (past possibility) operator P. M,t ⊩ PA iff M,t' ⊩ A for
some t' with t' ≺ t (Definition 14.4, item 7, B&D).
"""
struct PastDiamond <: Formula
    operand::Formula
end

"""
    FutureBox <: Formula

The "always" (future necessity) operator G. M,t ⊩ GA iff M,t' ⊩ A for
every t' with t ≺ t' (Definition 14.4, item 10, B&D).

G is the future dual of F: GA abbreviates ¬F¬A.
"""
struct FutureBox <: Formula
    operand::Formula
end

"""
    FutureDiamond <: Formula

The "eventually" (future possibility) operator F. M,t ⊩ FA iff M,t' ⊩ A for
some t' with t ≺ t' (Definition 14.4, item 9, B&D).
"""
struct FutureDiamond <: Formula
    operand::Formula
end

"""
    Since <: Formula

The binary "since" operator S. M,t ⊩ SBC iff there exists t' ≺ t such that
M,t' ⊩ B and for all s with t' ≺ s ≺ t, M,s ⊩ C
(Definition 14.5, item 1, B&D).
"""
struct Since <: Formula
    left::Formula   # B: the formula that was true at t'
    right::Formula  # C: the formula that holds between t' and t
end

"""
    Until <: Formula

The binary "until" operator U. M,t ⊩ UBC iff there exists t' with t ≺ t'
such that M,t' ⊩ B and for all s with t ≺ s ≺ t', M,s ⊩ C
(Definition 14.5, item 2, B&D).
"""
struct Until <: Formula
    left::Formula   # B: the formula that will be true at t'
    right::Formula  # C: the formula that holds between t and t'
end

# Unicode operator aliases
"""
    𝐇(operand::Formula)

Unicode alias for [`PastBox`](@ref) (H, "historically").
"""
const 𝐇 = PastBox

"""
    𝐏(operand::Formula)

Unicode alias for [`PastDiamond`](@ref) (P, "previously").
"""
const 𝐏 = PastDiamond

"""
    𝐆(operand::Formula)

Unicode alias for [`FutureBox`](@ref) (G, "always in the future").
"""
const 𝐆 = FutureBox

"""
    𝐅(operand::Formula)

Unicode alias for [`FutureDiamond`](@ref) (F, "eventually").
"""
const 𝐅 = FutureDiamond

# Pretty printing
Base.show(io::IO, f::PastDiamond) = print(io, "P", f.operand)
Base.show(io::IO, f::PastBox) = print(io, "H", f.operand)
Base.show(io::IO, f::FutureDiamond) = print(io, "F", f.operand)
Base.show(io::IO, f::FutureBox) = print(io, "G", f.operand)
Base.show(io::IO, f::Since) = print(io, "(S", f.left, f.right, ")")
Base.show(io::IO, f::Until) = print(io, "(U", f.left, f.right, ")")

# Structural equality
Base.:(==)(a::PastBox, b::PastBox) = a.operand == b.operand
Base.:(==)(a::PastDiamond, b::PastDiamond) = a.operand == b.operand
Base.:(==)(a::FutureBox, b::FutureBox) = a.operand == b.operand
Base.:(==)(a::FutureDiamond, b::FutureDiamond) = a.operand == b.operand
Base.:(==)(a::Since, b::Since) = a.left == b.left && a.right == b.right
Base.:(==)(a::Until, b::Until) = a.left == b.left && a.right == b.right

# Hash
Base.hash(f::PastBox, h::UInt) = hash((:PastBox, f.operand), h)
Base.hash(f::PastDiamond, h::UInt) = hash((:PastDiamond, f.operand), h)
Base.hash(f::FutureBox, h::UInt) = hash((:FutureBox, f.operand), h)
Base.hash(f::FutureDiamond, h::UInt) = hash((:FutureDiamond, f.operand), h)
Base.hash(f::Since, h::UInt) = hash((:Since, f.left, f.right), h)
Base.hash(f::Until, h::UInt) = hash((:Until, f.left, f.right), h)

# is_modal_free extensions
is_modal_free(::PastBox) = false
is_modal_free(::PastDiamond) = false
is_modal_free(::FutureBox) = false
is_modal_free(::FutureDiamond) = false
is_modal_free(::Since) = false
is_modal_free(::Until) = false

# ── Temporal model (Definition 14.3) ──

"""
    TemporalModel

A temporal model M = ⟨T, ≺, V⟩ where T is a set of time points, ≺ is a
binary precedence relation on T, and V assigns to each propositional variable
a set V(p) ⊆ T of time points where p is true (Definition 14.3, B&D).

Internally represented as a `KripkeModel` — the precedence relation ≺ is the
accessibility relation. A time point t₁ ≺ t₂ means t₁ precedes t₂, stored as
t₁ => t₂ in the relation.

The type alias [`TemporalModel`](@ref) is simply `KripkeModel` — the same
model infrastructure is reused, only the temporal operators are new.
"""
const TemporalModel = KripkeModel

# ── Semantics (Definition 14.4) ──

# PA: M,t ⊩ PA iff M,t' ⊩ A for some t' with t' ≺ t
# "previously" — t' precedes t means t is accessible FROM t' in the frame,
# so we need worlds that HAVE t in their successor set, i.e., predecessors of t.
function satisfies(model::TemporalModel, t::Symbol, f::PastDiamond)
    # predecessors of t: worlds t' such that t' ≺ t (t' => t in relation)
    any(model.frame.worlds) do t_prime
        t in accessible(model.frame, t_prime) && satisfies(model, t_prime, f.operand)
    end
end

# HA: M,t ⊩ HA iff M,t' ⊩ A for every t' with t' ≺ t
function satisfies(model::TemporalModel, t::Symbol, f::PastBox)
    all(model.frame.worlds) do t_prime
        !(t in accessible(model.frame, t_prime)) || satisfies(model, t_prime, f.operand)
    end
end

# FA: M,t ⊩ FA iff M,t' ⊩ A for some t' with t ≺ t'
function satisfies(model::TemporalModel, t::Symbol, f::FutureDiamond)
    any(t_prime -> satisfies(model, t_prime, f.operand), accessible(model.frame, t))
end

# GA: M,t ⊩ GA iff M,t' ⊩ A for every t' with t ≺ t'
function satisfies(model::TemporalModel, t::Symbol, f::FutureBox)
    all(t_prime -> satisfies(model, t_prime, f.operand), accessible(model.frame, t))
end

# SBC: M,t ⊩ SBC iff ∃t' ≺ t: M,t' ⊩ B and ∀s with t' ≺ s ≺ t: M,s ⊩ C
function satisfies(model::TemporalModel, t::Symbol, f::Since)
    for t_prime in model.frame.worlds
        # t_prime must precede t
        t in accessible(model.frame, t_prime) || continue
        # M,t' ⊩ B
        satisfies(model, t_prime, f.left) || continue
        # For all s with t' ≺ s ≺ t (i.e., s is a successor of t' and a predecessor of t)
        all_between = all(model.frame.worlds) do s
            s == t_prime && return true
            s == t && return true
            between = (s in accessible(model.frame, t_prime)) &&
                       (t in accessible(model.frame, s))
            !between || satisfies(model, s, f.right)
        end
        all_between && return true
    end
    false
end

# UBC: M,t ⊩ UBC iff ∃t': t ≺ t' and M,t' ⊩ B and ∀s with t ≺ s ≺ t': M,s ⊩ C
function satisfies(model::TemporalModel, t::Symbol, f::Until)
    for t_prime in accessible(model.frame, t)
        # M,t' ⊩ B
        satisfies(model, t_prime, f.left) || continue
        # For all s with t ≺ s ≺ t' (s is successor of t and predecessor of t')
        all_between = all(model.frame.worlds) do s
            s == t && return true
            s == t_prime && return true
            between = (s in accessible(model.frame, t)) &&
                       (t_prime in accessible(model.frame, s))
            !between || satisfies(model, s, f.right)
        end
        all_between && return true
    end
    false
end

# ── Temporal tableau rules ──
#
# These follow the same pattern as the modal rules in tableaux.jl (Table 6.2–6.3, B&D).
# FutureBox (𝐆) and FutureDiamond (𝐅) use the same prefix tree as Box/Diamond —
# in Phase 1, temporal and deontic accessibility share a single relation.

# ── Base temporal rules (analogous to □/◇ rules for K, Table 6.2) ──

"""
    apply_futurebox_true_rule(pf::PrefixedFormula, branch::TableauBranch) -> RuleResult

𝐆T rule: σ T 𝐆A → σ.n T A, for each used child prefix σ.n on the branch.
Analogous to `apply_box_true_rule` for □.
"""
function apply_futurebox_true_rule(pf::PrefixedFormula, branch::TableauBranch)
    pf.sign isa TrueSign && pf.formula isa FutureBox || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    used = used_prefixes(branch)

    additions = PrefixedFormula[]
    for τ in used
        τ == σ && continue
        is_child = length(τ.seq) == length(σ.seq) + 1 && τ.seq[1:end-1] == σ.seq
        is_child || continue
        new_pf = pf_true(τ, A)
        new_pf ∉ branch.formulas && push!(additions, new_pf)
    end

    isempty(additions) ? NoRule() : StackRule(additions)
end

"""
    apply_futurebox_false_rule(pf::PrefixedFormula, branch::TableauBranch) -> RuleResult

𝐆F rule: σ F 𝐆A → σ.n F A, for a new prefix σ.n not on the branch.
Analogous to `apply_box_false_rule` for □.
"""
function apply_futurebox_false_rule(pf::PrefixedFormula, branch::TableauBranch)
    pf.sign isa FalseSign && pf.formula isa FutureBox || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    _has_witness(branch, σ, F_SIGN, A) && return NoRule()
    τ = fresh_prefix(branch, σ)
    StackRule([pf_false(τ, A)])
end

"""
    apply_futurediamond_true_rule(pf::PrefixedFormula, branch::TableauBranch) -> RuleResult

𝐅T rule: σ T 𝐅A → σ.n T A, for a new prefix σ.n not on the branch.
Analogous to `apply_diamond_true_rule` for ◇.
"""
function apply_futurediamond_true_rule(pf::PrefixedFormula, branch::TableauBranch)
    pf.sign isa TrueSign && pf.formula isa FutureDiamond || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    _has_witness(branch, σ, T_SIGN, A) && return NoRule()
    τ = fresh_prefix(branch, σ)
    StackRule([pf_true(τ, A)])
end

"""
    apply_futurediamond_false_rule(pf::PrefixedFormula, branch::TableauBranch) -> RuleResult

𝐅F rule: σ F 𝐅A → σ.n F A, for each used child prefix σ.n on the branch.
Analogous to `apply_diamond_false_rule` for ◇.
"""
function apply_futurediamond_false_rule(pf::PrefixedFormula, branch::TableauBranch)
    pf.sign isa FalseSign && pf.formula isa FutureDiamond || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    used = used_prefixes(branch)

    additions = PrefixedFormula[]
    for τ in used
        τ == σ && continue
        is_child = length(τ.seq) == length(σ.seq) + 1 && τ.seq[1:end-1] == σ.seq
        is_child || continue
        new_pf = pf_false(τ, A)
        new_pf ∉ branch.formulas && push!(additions, new_pf)
    end

    isempty(additions) ? NoRule() : StackRule(additions)
end

# ── Temporal frame condition rules ──

"""
    apply_temporal_T_futurebox_rule(pf::PrefixedFormula, branch::TableauBranch) -> RuleResult

Temporal T𝐆 rule (reflexive temporal frames): σ T 𝐆A → σ T A.
Analogous to `apply_T_box_rule` for □.
"""
function apply_temporal_T_futurebox_rule(pf::PrefixedFormula, branch::TableauBranch)
    pf.sign isa TrueSign && pf.formula isa FutureBox || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    new_pf = pf_true(σ, A)
    new_pf ∈ branch.formulas ? NoRule() : StackRule([new_pf])
end

"""
    apply_temporal_T_futurediamond_rule(pf::PrefixedFormula, branch::TableauBranch) -> RuleResult

Temporal T𝐅 rule (reflexive temporal frames): σ F 𝐅A → σ F A.
Analogous to `apply_T_diamond_rule` for ◇.
"""
function apply_temporal_T_futurediamond_rule(pf::PrefixedFormula, branch::TableauBranch)
    pf.sign isa FalseSign && pf.formula isa FutureDiamond || return NoRule()
    σ = pf.prefix
    A = pf.formula.operand
    new_pf = pf_false(σ, A)
    new_pf ∈ branch.formulas ? NoRule() : StackRule([new_pf])
end

"""
    apply_temporal_4_futurebox_rule(pf::PrefixedFormula, branch::TableauBranch) -> RuleResult

Temporal 4𝐆 rule (transitive temporal frames): σ T 𝐆A → σ.n T 𝐆A, for each used child σ.n.
Analogous to `apply_4_box_rule` for □.
"""
function apply_temporal_4_futurebox_rule(pf::PrefixedFormula, branch::TableauBranch)
    pf.sign isa TrueSign && pf.formula isa FutureBox || return NoRule()
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
    apply_temporal_4_futurediamond_rule(pf::PrefixedFormula, branch::TableauBranch) -> RuleResult

Temporal 4𝐅 rule (transitive temporal frames): σ F 𝐅A → σ.n F 𝐅A, for each used child σ.n.
Analogous to `apply_4_diamond_rule` for ◇.
"""
function apply_temporal_4_futurediamond_rule(pf::PrefixedFormula, branch::TableauBranch)
    pf.sign isa FalseSign && pf.formula isa FutureDiamond || return NoRule()
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

# ── Combined deontic-temporal tableau system ──

"""
    TABLEAU_KDt

Tableau system for combined deontic-temporal logic. Deontic operators (□/◇)
have serial frames (D axiom); temporal operators (𝐆/𝐅) have reflexive and
transitive frames.

In Phase 1, deontic and temporal accessibility share a single relation.
Multi-relational prefixes (distinguishing R_d from R_t) are deferred to Phase 2.
"""
const TABLEAU_KDt = TableauSystem(:KDt,
    Function[
        # Temporal reflexivity (T axiom for time): 𝐆A → A
        apply_temporal_T_futurebox_rule, apply_temporal_T_futurediamond_rule,
        # Temporal transitivity (4 axiom for time): 𝐆A → 𝐆𝐆A
        apply_temporal_4_futurebox_rule, apply_temporal_4_futurediamond_rule,
    ],
    Function[
        # Deontic seriality (D axiom): □A → ◇A
        apply_D_box_rule, apply_D_diamond_rule,
    ]
)

# ── Frame properties for temporal logics (Table 14.1) ──

"""
    is_transitive_frame(frame::KripkeFrame) -> Bool

Return `true` if the frame's relation is transitive: ∀u∀v∀w((u≺v ∧ v≺w) → u≺w).

Corresponds to the validity of FFp → Fp (Table 14.1, B&D).
"""
function is_transitive_frame(frame::KripkeFrame)
    for u in frame.worlds
        for v in accessible(frame, u)
            for w in accessible(frame, v)
                if !(w in accessible(frame, u))
                    return false
                end
            end
        end
    end
    true
end

"""
    is_linear_frame(frame::KripkeFrame) -> Bool

Return `true` if the frame's relation is linear: ∀w∀v(w≺v ∨ w=v ∨ v≺w).

Corresponds to the validity of (FPp ∨ PFp) → (Pp ∨ p ∨ Fp) (Table 14.1, B&D).
"""
function is_linear_frame(frame::KripkeFrame)
    worlds = collect(frame.worlds)
    for i in eachindex(worlds)
        for j in eachindex(worlds)
            i == j && continue
            w, v = worlds[i], worlds[j]
            if !(v in accessible(frame, w)) && !(w in accessible(frame, v))
                return false
            end
        end
    end
    true
end

"""
    is_dense_frame(frame::KripkeFrame) -> Bool

Return `true` if the frame is dense: ∀w∀v(w≺v → ∃u(w≺u ∧ u≺v)).

Corresponds to the validity of Fp → FFp (Table 14.1, B&D).
"""
function is_dense_frame(frame::KripkeFrame)
    for w in frame.worlds
        for v in accessible(frame, w)
            found = any(u -> (u in accessible(frame, w)) && (v in accessible(frame, u)),
                        frame.worlds)
            found || return false
        end
    end
    true
end

"""
    is_unbounded_past(frame::KripkeFrame) -> Bool

Return `true` if the frame has an unbounded past: ∀w∃v(v≺w).

Corresponds to the validity of Hp → Pp (Table 14.1, B&D).
"""
function is_unbounded_past(frame::KripkeFrame)
    for w in frame.worlds
        has_predecessor = any(v -> w in accessible(frame, v), frame.worlds)
        has_predecessor || return false
    end
    true
end

"""
    is_unbounded_future(frame::KripkeFrame) -> Bool

Return `true` if the frame has an unbounded future: ∀w∃v(w≺v).

Corresponds to the validity of Gp → Fp (Table 14.1, B&D).
"""
function is_unbounded_future(frame::KripkeFrame)
    all(w -> !isempty(accessible(frame, w)), frame.worlds)
end
