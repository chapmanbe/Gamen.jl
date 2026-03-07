# Tutorial

This tutorial walks through the basics of Gamen.jl, following Chapter 1 of
[Boxes and Diamonds](https://bd.openlogicproject.org).

## Building Formulas

The language of basic modal logic (Definition 1.1) includes propositional
variables, logical connectives, and the modal operators □ (Box) and
◇ (Diamond).

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

Falsity (⊥) and truth (⊤) are available:

```jldoctest tutorial
julia> Bottom()
⊥

julia> Top()
¬⊥
```

## Creating Kripke Models

A model M = ⟨W, R, V⟩ consists of worlds, an accessibility
relation, and a valuation (Definition 1.6).

Here we build the model from Figure 1.1 in the book:

```jldoctest tutorial
julia> frame = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w1 => :w3]);

julia> model = KripkeModel(frame, [:p => [:w1, :w2], :q => [:w2]]);
```

The valuation follows the book's convention: each atom maps to the set of
worlds where it is true. So V(p) = {w₁, w₂} and V(q) = {w₂}.

## Model Checking

The function [`satisfies`](@ref) implements the satisfaction relation
M, w ⊩ A (Definition 1.7):

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

Note that □q is vacuously true at w₃ because w₃ has no accessible worlds.

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

Proposition 1.8 establishes that □A ↔ ¬◇¬A and ◇A ↔ ¬□¬A. We can verify this:

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

The translation uses a unary predicate P_p for each propositional variable
p, and a binary predicate Q for the accessibility relation:

```jldoctest tutorial
julia> standard_translation(Box(p))
∀y₁ (Q(x, y₁) → P_p(y₁))

julia> standard_translation(Diamond(p))
∃y₁ (Q(x, y₁) ∧ P_p(y₁))

julia> standard_translation(Implies(Box(p), p))
(∀y₁ (Q(x, y₁) → P_p(y₁)) → P_p(x))
```

## Axiomatic Derivations

Chapter 3 introduces Hilbert-style proof systems for modal logic. A
*derivation* is a sequence of formulas where each step is justified as a
tautological instance, an axiom schema instance, or follows by modus ponens
or necessitation.

### Tautologies and Substitution

```jldoctest tutorial
julia> is_tautology(Implies(p, Implies(q, p)))
true

julia> is_tautological_instance(Implies(Box(p), Implies(Diamond(q), Box(p))))
true

julia> substitute(Implies(p, q), Dict(:p => Box(p), :q => Diamond(q)))
(□p → ◇q)
```

### Axiom Schemas and Modal Systems

The system **K** includes the K axiom □(A → B) → (□A → □B) and the Dual
axiom ◇A ↔ ¬□¬A. Additional schemas define stronger systems:

```jldoctest tutorial
julia> is_instance(Implies(Box(Implies(p, q)), Implies(Box(p), Box(q))), SchemaK())
true

julia> is_instance(Implies(Box(p), p), SchemaT())
true

julia> SYSTEM_S5
S5
```

### Building and Checking Proofs

Here is a proof that □A → □(B → A) (Proposition 3.12):

```jldoctest tutorial
julia> proof = Derivation([
           ProofStep(Implies(p, Implies(q, p)), Tautology()),
           ProofStep(Box(Implies(p, Implies(q, p))), Necessitation(1)),
           ProofStep(
               Implies(Box(Implies(p, Implies(q, p))),
                       Implies(Box(p), Box(Implies(q, p)))),
               AxiomInst(SchemaK())),
           ProofStep(
               Implies(Box(p), Box(Implies(q, p))),
               ModusPonens(2, 3)),
       ]);

julia> is_valid_derivation(SYSTEM_K, proof)
true

julia> conclusion(proof)
(□p → □(q → p))
```

### Dual Formulas

The dual of a formula swaps ⊥ ↔ ⊤, ∧ ↔ ∨, and □ ↔ ◇:

```jldoctest tutorial
julia> dual(And(p, q))
(¬p ∨ ¬q)

julia> dual(Box(p))
◇¬p
```

## Completeness and Canonical Models

Chapter 4 proves the *completeness* theorem: every valid formula is
provable. The key construction is the *canonical model*, whose worlds
are the complete Σ-consistent sets of formulas.

### Consistency and Derivability

A set of formulas is Σ-consistent if no contradiction can be derived
from it (Definition 3.39). Derivability from a set Γ ⊢_Σ A means A
follows from finitely many premises in Γ (Definition 3.36):

```jldoctest tutorial
julia> is_consistent(SYSTEM_K, [p, Box(p)])
true

julia> is_consistent(SYSTEM_K, [p, Not(p)])
false

julia> is_consistent(SYSTEM_KT, [Box(p), Not(p)])
false
```

Derivability checks whether a formula follows from premises:

```jldoctest tutorial
julia> is_derivable_from(SYSTEM_K, [p, Implies(p, q)], q; max_worlds=2)
true

julia> is_derivable_from(SYSTEM_K, Formula[], Implies(Box(p), p); max_worlds=2)
false

julia> is_derivable_from(SYSTEM_KT, Formula[], Implies(Box(p), p); max_worlds=2)
true
```

### Subformulas and Closure

The [`subformulas`](@ref) function collects all subformulas, and
[`formula_closure`](@ref) extends a set to include negations:

```jldoctest tutorial
julia> length(subformulas(Box(Implies(p, q))))
4

julia> Box(Implies(p, q)) ∈ subformulas(Box(Implies(p, q)))
true

julia> formula_closure([p])
2-element Vector{Formula}:
 p
 ¬p
```

### Modal Operators on Sets

Definition 4.5 defines □Γ, ◇Γ, □⁻¹Γ, and ◇⁻¹Γ:

```jldoctest tutorial
julia> Γ = Set{Formula}([Box(p), Box(q), Diamond(p)]);

julia> box_inverse(Γ) == Set{Formula}([p, q])
true

julia> diamond_inverse(Γ) == Set{Formula}([p])
true
```

### Building Canonical Models

The canonical model M^Σ for a system Σ over a finite language has as
worlds all complete Σ-consistent sets (Definition 4.11):

```jldoctest tutorial
julia> cm = canonical_model(SYSTEM_K, [p, Box(p)]; max_worlds=3);

julia> length(cm.worlds)
4

julia> truth_lemma_holds(cm)
true
```

The canonical model for **KT** is reflexive, and for **S4** (with enough
modal depth in the language) is reflexive and transitive (Theorem 4.16):

```jldoctest tutorial
julia> cm_kt = canonical_model(SYSTEM_KT, [p, Box(p)]; max_worlds=3);

julia> is_reflexive(cm_kt.model.frame)
true

julia> cm_s4 = canonical_model(SYSTEM_S4, [p, Box(p), Box(Box(p))]; max_worlds=3);

julia> is_reflexive(cm_s4.model.frame) && is_transitive(cm_s4.model.frame)
true
```

### Lindenbaum's Lemma

Lindenbaum's Lemma (Theorem 4.3) guarantees that every consistent set
can be extended to a complete consistent set:

```jldoctest tutorial
julia> lang = formula_closure([p, Box(p)]);

julia> ext = lindenbaum_extend(SYSTEM_K, [Box(p)], lang; max_worlds=3);

julia> Box(p) ∈ ext
true
```
