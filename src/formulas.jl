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

Base.isless(a::Atom, b::Atom) = isless(a.name, b.name)

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

# Unicode aliases for modal operators
"""
    □(operand::Formula)

Unicode alias for [`Box`](@ref). Type `\\square<tab>` in the Julia REPL.
"""
const □ = Box

"""
    ◇(operand::Formula)

Unicode alias for [`Diamond`](@ref). Type `\\diamond<tab>` in the Julia REPL.
"""
const ◇ = Diamond

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

# Structural equality — needed for axiom schema matching (Chapter 3)
Base.:(==)(::Formula, ::Formula) = false   # different types are never equal
Base.:(==)(::Bottom, ::Bottom) = true
Base.:(==)(a::Atom, b::Atom) = a.name == b.name
Base.:(==)(a::Not, b::Not) = a.operand == b.operand
Base.:(==)(a::And, b::And) = a.left == b.left && a.right == b.right
Base.:(==)(a::Or, b::Or) = a.left == b.left && a.right == b.right
Base.:(==)(a::Implies, b::Implies) = a.antecedent == b.antecedent && a.consequent == b.consequent
Base.:(==)(a::Iff, b::Iff) = a.left == b.left && a.right == b.right
Base.:(==)(a::Box, b::Box) = a.operand == b.operand
Base.:(==)(a::Diamond, b::Diamond) = a.operand == b.operand

Base.hash(::Bottom, h::UInt) = hash(:Bottom, h)
Base.hash(f::Atom, h::UInt) = hash((:Atom, f.name), h)
Base.hash(f::Not, h::UInt) = hash((:Not, f.operand), h)
Base.hash(f::And, h::UInt) = hash((:And, f.left, f.right), h)
Base.hash(f::Or, h::UInt) = hash((:Or, f.left, f.right), h)
Base.hash(f::Implies, h::UInt) = hash((:Implies, f.antecedent, f.consequent), h)
Base.hash(f::Iff, h::UInt) = hash((:Iff, f.left, f.right), h)
Base.hash(f::Box, h::UInt) = hash((:Box, f.operand), h)
Base.hash(f::Diamond, h::UInt) = hash((:Diamond, f.operand), h)
