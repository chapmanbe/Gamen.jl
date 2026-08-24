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

# Structural equality/hash come from the generic traversal protocol
# (src/traversal.jl) — no per-type methods needed.

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
        t in _successors(model.frame, t_prime) && satisfies(model, t_prime, f.operand)
    end
end

# HA: M,t ⊩ HA iff M,t' ⊩ A for every t' with t' ≺ t
function satisfies(model::TemporalModel, t::Symbol, f::PastBox)
    t in model.frame.worlds || throw(ArgumentError("World :$t is not in model"))
    all(model.frame.worlds) do t_prime
        !(t in _successors(model.frame, t_prime)) || satisfies(model, t_prime, f.operand)
    end
end

# FA: M,t ⊩ FA iff M,t' ⊩ A for some t' with t ≺ t'
function satisfies(model::TemporalModel, t::Symbol, f::FutureDiamond)
    any(t_prime -> satisfies(model, t_prime, f.operand), _successors(model.frame, t))
end

# GA: M,t ⊩ GA iff M,t' ⊩ A for every t' with t ≺ t'
function satisfies(model::TemporalModel, t::Symbol, f::FutureBox)
    t in model.frame.worlds || throw(ArgumentError("World :$t is not in model"))
    all(t_prime -> satisfies(model, t_prime, f.operand), _successors(model.frame, t))
end

# SBC: M,t ⊩ SBC iff ∃t' ≺ t: M,t' ⊩ B and ∀s with t' ≺ s ≺ t: M,s ⊩ C
function satisfies(model::TemporalModel, t::Symbol, f::Since)
    for t_prime in model.frame.worlds
        # t_prime must precede t
        t in _successors(model.frame, t_prime) || continue
        # M,t' ⊩ B
        satisfies(model, t_prime, f.left) || continue
        # For all s with t' ≺ s ≺ t. Endpoints are NOT exempted: B&D leaves ≺
        # free to be reflexive or not, so s = t/t' is in range exactly when
        # the frame makes it so (issue #10).
        all_between = all(model.frame.worlds) do s
            between = (s in _successors(model.frame, t_prime)) &&
                       (t in _successors(model.frame, s))
            !between || satisfies(model, s, f.right)
        end
        all_between && return true
    end
    false
end

# UBC: M,t ⊩ UBC iff ∃t': t ≺ t' and M,t' ⊩ B and ∀s with t ≺ s ≺ t': M,s ⊩ C
function satisfies(model::TemporalModel, t::Symbol, f::Until)
    for t_prime in _successors(model.frame, t)
        # M,t' ⊩ B
        satisfies(model, t_prime, f.left) || continue
        # For all s with t ≺ s ≺ t'. Endpoints are NOT exempted: B&D leaves ≺
        # free to be reflexive or not, so s = t/t' is in range exactly when
        # the frame makes it so (issue #10).
        all_between = all(model.frame.worlds) do s
            between = (s in _successors(model.frame, t)) &&
                       (t_prime in _successors(model.frame, s))
            !between || satisfies(model, s, f.right)
        end
        all_between && return true
    end
    false
end

# ── Temporal operator pair ──
#
# FutureBox (𝐆) and FutureDiamond (𝐅) use the same prefix tree as Box/Diamond —
# in Phase 1, temporal and deontic accessibility share a single relation.
# The tableau rules for 𝐆/𝐅 are the generic operator-pair rules from
# tableaux.jl (Table 6.2–6.3, B&D) instantiated at TEMPORAL_PAIR — the eight
# verbatim rule copies this file used to carry are gone (review §A2).

"""
    TEMPORAL_PAIR

The temporal `OperatorPair`: 𝐆 (`FutureBox`) as the universal operator, 𝐅
(`FutureDiamond`) as its existential dual. Declared by `TABLEAU_KDt` so the
generic □/◇ tableau rules also serve the temporal operators.
"""
const TEMPORAL_PAIR = OperatorPair(FutureBox, FutureDiamond)

# ── Combined deontic-temporal tableau system ──

