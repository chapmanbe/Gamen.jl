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
| Definition 2.1 | Validity on a frame | [`is_valid_on_frame`](@ref) |
| Definition 2.3 | Frame properties | [`is_reflexive`](@ref), [`is_symmetric`](@ref), [`is_transitive`](@ref), [`is_serial`](@ref), [`is_euclidean`](@ref) |
| Proposition 1.19 | Schema K valid on all frames | Verified in tests |
| Proposition 2.5 | Schema T ↔ reflexivity | Verified in tests |
| Proposition 2.7 | Schema D ↔ seriality | Verified in tests |
| Proposition 2.9 | Schema B ↔ symmetry | Verified in tests |
| Proposition 2.11 | Schema 4 ↔ transitivity | Verified in tests |
| Proposition 2.13 | Schema 5 ↔ euclideanness | Verified in tests |

## Part IV: Applied Modal Logic

### Chapter 14: Temporal Logics

*Coming soon.*

### Chapter 15: Epistemic Logics

*Coming soon.*
