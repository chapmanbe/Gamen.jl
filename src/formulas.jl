"""
    Formula

Abstract base type for all modal logic formulas (Definition 1.2, B&D).
"""
abstract type Formula end

"""
    Bottom <: Formula

The propositional constant for falsity ⊥ (Definition 1.1, item 1).
"""
struct Bottom <: Formula end

"""
    Atom <: Formula

A propositional variable identified by a symbol (Definition 1.1, item 2).
Supports both named atoms like `Atom(:p)` and indexed atoms like `Atom(0)`.
"""
struct Atom <: Formula
    name::Symbol
end

Atom(i::Integer) = Atom(Symbol("p", i))

"""
    Not <: Formula

Negation of a formula (Definition 1.2, item 3).
"""
struct Not <: Formula
    operand::Formula
end

"""
    And <: Formula

Conjunction of two formulas (Definition 1.2, item 4).
"""
struct And <: Formula
    left::Formula
    right::Formula
end

"""
    Or <: Formula

Disjunction of two formulas (Definition 1.2, item 5).
"""
struct Or <: Formula
    left::Formula
    right::Formula
end

"""
    Implies <: Formula

Material conditional (Definition 1.2, item 6).
"""
struct Implies <: Formula
    antecedent::Formula
    consequent::Formula
end

"""
    Iff <: Formula

Biconditional. A ↔ B abbreviates (A → B) ∧ (B → A) (Definition 1.3, item 2).
Represented as its own type for convenience.
"""
struct Iff <: Formula
    left::Formula
    right::Formula
end

"""
    Box <: Formula

The necessity modal operator □ (Definition 1.2, item 7).
"""
struct Box <: Formula
    operand::Formula
end

"""
    Diamond <: Formula

The possibility modal operator ◇ (Definition 1.2, item 8).
"""
struct Diamond <: Formula
    operand::Formula
end

# Abbreviations (Definition 1.3)

"""
    Top()

⊤ abbreviates ¬⊥ (Definition 1.3, item 1).
"""
Top() = Not(Bottom())

# Pretty printing
Base.show(io::IO, ::Bottom) = print(io, "⊥")
Base.show(io::IO, f::Atom) = print(io, f.name)
Base.show(io::IO, f::Not) = print(io, "¬", f.operand)
Base.show(io::IO, f::And) = print(io, "(", f.left, " ∧ ", f.right, ")")
Base.show(io::IO, f::Or) = print(io, "(", f.left, " ∨ ", f.right, ")")
Base.show(io::IO, f::Implies) = print(io, "(", f.antecedent, " → ", f.consequent, ")")
Base.show(io::IO, f::Iff) = print(io, "(", f.left, " ↔ ", f.right, ")")
Base.show(io::IO, f::Box) = print(io, "□", f.operand)
Base.show(io::IO, f::Diamond) = print(io, "◇", f.operand)

"""
    is_modal_free(f::Formula) -> Bool

Return `true` if the formula contains no □ or ◇ operators.
"""
is_modal_free(::Bottom) = true
is_modal_free(::Atom) = true
is_modal_free(f::Not) = is_modal_free(f.operand)
is_modal_free(f::And) = is_modal_free(f.left) && is_modal_free(f.right)
is_modal_free(f::Or) = is_modal_free(f.left) && is_modal_free(f.right)
is_modal_free(f::Implies) = is_modal_free(f.antecedent) && is_modal_free(f.consequent)
is_modal_free(f::Iff) = is_modal_free(f.left) && is_modal_free(f.right)
is_modal_free(::Box) = false
is_modal_free(::Diamond) = false
