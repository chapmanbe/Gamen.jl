# API Reference

## Formulas

```@docs
Formula
Bottom
Atom
Not
And
Or
Implies
Iff
Box
Diamond
□
◇
Top
is_modal_free
atoms
```

## Kripke Structures

```@docs
KripkeFrame
KripkeModel
accessible
```

## Semantics

```@docs
satisfies
is_true_in
is_valid
entails
```

## Frame Properties

```@docs
is_reflexive
is_symmetric
is_transitive
is_serial
is_euclidean
is_partially_functional
is_functional
is_weakly_dense
is_weakly_connected
is_weakly_directed
is_equivalence_relation
is_universal
is_valid_on_frame
```

## Standard Translation

```@docs
FOFormula
FOBottom
FOTop
FOVar
FOPredicate
FONot
FOAnd
FOOr
FOImplies
FOIff
FOForall
FOExists
standard_translation
```

## Axiomatic Derivations

### Substitution and Tautologies

```@docs
substitute
is_tautology
is_tautological_instance
```

### Axiom Schemas

```@docs
AxiomSchema
SchemaK
SchemaDual
SchemaT
SchemaD
SchemaB
Schema4
Schema5
is_instance
```

### Modal Systems

```@docs
ModalSystem
SYSTEM_K
SYSTEM_KT
SYSTEM_KD
SYSTEM_KB
SYSTEM_K4
SYSTEM_K5
SYSTEM_S4
SYSTEM_S5
```

### Derivations

```@docs
Justification
Tautology
AxiomInst
ModusPonens
Necessitation
ProofStep
Derivation
conclusion
is_valid_derivation
```

### Dual Formulas

```@docs
dual
```
