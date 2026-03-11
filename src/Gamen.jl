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
export is_instance, frame_predicate
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

# Filtrations and decidability (Chapter 5)
export is_closed_under_subformulas, is_modally_closed
export subformula_closure, modal_closure
export world_equivalent, equivalence_classes, equivalence_class
export Filtration, finest_filtration, coarsest_filtration, symmetric_filtration, transitive_filtration
export filtration_lemma_holds
export has_finite_model_property, is_decidable_within

# Tableaux (Chapter 6)
export Prefix, extend, parent_prefix
export Sign, TrueSign, FalseSign, T_SIGN, F_SIGN
export PrefixedFormula, pf_true, pf_false
export TableauBranch, is_closed, used_prefixes, fresh_prefix
export Tableau, build_tableau
export TableauSystem
export TABLEAU_K, TABLEAU_KT, TABLEAU_KD, TABLEAU_KB
export TABLEAU_K4, TABLEAU_S4, TABLEAU_S5
export tableau_proves, tableau_consistent
export extract_countermodel
export tableau_rules, tableau_witness_rules

# Temporal logics (Chapter 14)
export PastBox, PastDiamond, FutureBox, FutureDiamond, Since, Until
export 𝐇, 𝐏, 𝐆, 𝐅
export TemporalModel
export is_transitive_frame, is_linear_frame, is_dense_frame
export is_unbounded_past, is_unbounded_future

# Epistemic logics (Chapter 15)
export Knowledge, Announce
export EpistemicFrame, EpistemicModel
export agents
export restrict_model
export group_knows, common_knowledge
export is_bisimulation, bisimilar_worlds
export EPISTEMIC_K, EPISTEMIC_KT, EPISTEMIC_S4, EPISTEMIC_S5

# Visualization (loaded via GamenMakieExt when CairoMakie, GraphMakie, Graphs are available)
export visualize_model

include("formulas.jl")
include("kripke.jl")
include("semantics.jl")
include("frame_properties.jl")
include("fol.jl")
include("axioms.jl")
include("completeness.jl")
include("filtrations.jl")
include("tableaux.jl")
include("temporal.jl")
include("epistemic.jl")

"""
    visualize_model(model::KripkeModel; kwargs...)
    visualize_model(frame::KripkeFrame; kwargs...)

Render a Kripke model (or frame) as a directed graph.

Requires CairoMakie, GraphMakie, and Graphs to be loaded:

```julia
using Gamen, CairoMakie, GraphMakie, Graphs
visualize_model(model)
```

See the GamenMakieExt extension for full documentation.
"""
function visualize_model end

end # module Gamen
