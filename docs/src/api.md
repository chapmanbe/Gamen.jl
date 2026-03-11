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

## Completeness and Canonical Models

### Subformulas and Closure

```@docs
subformulas
formula_closure
```

### Derivability and Consistency

```@docs
is_derivable_from
is_consistent
is_complete_consistent
```

### Modal Operators on Sets

```@docs
box_set
diamond_set
box_inverse
diamond_inverse
```

### Lindenbaum's Lemma

```@docs
lindenbaum_extend
```

### Canonical Models

```@docs
CanonicalModel
canonical_model
truth_lemma_holds
determines
```


## Chapter 5: Filtrations and Decidability

### Closure Properties

```@docs
is_closed_under_subformulas
is_modally_closed
subformula_closure
modal_closure
```

### Equivalence Classes

```@docs
world_equivalent
equivalence_classes
equivalence_class
```

### Filtrations

```@docs
Filtration
finest_filtration
coarsest_filtration
symmetric_filtration
transitive_filtration
filtration_lemma_holds
```

### Finite Model Property and Decidability

```@docs
has_finite_model_property
is_decidable_within
```

## Chapter 14: Temporal Logics

### Temporal Formula Types

```@docs
PastDiamond
PastBox
FutureDiamond
FutureBox
Since
Until
TemporalModel
```

### Temporal Frame Properties

```@docs
is_transitive_frame
is_linear_frame
is_dense_frame
is_unbounded_past
is_unbounded_future
```

## Chapter 15: Epistemic Logics

### Epistemic Formula Types

```@docs
Knowledge
Announce
```

### Multi-Agent Models

```@docs
EpistemicFrame
EpistemicModel
agents
restrict_model
```

### Group and Common Knowledge

```@docs
group_knows
common_knowledge
```

### Bisimulation

```@docs
is_bisimulation
bisimilar_worlds
```

### Epistemic Systems

```@docs
EPISTEMIC_K
EPISTEMIC_KT
EPISTEMIC_S4
EPISTEMIC_S5
```

## Chapter 6: Modal Tableaux

### Prefixes and Signed Formulas

```@docs
Prefix
extend
parent_prefix
PrefixedFormula
pf_true
pf_false
```

### Tableau Branches

```@docs
TableauBranch
is_closed
used_prefixes
fresh_prefix
```

### Tableau Construction

```@docs
Tableau
build_tableau
tableau_proves
tableau_consistent
extract_countermodel
```

### Tableau Systems

```@docs
TableauSystem
TABLEAU_K
TABLEAU_KT
TABLEAU_KD
TABLEAU_KB
TABLEAU_K4
TABLEAU_S4
TABLEAU_S5
```
