"""
    satisfies(model::KripkeModel, world::Symbol, formula::Formula) -> Bool

Determine whether `formula` is true at `world` in `model`, written
M, w ⊩ A in the book (Definition 1.7, B&D).
"""
function satisfies end

# 1. A ≡ ⊥: Never M, w ⊩ ⊥.
function satisfies(::KripkeModel, ::Symbol, ::Bottom)
    false
end

# 2. M, w ⊩ p iff w ∈ V(p).
function satisfies(model::KripkeModel, world::Symbol, f::Atom)
    world in get(model.valuation, f.name, Set{Symbol}())
end

# 3. A ≡ ¬B: M, w ⊩ A iff M, w ⊮ B.
function satisfies(model::KripkeModel, world::Symbol, f::Not)
    !satisfies(model, world, f.operand)
end

# 4. A ≡ (B ∧ C): M, w ⊩ A iff M, w ⊩ B and M, w ⊩ C.
function satisfies(model::KripkeModel, world::Symbol, f::And)
    satisfies(model, world, f.left) && satisfies(model, world, f.right)
end

# 5. A ≡ (B ∨ C): M, w ⊩ A iff M, w ⊩ B or M, w ⊩ C (or both).
function satisfies(model::KripkeModel, world::Symbol, f::Or)
    satisfies(model, world, f.left) || satisfies(model, world, f.right)
end

# 6. A ≡ (B → C): M, w ⊩ A iff M, w ⊮ B or M, w ⊩ C.
function satisfies(model::KripkeModel, world::Symbol, f::Implies)
    !satisfies(model, world, f.antecedent) || satisfies(model, world, f.consequent)
end

# Iff: A ≡ (B ↔ C): abbreviates (B → C) ∧ (C → B).
function satisfies(model::KripkeModel, world::Symbol, f::Iff)
    l = satisfies(model, world, f.left)
    r = satisfies(model, world, f.right)
    l == r
end

# 7. A ≡ □B: M, w ⊩ A iff M, w' ⊩ B for all w' ∈ W with Rww'.
function satisfies(model::KripkeModel, world::Symbol, f::Box)
    all(w -> satisfies(model, w, f.operand), accessible(model.frame, world))
end

# 8. A ≡ ◇B: M, w ⊩ A iff M, w' ⊩ B for at least one w' ∈ W with Rww'.
function satisfies(model::KripkeModel, world::Symbol, f::Diamond)
    any(w -> satisfies(model, w, f.operand), accessible(model.frame, world))
end

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
