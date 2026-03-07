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

*Coming soon.*

## Part IV: Applied Modal Logic

### Chapter 14: Temporal Logics

*Coming soon.*

### Chapter 15: Epistemic Logics

*Coming soon.*
