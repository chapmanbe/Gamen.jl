"""
    atoms(f::Formula) -> Set{Symbol}

Collect all propositional variable names appearing in a formula.
"""
function atoms end

atoms(::Bottom) = Set{Symbol}()
atoms(f::Atom) = Set{Symbol}([f.name])
atoms(f::Not) = atoms(f.operand)
atoms(f::And) = atoms(f.left) ∪ atoms(f.right)
atoms(f::Or) = atoms(f.left) ∪ atoms(f.right)
atoms(f::Implies) = atoms(f.antecedent) ∪ atoms(f.consequent)
atoms(f::Iff) = atoms(f.left) ∪ atoms(f.right)
atoms(f::Box) = atoms(f.operand)
atoms(f::Diamond) = atoms(f.operand)

# Frame properties (Definition 2.3, B&D)

"""
    is_reflexive(frame::KripkeFrame) -> Bool

A frame is *reflexive* if every world accesses itself: ∀w ∈ W, wRw
(Definition 2.3, B&D).
"""
function is_reflexive(frame::KripkeFrame)
    all(w -> w ∈ accessible(frame, w), frame.worlds)
end

"""
    is_symmetric(frame::KripkeFrame) -> Bool

A frame is *symmetric* if accessibility is symmetric:
∀w, w' ∈ W, wRw' → w'Rw (Definition 2.3, B&D).
"""
function is_symmetric(frame::KripkeFrame)
    all(frame.worlds) do w
        all(accessible(frame, w)) do v
            w ∈ accessible(frame, v)
        end
    end
end

"""
    is_transitive(frame::KripkeFrame) -> Bool

A frame is *transitive* if accessibility is transitive:
∀w, w', w'' ∈ W, (wRw' ∧ w'Rw'') → wRw'' (Definition 2.3, B&D).
"""
function is_transitive(frame::KripkeFrame)
    all(frame.worlds) do w
        all(accessible(frame, w)) do v
            accessible(frame, v) ⊆ accessible(frame, w)
        end
    end
end

"""
    is_serial(frame::KripkeFrame) -> Bool

A frame is *serial* if every world has at least one successor:
∀w ∈ W, ∃w' ∈ W, wRw' (Definition 2.3, B&D).
"""
function is_serial(frame::KripkeFrame)
    all(w -> !isempty(accessible(frame, w)), frame.worlds)
end

"""
    is_euclidean(frame::KripkeFrame) -> Bool

A frame is *euclidean* if:
∀w, w', w'' ∈ W, (wRw' ∧ wRw'') → w'Rw'' (Definition 2.3, B&D).
"""
function is_euclidean(frame::KripkeFrame)
    all(frame.worlds) do w
        succs = accessible(frame, w)
        all(succs) do v
            succs ⊆ accessible(frame, v)
        end
    end
end

# Additional frame properties (Table frd.2, B&D)

"""
    is_partially_functional(frame::KripkeFrame) -> Bool

A frame is *partially functional* if every world has at most one successor:
∀w∀u∀v((wRu ∧ wRv) → u = v) (Table frd.2, B&D).
"""
function is_partially_functional(frame::KripkeFrame)
    all(w -> length(accessible(frame, w)) <= 1, frame.worlds)
end

"""
    is_functional(frame::KripkeFrame) -> Bool

A frame is *functional* if every world has exactly one successor:
∀w∃v∀u(wRu ↔ u = v) (Table frd.2, B&D).

Equivalently, a frame is functional iff it is both serial and partially functional.
"""
function is_functional(frame::KripkeFrame)
    all(w -> length(accessible(frame, w)) == 1, frame.worlds)
end

"""
    is_weakly_dense(frame::KripkeFrame) -> Bool

A frame is *weakly dense* if every step can be decomposed into two steps:
∀u∀v(uRv → ∃w(uRw ∧ wRv)) (Table frd.2, B&D).
"""
function is_weakly_dense(frame::KripkeFrame)
    all(frame.worlds) do u
        all(accessible(frame, u)) do v
            any(frame.worlds) do w
                w ∈ accessible(frame, u) && v ∈ accessible(frame, w)
            end
        end
    end
end

"""
    is_weakly_connected(frame::KripkeFrame) -> Bool

A frame is *weakly connected* if any two successors of a world are
related or identical:
∀w∀u∀v((wRu ∧ wRv) → (uRv ∨ u = v ∨ vRu)) (Table frd.2, B&D).
"""
function is_weakly_connected(frame::KripkeFrame)
    all(frame.worlds) do w
        succs = accessible(frame, w)
        all(succs) do u
            all(succs) do v
                v ∈ accessible(frame, u) || u == v || u ∈ accessible(frame, v)
            end
        end
    end
end

"""
    is_weakly_directed(frame::KripkeFrame) -> Bool

A frame is *weakly directed* (has the "diamond property" or "confluence")
if any two successors of a world have a common successor:
∀w∀u∀v((wRu ∧ wRv) → ∃t(uRt ∧ vRt)) (Table frd.2, B&D).
"""
function is_weakly_directed(frame::KripkeFrame)
    all(frame.worlds) do w
        succs = accessible(frame, w)
        all(succs) do u
            all(succs) do v
                any(frame.worlds) do t
                    t ∈ accessible(frame, u) && t ∈ accessible(frame, v)
                end
            end
        end
    end
end

"""
    is_equivalence_relation(frame::KripkeFrame) -> Bool

A frame's accessibility relation is an *equivalence relation* iff it is
reflexive, symmetric, and transitive (Definition frd.11, B&D).
"""
function is_equivalence_relation(frame::KripkeFrame)
    is_reflexive(frame) && is_symmetric(frame) && is_transitive(frame)
end

"""
    is_universal(frame::KripkeFrame) -> Bool

A frame's accessibility relation is *universal* if every world is
accessible from every world: ∀u,v ∈ W, uRv (Definition frd.11, B&D).
"""
function is_universal(frame::KripkeFrame)
    n = length(frame.worlds)
    all(w -> length(accessible(frame, w)) == n, frame.worlds)
end

# Frame validity (Definition 2.1, B&D)

"""
    is_valid_on_frame(frame::KripkeFrame, formula::Formula) -> Bool

A formula A is *valid on a frame* F = ⟨W, R⟩ if it is true in every
model M = ⟨W, R, V⟩ based on F (Definition 2.1, B&D).

This enumerates all possible valuations for the propositional variables
in the formula, so it is only tractable for small frames and formulas.
"""
function is_valid_on_frame(frame::KripkeFrame, formula::Formula)
    vars = collect(atoms(formula))
    worlds = collect(frame.worlds)

    if isempty(vars)
        # No propositional variables — just check with empty valuation
        model = KripkeModel(frame, Dict{Symbol,Set{Symbol}}())
        return is_true_in(model, formula)
    end

    # Each variable can map to any subset of worlds.
    # We iterate over all combinations using a bit vector per variable.
    n_worlds = length(worlds)
    n_valuations = (1 << n_worlds) ^ length(vars)

    for i in 0:(n_valuations - 1)
        val = Dict{Symbol,Set{Symbol}}()
        remainder = i
        for var in vars
            bits = remainder & ((1 << n_worlds) - 1)
            remainder >>= n_worlds
            val[var] = Set{Symbol}(worlds[j] for j in 1:n_worlds if bits & (1 << (j - 1)) != 0)
        end
        model = KripkeModel(frame, val)
        if !is_true_in(model, formula)
            return false
        end
    end
    true
end
