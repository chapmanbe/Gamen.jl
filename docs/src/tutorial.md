# Tutorial

This tutorial walks through the basics of Gamen.jl, following Chapter 1 of
[Boxes and Diamonds](https://bd.openlogicproject.org).

## Building Formulas

The language of basic modal logic (Definition 1.1) includes propositional
variables, logical connectives, and the modal operators ``\square`` (Box) and
``\diamond`` (Diamond).

```jldoctest tutorial
julia> using Gamen

julia> p = Atom(:p); q = Atom(:q);

julia> And(p, q)
(p ∧ q)

julia> Implies(p, Diamond(q))
(p → ◇q)
```

You can also use indexed propositional variables:

```jldoctest tutorial
julia> Atom(0)
p0

julia> Atom(1)
p1
```

### Special Constants

Falsity (``\bot``) and truth (``\top``) are available:

```jldoctest tutorial
julia> Bottom()
⊥

julia> Top()
¬⊥
```

## Creating Kripke Models

A model ``M = \langle W, R, V \rangle`` consists of worlds, an accessibility
relation, and a valuation (Definition 1.6).

Here we build the model from Figure 1.1 in the book:

```jldoctest tutorial
julia> frame = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w1 => :w3]);

julia> model = KripkeModel(frame, [:p => [:w1, :w2], :q => [:w2]]);
```

The valuation follows the book's convention: each atom maps to the set of
worlds where it is true. So ``V(p) = \{w_1, w_2\}`` and ``V(q) = \{w_2\}``.

## Model Checking

The function [`satisfies`](@ref) implements the satisfaction relation
``M, w \Vdash A`` (Definition 1.7):

```jldoctest tutorial
julia> satisfies(model, :w1, p)
true

julia> satisfies(model, :w1, q)
false

julia> satisfies(model, :w1, Diamond(q))
true
```

The Box operator is true at a world when the operand holds at *all* accessible
worlds:

```jldoctest tutorial
julia> satisfies(model, :w1, Box(q))
false

julia> satisfies(model, :w3, Box(q))
true
```

Note that ``\square q`` is vacuously true at ``w_3`` because ``w_3`` has no
accessible worlds.

## Truth in a Model

A formula is true in a model when it holds at every world (Definition 1.9):

```jldoctest tutorial
julia> is_true_in(model, Top())
true

julia> is_true_in(model, p)
false
```

## Entailment

A set of premises entails a conclusion when, at every world where all premises
hold, the conclusion also holds (Definition 1.23):

```jldoctest tutorial
julia> frame2 = KripkeFrame([:w1, :w2], [:w1 => :w2]);

julia> model2 = KripkeModel(frame2, [:p => [:w1, :w2], :q => [:w1, :w2]]);

julia> entails(model2, p, Or(p, q))
true
```

## The Duality of □ and ◇

Proposition 1.8 establishes that ``\square A \leftrightarrow \lnot\diamond\lnot A``
and ``\diamond A \leftrightarrow \lnot\square\lnot A``. We can verify this:

```jldoctest tutorial
julia> w = :w1;

julia> satisfies(model, w, Box(p)) == satisfies(model, w, Not(Diamond(Not(p))))
true

julia> satisfies(model, w, Diamond(p)) == satisfies(model, w, Not(Box(Not(p))))
true
```

## Standard Translation

The *standard translation* (Definition frd.15) maps modal formulas into
first-order logic, making the correspondence between modal and first-order
reasoning explicit.

The translation uses a unary predicate ``P_p`` for each propositional variable
``p``, and a binary predicate ``Q`` for the accessibility relation:

```jldoctest tutorial
julia> standard_translation(Box(p))
∀y₁ (Q(x, y₁) → P_p(y₁))

julia> standard_translation(Diamond(p))
∃y₁ (Q(x, y₁) ∧ P_p(y₁))

julia> standard_translation(Implies(Box(p), p))
(∀y₁ (Q(x, y₁) → P_p(y₁)) → P_p(x))
```
