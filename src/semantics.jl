"""
    satisfies(model, world::Symbol, formula::Formula) -> Bool

Determine whether `formula` is true at `world` in `model`, written
M, w ⊩ A in the book (Definition 1.7, B&D).

The propositional clauses are shared by every model type that has a
`frame.worlds` set and a `valuation` (currently `KripkeModel` and
`EpistemicModel`) — logic variants are configurations of this base system,
not reimplementations. Modal operators plug in an accessibility relation
via [`successor_worlds`](@ref).
"""
function satisfies end

# 1. A ≡ ⊥: Never M, w ⊩ ⊥.
function satisfies(model, world::Symbol, ::Bottom)
    world in model.frame.worlds || throw(ArgumentError("World :$world is not in model"))
    false
end

# 2. M, w ⊩ p iff w ∈ V(p).
function satisfies(model, world::Symbol, f::Atom)
    world in model.frame.worlds || throw(ArgumentError("World :$world is not in model"))
    world in get(model.valuation, f, Set{Symbol}())
end

# 3. A ≡ ¬B: M, w ⊩ A iff M, w ⊮ B.
function satisfies(model, world::Symbol, f::Not)
    !satisfies(model, world, f.operand)
end

# 4. A ≡ (B ∧ C): M, w ⊩ A iff M, w ⊩ B and M, w ⊩ C.
function satisfies(model, world::Symbol, f::And)
    satisfies(model, world, f.left) && satisfies(model, world, f.right)
end

# 5. A ≡ (B ∨ C): M, w ⊩ A iff M, w ⊩ B or M, w ⊩ C (or both).
function satisfies(model, world::Symbol, f::Or)
    satisfies(model, world, f.left) || satisfies(model, world, f.right)
end

# 6. A ≡ (B → C): M, w ⊩ A iff M, w ⊮ B or M, w ⊩ C.
function satisfies(model, world::Symbol, f::Implies)
    !satisfies(model, world, f.antecedent) || satisfies(model, world, f.consequent)
end

# Iff: A ≡ (B ↔ C): abbreviates (B → C) ∧ (C → B).
function satisfies(model, world::Symbol, f::Iff)
    l = satisfies(model, world, f.left)
    r = satisfies(model, world, f.right)
    l == r
end

# ── Pluggable accessibility for □/◇-shaped operators ──

"""
    successor_worlds(model, world::Symbol, f::Formula)

Accessibility hook for modal operators: return the worlds the operator `f`
quantifies over at `world`. `Box`/`Diamond` on a `KripkeModel` use the
frame's relation; `Knowledge` on an `EpistemicModel` uses the agent's
relation. Adding a new □/◇-shaped operator to a model type means defining a
`successor_worlds` method and forwarding `satisfies` to
`_universal_modal_satisfies` / `_existential_modal_satisfies` — the boolean
clauses come for free.

Callers must not mutate the returned collection.
"""
function successor_worlds(model, world::Symbol, f::Formula)
    throw(ArgumentError("no accessibility relation is defined for a " *
                        "$(nameof(typeof(f))) operator on a $(nameof(typeof(model)))"))
end

successor_worlds(model::KripkeModel, world::Symbol, ::Union{Box,Diamond}) =
    _successors(model.frame, world)

function _universal_modal_satisfies(model, world::Symbol, f::Formula)
    world in model.frame.worlds || throw(ArgumentError("World :$world is not in model"))
    all(w -> satisfies(model, w, f.operand), successor_worlds(model, world, f))
end

function _existential_modal_satisfies(model, world::Symbol, f::Formula)
    world in model.frame.worlds || throw(ArgumentError("World :$world is not in model"))
    any(w -> satisfies(model, w, f.operand), successor_worlds(model, world, f))
end

# 7. A ≡ □B: M, w ⊩ A iff M, w' ⊩ B for all w' ∈ W with Rww'.
satisfies(model, world::Symbol, f::Box) = _universal_modal_satisfies(model, world, f)

# 8. A ≡ ◇B: M, w ⊩ A iff M, w' ⊩ B for at least one w' ∈ W with Rww'.
satisfies(model, world::Symbol, f::Diamond) = _existential_modal_satisfies(model, world, f)

"""
    is_true_in(model::KripkeModel, formula::Formula) -> Bool

A formula A is *true in a model* M, written M ⊩ A, if and only if
M, w ⊩ A for every w ∈ W (Definition 1.9, B&D).
"""
function is_true_in(model::KripkeModel, formula::Formula)
    all(w -> satisfies(model, w, formula), model.frame.worlds)
end

"""
    is_valid(formula::Formula, models) -> Bool

A formula A is *valid* in a class of models C if it is true in every model
in C (Definition 1.11, B&D). Pass any iterable collection of models.
"""
function is_valid(formula::Formula, models)
    all(m -> is_true_in(m, formula), models)
end

"""
    is_valid(formula::Formula, model::KripkeModel) -> Bool

Convenience method for a single model: validity in the singleton class {M}
is truth in M (Definition 1.9, B&D). Mirrors the single-premise convenience
overload of `entails`.
"""
function is_valid(formula::Formula, model::KripkeModel)
    is_true_in(model, formula)
end

"""
    entails(model::KripkeModel, premises, conclusion::Formula) -> Bool

A set of formulas Γ *entails* A in model M if for every world w ∈ W,
if M, w ⊩ B for every B ∈ Γ, then M, w ⊩ A (Definition 1.23, B&D).

If `premises` is a single formula, it is treated as a singleton set.
"""
function entails(model::KripkeModel, premises, conclusion::Formula)
    for w in model.frame.worlds
        if all(p -> satisfies(model, w, p), premises)
            if !satisfies(model, w, conclusion)
                return false
            end
        end
    end
    true
end

function entails(model::KripkeModel, premise::Formula, conclusion::Formula)
    entails(model, [premise], conclusion)
end
