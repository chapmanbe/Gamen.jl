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
| Definition 1.6 | Model M = ⟨W, R, V⟩ | [`KripkeFrame`](@ref), [`KripkeModel`](@ref) |
| Definition 1.7 | Truth at a world | [`satisfies`](@ref) |
| Definition 1.9 | Truth in a model | [`is_true_in`](@ref) |
| Definition 1.11 | Validity in a class | [`is_valid`](@ref) |
| Definition 1.23 | Entailment | [`entails`](@ref) |
| Proposition 1.8 | □A ↔ ¬◇¬A duality | Verified in tests |

## Chapter 2: Frame Definability

| B&D Reference | Description | Gamen.jl |
|:---|:---|:---|
| Definition frd.3 | Frame F = ⟨W, R⟩ | [`KripkeFrame`](@ref) |
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

## Chapter 3: Axiomatic Derivations

| B&D Reference | Description | Gamen.jl |
|:---|:---|:---|
| Definition 3.1 | Modus ponens | [`ModusPonens`](@ref) |
| Definition 3.2 | Necessitation | [`Necessitation`](@ref) |
| Definition 3.3 | Derivation | [`Derivation`](@ref), [`is_valid_derivation`](@ref) |
| Definition 3.5 | Normal modal logic (K, Dual) | [`SchemaK`](@ref), [`SchemaDual`](@ref) |
| Definition 3.9 | Modal system KA₁...Aₙ | [`ModalSystem`](@ref), [`SYSTEM_K`](@ref) |
| Definition 3.10 | Derivability in a system | [`is_valid_derivation`](@ref) |
| Proposition 3.12 | □A → □(B → A) K-provable | Verified in tests |
| Proposition 3.13 | □(A ∧ B) → (□A ∧ □B) K-provable | Verified in tests |
| Table 3.1 | Axiom schemas T, D, B, 4, 5 | [`SchemaT`](@ref), [`SchemaD`](@ref), [`SchemaB`](@ref), [`Schema4`](@ref), [`Schema5`](@ref) |
| Section 3.8 | Named systems (S4, S5, etc.) | [`SYSTEM_S4`](@ref), [`SYSTEM_S5`](@ref) |
| Definition 3.26 | Dual formulas | [`dual`](@ref) |
| Theorem 3.31 | Soundness | Verified in tests |

## Part IV: Applied Modal Logic

### Chapter 14: Temporal Logics

*Coming soon.*

### Chapter 15: Epistemic Logics

*Coming soon.*
