module Gamen

# Formula types
export Formula, Bottom, Atom, Not, And, Or, Implies, Iff
export Box, Diamond
export Top, is_modal_free

# Kripke structures
export KripkeFrame, KripkeModel, accessible

# Semantics
export satisfies, is_true_in, is_valid, entails

# Frame properties and definability (Chapter 2)
export atoms
export is_reflexive, is_symmetric, is_transitive, is_serial, is_euclidean
export is_valid_on_frame

include("formulas.jl")
include("kripke.jl")
include("semantics.jl")
include("frame_properties.jl")

end # module Gamen
