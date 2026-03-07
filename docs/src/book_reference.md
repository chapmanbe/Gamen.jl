# Book Reference

This page maps definitions and propositions from
[Boxes and Diamonds](https://bd.openlogicproject.org) (B&D) by Richard Zach
to their implementations in Gamen.jl.

## Chapter 1: Syntax and Semantics

| B&D Reference | Description | Gamen.jl |
|:---|:---|:---|
| Definition 1.1 | Language of modal logic | [`Bottom`](@ref), [`Atom`](@ref), [`Box`](@ref), [`Diamond`](@ref) |
| Definition 1.2 | Formulas (inductive) | [`Formula`](@ref) type hierarchy |
| Definition 1.3 | Abbreviations (⊤, ↔) | [`Top`](@ref), [`Iff`](@ref) |
| Definition 1.6 | Model ``M = \langle W,R,V \rangle`` | [`KripkeFrame`](@ref), [`KripkeModel`](@ref) |
| Definition 1.7 | Truth at a world | [`satisfies`](@ref) |
| Definition 1.9 | Truth in a model | [`is_true_in`](@ref) |
| Definition 1.11 | Validity in a class | [`is_valid`](@ref) |
| Definition 1.23 | Entailment | [`entails`](@ref) |
| Proposition 1.8 | □A ↔ ¬◇¬A duality | Verified in tests |

## Chapter 2: Frame Definability

| B&D Reference | Description | Gamen.jl |
|:---|:---|:---|
| Definition frd.3 | Frame ``\mathfrak{F} = \langle W, R \rangle`` | [`KripkeFrame`](@ref) |
| Definition frd.4 | Validity on a frame | [`is_valid_on_frame`](@ref) |
| Definition frd.5 | Frame definability | Verified in tests (Corollary frd.8) |
| Table frd.1 | 5 core frame properties | [`is_serial`](@ref), [`is_reflexive`](@ref), [`is_symmetric`](@ref), [`is_transitive`](@ref), [`is_euclidean`](@ref) |
| Table frd.2 | 5 additional frame properties | [`is_partially_functional`](@ref), [`is_functional`](@ref), [`is_weakly_dense`](@ref), [`is_weakly_connected`](@ref), [`is_weakly_directed`](@ref) |
| Theorem frd.1 | Property → schema valid (soundness) | Verified in tests |
| Theorem frd.6 | Schema valid → property (definability) | Verified in tests |
| Corollary frd.8 | Full correspondence for D, T, B, 4, 5 | Verified in tests |
| Proposition frd.9 | Relationships between properties | Verified in tests |
| Definition frd.11 | Equivalence relation, universal | [`is_equivalence_relation`](@ref), [`is_universal`](@ref) |
| Proposition frd.12 | Equivalent characterizations of equivalence relations | Verified in tests |
| Proposition frd.14 | S5 = logic of equivalence/universal frames | Verified in tests |
| Definition frd.15 | Standard translation STₓ(φ) | [`standard_translation`](@ref) |
| Proposition frd.16 | Agreement of satisfaction and ST | Verified in tests |

## Part IV: Applied Modal Logic

### Chapter 14: Temporal Logics

*Coming soon.*

### Chapter 15: Epistemic Logics

*Coming soon.*
