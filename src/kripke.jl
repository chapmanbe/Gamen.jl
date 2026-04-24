"""
    KripkeFrame

A Kripke frame ⟨W, R⟩ consisting of a nonempty set of worlds W and a binary
accessibility relation R on W (Definition 1.6, B&D).
"""
struct KripkeFrame
    worlds::Set{Symbol}
    relation::Dict{Symbol,Set{Symbol}}
end

function KripkeFrame(worlds, relation::Vector{Pair{Symbol,Symbol}})
    w = Set{Symbol}(worlds)
    rel = Dict{Symbol,Set{Symbol}}()
    for world in w
        rel[world] = Set{Symbol}()
    end
    for (from, to) in relation
        push!(rel[from], to)
    end
    KripkeFrame(w, rel)
end

"""
    KripkeModel

A model M = ⟨W, R, V⟩ where V is a valuation function assigning to each
propositional variable p a set V(p) of worlds where p is true
(Definition 1.6, B&D).

The valuation maps `Atom`s to sets of worlds: V(p) ⊆ W.
"""
struct KripkeModel
    frame::KripkeFrame
    valuation::Dict{Atom,Set{Symbol}}
end

"""
    KripkeModel(frame, valuation_pairs)

Convenience constructor where valuation is specified as the book does:
each propositional variable maps to a list of worlds where it is true.
Symbol keys are automatically wrapped in `Atom`.

# Example (Figure 1.1, B&D)
```julia
frame = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w1 => :w3])
model = KripkeModel(frame, [:p => [:w1, :w2], :q => [:w2]])
```
"""
function KripkeModel(frame::KripkeFrame, valuation::Vector{Pair{Symbol,Vector{Symbol}}})
    val = Dict{Atom,Set{Symbol}}()
    for (atom, worlds) in valuation
        val[Atom(atom)] = Set{Symbol}(worlds)
    end
    KripkeModel(frame, val)
end

"""
    accessible(frame::KripkeFrame, world::Symbol)

Return the set of worlds accessible from `world`. When Rww' holds,
we say w' is *accessible from* w (Definition 1.6, B&D).
"""
function accessible(frame::KripkeFrame, world::Symbol)
    get(frame.relation, world, Set{Symbol}())
end
