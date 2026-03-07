module Gamen

# Formula types
export Formula, Bottom, Atom, Not, And, Or, Implies, Iff
export Box, Diamond, □, ◇
export Top, is_modal_free

# Kripke structures
export KripkeFrame, KripkeModel, accessible

# Semantics
export satisfies, is_true_in, is_valid, entails

# Frame properties and definability (Chapter 2)
export atoms
export is_reflexive, is_symmetric, is_transitive, is_serial, is_euclidean
export is_partially_functional, is_functional, is_weakly_dense
export is_weakly_connected, is_weakly_directed
export is_equivalence_relation, is_universal
export is_valid_on_frame

# Standard translation (Chapter 2, frd.7)
export FOFormula, FOBottom, FOTop, FOVar, FOPredicate
export FONot, FOAnd, FOOr, FOImplies, FOIff, FOForall, FOExists
export standard_translation

# Axiomatic derivations (Chapter 3)
export substitute
export is_tautology, is_tautological_instance
export AxiomSchema, SchemaK, SchemaDual, SchemaT, SchemaD, SchemaB, Schema4, Schema5
export is_instance
export ModalSystem, SYSTEM_K, SYSTEM_KT, SYSTEM_KD, SYSTEM_KB
export SYSTEM_K4, SYSTEM_K5, SYSTEM_S4, SYSTEM_S5
export Justification, Tautology, AxiomInst, ModusPonens, Necessitation
export ProofStep, Derivation, conclusion
export is_valid_derivation
export dual

# Completeness and canonical models (Chapter 4)
export subformulas, formula_closure
export is_derivable_from, is_consistent
export is_complete_consistent
export box_set, diamond_set, box_inverse, diamond_inverse
export lindenbaum_extend
export CanonicalModel, canonical_model
export determines, truth_lemma_holds

include("formulas.jl")
include("kripke.jl")
include("semantics.jl")
include("frame_properties.jl")
include("fol.jl")
include("axioms.jl")
include("completeness.jl")

end # module Gamen
