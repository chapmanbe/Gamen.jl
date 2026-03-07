module Gamen

# Formula types
export Formula, Bottom, Atom, Not, And, Or, Implies, Iff
export Box, Diamond
export Top, is_modal_free

# Kripke structures
export KripkeFrame, KripkeModel, accessible

# Semantics
export satisfies, is_true_in, is_valid, entails

include("formulas.jl")
include("kripke.jl")
include("semantics.jl")

end # module Gamen
