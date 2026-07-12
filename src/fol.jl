# First-order logic formulas — used as the target language for the standard translation.

"""
    FOFormula

Abstract base type for first-order logic formulas.
"""
abstract type FOFormula end

"""
    FOBottom <: FOFormula

First-order falsity ⊥.
"""
struct FOBottom <: FOFormula end

"""
    FOTop <: FOFormula

First-order truth ⊤.
"""
struct FOTop <: FOFormula end

"""
    FOVar

A first-order variable, identified by a symbol (e.g., :x, :y).
"""
struct FOVar
    name::Symbol
end

"""
    FOPredicate <: FOFormula

An applied predicate symbol. Unary predicates `Pᵢ(x)` represent propositional
variables; the binary predicate `Q(x, y)` represents the accessibility relation.
"""
struct FOPredicate <: FOFormula
    name::Symbol
    args::Vector{FOVar}
end

"""
    FONot <: FOFormula

First-order negation.
"""
struct FONot <: FOFormula
    operand::FOFormula
end

"""
    FOAnd <: FOFormula

First-order conjunction.
"""
struct FOAnd <: FOFormula
    left::FOFormula
    right::FOFormula
end

"""
    FOOr <: FOFormula

First-order disjunction.
"""
struct FOOr <: FOFormula
    left::FOFormula
    right::FOFormula
end

"""
    FOImplies <: FOFormula

First-order material conditional.
"""
struct FOImplies <: FOFormula
    antecedent::FOFormula
    consequent::FOFormula
end

"""
    FOIff <: FOFormula

First-order biconditional.
"""
struct FOIff <: FOFormula
    left::FOFormula
    right::FOFormula
end

"""
    FOForall <: FOFormula

Universal quantification: ∀v. φ
"""
struct FOForall <: FOFormula
    var::FOVar
    body::FOFormula
end

"""
    FOExists <: FOFormula

Existential quantification: ∃v. φ

# Structural equality

All `FOFormula` subtypes (and `FOVar`) compare with structural `==` and hash
accordingly: two translations of the same modal formula are `==` and can be
deduplicated in `Set`s and `Dict`s.
"""
struct FOExists <: FOFormula
    var::FOVar
    body::FOFormula
end

# Structural equality and hashing (issue #10 §M5): without these,
# `standard_translation(φ) == standard_translation(φ)` was false whenever the
# translation contained a Vector field (FOPredicate args), because the
# fallback `==` is object identity for such fields.

function Base.:(==)(a::FOFormula, b::FOFormula)
    typeof(a) === typeof(b) || return false
    T = typeof(a)
    all(i -> getfield(a, i) == getfield(b, i), 1:fieldcount(T))
end

function Base.hash(f::FOFormula, h::UInt)
    h = hash(typeof(f), h)
    for i in 1:fieldcount(typeof(f))
        h = hash(getfield(f, i), h)
    end
    h
end

# Pretty printing

Base.show(io::IO, ::FOBottom) = print(io, "⊥")
Base.show(io::IO, ::FOTop) = print(io, "⊤")
Base.show(io::IO, v::FOVar) = print(io, v.name)

function Base.show(io::IO, p::FOPredicate)
    print(io, p.name, "(")
    join(io, p.args, ", ")
    print(io, ")")
end

Base.show(io::IO, f::FONot) = print(io, "¬", f.operand)
Base.show(io::IO, f::FOAnd) = print(io, "(", f.left, " ∧ ", f.right, ")")
Base.show(io::IO, f::FOOr) = print(io, "(", f.left, " ∨ ", f.right, ")")
Base.show(io::IO, f::FOImplies) = print(io, "(", f.antecedent, " → ", f.consequent, ")")
Base.show(io::IO, f::FOIff) = print(io, "(", f.left, " ↔ ", f.right, ")")
Base.show(io::IO, f::FOForall) = print(io, "∀", f.var, " ", f.body)
Base.show(io::IO, f::FOExists) = print(io, "∃", f.var, " ", f.body)

# Standard translation (Definition frd.15, B&D)

# Fresh variable generator: produces y₁, y₂, y₃, …, skipping any name in
# `avoid` (the caller's free variable — issue #10 §M4: without this,
# standard_translation(Box(p), FOVar(:y₁)) captured the free y₁ under ∀y₁)
mutable struct VarCounter
    count::Int
    avoid::Set{Symbol}
end

VarCounter(count::Int) = VarCounter(count, Set{Symbol}())

function fresh_var!(counter::VarCounter)
    while true
        counter.count += 1
        name = Symbol("y", _subscript_digits(counter.count))
        name in counter.avoid || return FOVar(name)
    end
end

function _subscript_digits(n::Int)
    subs = ('₀', '₁', '₂', '₃', '₄', '₅', '₆', '₇', '₈', '₉')
    n == 0 && return string(subs[1])
    digits = Char[]
    while n > 0
        push!(digits, subs[n % 10 + 1])
        n ÷= 10
    end
    return String(reverse(digits))
end

"""
    standard_translation(φ::Formula, [x::FOVar]) -> FOFormula

Compute the *standard translation* STₓ(φ) of a modal formula φ into
first-order logic (Definition frd.15, B&D).

The translation maps:
- Propositional variable `p` to unary predicate `P_p(x)`
- `□ψ` to `∀y (Q(x, y) → STᵧ(ψ))`
- `◇ψ` to `∃y (Q(x, y) ∧ STᵧ(ψ))`

The binary predicate `Q` represents the accessibility relation.

# Example
```jldoctest
julia> using Gamen

julia> p = Atom(:p);

julia> standard_translation(□(Implies(p, p)))
∀y₁ (Q(x, y₁) → (P_p(y₁) → P_p(y₁)))

julia> standard_translation(◇(p))
∃y₁ (Q(x, y₁) ∧ P_p(y₁))
```
"""
function standard_translation(φ::Formula, x::FOVar=FOVar(:x))
    standard_translation(φ, x, VarCounter(0, Set([x.name])))
end

function standard_translation(::Bottom, _::FOVar, _::VarCounter)
    FOBottom()
end

function standard_translation(f::Not, x::FOVar, counter::VarCounter)
    # Top() = Not(Bottom())
    if f.operand isa Bottom
        return FOTop()
    end
    FONot(standard_translation(f.operand, x, counter))
end

function standard_translation(f::Atom, x::FOVar, _::VarCounter)
    FOPredicate(Symbol("P_", f.name), [x])
end

function standard_translation(f::And, x::FOVar, counter::VarCounter)
    FOAnd(standard_translation(f.left, x, counter),
          standard_translation(f.right, x, counter))
end

function standard_translation(f::Or, x::FOVar, counter::VarCounter)
    FOOr(standard_translation(f.left, x, counter),
         standard_translation(f.right, x, counter))
end

function standard_translation(f::Implies, x::FOVar, counter::VarCounter)
    FOImplies(standard_translation(f.antecedent, x, counter),
              standard_translation(f.consequent, x, counter))
end

function standard_translation(f::Iff, x::FOVar, counter::VarCounter)
    FOIff(standard_translation(f.left, x, counter),
          standard_translation(f.right, x, counter))
end

function standard_translation(f::Box, x::FOVar, counter::VarCounter)
    y = fresh_var!(counter)
    FOForall(y, FOImplies(
        FOPredicate(:Q, [x, y]),
        standard_translation(f.operand, y, counter)))
end

function standard_translation(f::Diamond, x::FOVar, counter::VarCounter)
    y = fresh_var!(counter)
    FOExists(y, FOAnd(
        FOPredicate(:Q, [x, y]),
        standard_translation(f.operand, y, counter)))
end