"""
    TABLEAU_KDt

Tableau system for combined deontic-temporal logic. Deontic operators (□/◇)
have serial frames (D axiom); temporal operators (𝐆/𝐅) have reflexive and
transitive frames.

In Phase 1, deontic and temporal accessibility share a single relation.
Multi-relational prefixes (distinguishing R_d from R_t) are deferred to Phase 2.

⚠️ **Unsourced rules**: B&D presents no tableau rules for temporal logic. The
𝐆/𝐅 rules here are the □/◇ rules instantiated at `TEMPORAL_PAIR` by analogy
(treating ≺ as a future-facing accessibility relation) and have no published
source yet. No rules exist for 𝐇, 𝐏, `Since`, or `Until` — formulas
containing them throw `ArgumentError` rather than being silently treated as
atoms. Extending the temporal tableau is quarantined until a published rule
set is adopted (issue #10).

Hand-assembled rather than derived from a `ModalSystem` — B&D provides no
temporal axiom schema objects, so `.schemas` is empty and both the rule
bindings and `uses_blocking` are declared explicitly.
"""
const TABLEAU_KDt = TableauSystem(:KDt,
    Function[
        # Temporal reflexivity (T axiom for time): 𝐆A → A
        BoundRule(apply_T_box_rule, TEMPORAL_PAIR),
        BoundRule(apply_T_diamond_rule, TEMPORAL_PAIR),
        # Temporal transitivity (4 axiom for time): 𝐆A → 𝐆𝐆A
        BoundRule(apply_4_box_rule, TEMPORAL_PAIR),
        BoundRule(apply_4_diamond_rule, TEMPORAL_PAIR),
    ],
    Function[
        # Deontic seriality (D axiom): □A → ◇A
        BoundRule(apply_D_box_rule, BASE_PAIR),
        BoundRule(apply_D_diamond_rule, BASE_PAIR),
    ];
    operator_pairs=[BASE_PAIR, TEMPORAL_PAIR],
    uses_blocking=true  # temporal transitivity (𝐆/𝐅) can re-inject unstripped
                        # boxed formulas into descendant worlds indefinitely
)

# ── Frame properties for temporal logics (Table 14.1) ──

"""
    is_transitive_frame(frame::KripkeFrame) -> Bool

Return `true` if the frame's relation is transitive: ∀u∀v∀w((u≺v ∧ v≺w) → u≺w).

Corresponds to the validity of FFp → Fp (Table 14.1, B&D). Alias for the
Chapter 2 predicate [`is_transitive`](@ref) — the temporal reading of the
same frame condition, not a separate implementation.
"""
const is_transitive_frame = is_transitive

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
            if !(v in _successors(frame, w)) && !(w in _successors(frame, v))
                return false
            end
        end
    end
    true
end

"""
    is_dense_frame(frame::KripkeFrame) -> Bool

Return `true` if the frame is dense: ∀w∀v(w≺v → ∃u(w≺u ∧ u≺v)).

Corresponds to the validity of Fp → FFp (Table 14.1, B&D). Alias for the
Chapter 2 predicate [`is_weakly_dense`](@ref) — the temporal reading of the
same frame condition, not a separate implementation.
"""
const is_dense_frame = is_weakly_dense

"""
    is_unbounded_past(frame::KripkeFrame) -> Bool

Return `true` if the frame has an unbounded past: ∀w∃v(v≺w).

Corresponds to the validity of Hp → Pp (Table 14.1, B&D).
"""
function is_unbounded_past(frame::KripkeFrame)
    for w in frame.worlds
        has_predecessor = any(v -> w in _successors(frame, v), frame.worlds)
        has_predecessor || return false
    end
    true
end

"""
    is_unbounded_future(frame::KripkeFrame) -> Bool

Return `true` if the frame has an unbounded future: ∀w∃v(w≺v).

Corresponds to the validity of Gp → Fp (Table 14.1, B&D). Alias for the
Chapter 2 predicate [`is_serial`](@ref) — the temporal reading of the same
frame condition, not a separate implementation.
"""
const is_unbounded_future = is_serial
