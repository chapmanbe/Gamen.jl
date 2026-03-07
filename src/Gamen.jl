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

include("formulas.jl")
include("kripke.jl")
include("semantics.jl")
include("frame_properties.jl")
include("fol.jl")

end # module Gamen
