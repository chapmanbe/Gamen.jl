# Chapter 15: Epistemic Logics (B&D)

# ── Formula types (Definition 15.2) ──

"""
    Knowledge <: Formula

The epistemic knowledge operator K_a. M,w ⊩ K_a B iff M,w' ⊩ B for all w'
with R_a ww' (Definition 15.5, item 7, B&D).

The agent `a` is any value that can serve as a key (typically a Symbol).
"""
struct Knowledge <: Formula
    agent::Symbol
    operand::Formula
end

Base.show(io::IO, f::Knowledge) = print(io, "K[", f.agent, "]", f.operand)

# ==/hash come from the generic traversal protocol (src/traversal.jl)
is_modal_free(::Knowledge) = false

"""
    Announce <: Formula

The public announcement operator [B]C. M,w ⊩ [B]C iff M,w ⊩ B implies
M|B, w ⊩ C, where M|B is the model restricted to worlds where B holds
(Definition 15.11, item 8, B&D).
"""
struct Announce <: Formula
    announcement::Formula
    body::Formula
end

Base.show(io::IO, f::Announce) = print(io, "[", f.announcement, "]", f.body)
is_modal_free(::Announce) = false

# ── Multi-agent epistemic model (Definition 15.4) ──

"""
    EpistemicFrame

A multi-agent Kripke frame with a family of accessibility relations, one for
each agent. Wraps a set of worlds W and a dictionary mapping agent symbols to
their accessibility relations (Definition 15.4, B&D).

Fields:
- `worlds::Set{Symbol}`: the set of possible worlds W
- `relations::Dict{Symbol, Dict{Symbol, Set{Symbol}}}`: agent → (world → successors)
"""
struct EpistemicFrame
    worlds::Set{Symbol}
    relations::Dict{Symbol,Dict{Symbol,Set{Symbol}}}

    function EpistemicFrame(worlds::Set{Symbol},
                            relations::Dict{Symbol,Dict{Symbol,Set{Symbol}}})
        isempty(worlds) &&
            throw(ArgumentError("an epistemic frame requires a nonempty set of worlds (Definition 15.4, B&D)"))
        for (agent, rel) in relations
            for (from, targets) in rel
                from ∈ worlds ||
                    throw(ArgumentError("relation source $from for agent $agent is not a world of the frame"))
                for to in targets
                    to ∈ worlds ||
                        throw(ArgumentError("relation target $to for agent $agent is not a world of the frame"))
                end
            end
        end
        new(worlds, relations)
    end
end

"""
    EpistemicFrame(worlds, agent_relations)

Convenience constructor. `agent_relations` is a vector of `agent => pairs`
where pairs is a `Vector{Pair{Symbol,Symbol}}`.

# Example
```julia
frame = EpistemicFrame(
    [:w1, :w2, :w3],
    [:a => [:w1 => :w2, :w2 => :w2],
     :b => [:w1 => :w1, :w1 => :w3, :w3 => :w3]]
)
```
"""
function EpistemicFrame(worlds, agent_relations::Vector)
    w = Set{Symbol}(worlds)
    rels = Dict{Symbol,Dict{Symbol,Set{Symbol}}}()
    for (agent, pairs) in agent_relations
        rel = Dict{Symbol,Set{Symbol}}()
        for world in w
            rel[world] = Set{Symbol}()
        end
        for (from, to) in pairs
            from ∈ w ||
                throw(ArgumentError("relation source $from for agent $agent is not a world of the frame"))
            push!(rel[from], to)
        end
        rels[Symbol(agent)] = rel
    end
    EpistemicFrame(w, rels)
end

"""
    agents(frame::EpistemicFrame) -> Set{Symbol}

Return the set of agent symbols in the frame.
"""
agents(frame::EpistemicFrame) = Set(keys(frame.relations))

"""
    accessible(frame::EpistemicFrame, agent::Symbol, world::Symbol) -> Set{Symbol}

Return the set of worlds accessible by `agent` from `world`.

The returned `Set` is a copy: mutating it does not alter the frame.
"""
function accessible(frame::EpistemicFrame, agent::Symbol, world::Symbol)
    rel = get(frame.relations, agent, nothing)
    rel === nothing && return Set{Symbol}()
    stored = get(rel, world, nothing)
    stored === nothing ? Set{Symbol}() : copy(stored)
end

# Non-copying successor lookup for internal hot loops (model checking).
# Callers must not mutate the result. Mirrors _successors(::KripkeFrame, w).
function _successors(frame::EpistemicFrame, agent::Symbol, world::Symbol)
    rel = get(frame.relations, agent, nothing)
    rel === nothing && return _EMPTY_WORLDS
    get(rel, world, _EMPTY_WORLDS)
end

"""
    EpistemicModel

A multi-agent epistemic model M = ⟨W, R, V⟩ where R = {R_a : a ∈ G} is a
family of accessibility relations (one per agent), and V is a valuation
(Definition 15.4, B&D).

Fields:
- `frame::EpistemicFrame`: the multi-agent frame
- `valuation::Dict{Atom, Set{Symbol}}`: atom → set of worlds where it is true
"""
struct EpistemicModel
    frame::EpistemicFrame
    valuation::Dict{Atom,Set{Symbol}}

    function EpistemicModel(frame::EpistemicFrame, valuation::Dict{Atom,Set{Symbol}})
        for (atom, true_worlds) in valuation
            for w in true_worlds
                w ∈ frame.worlds ||
                    throw(ArgumentError("valuation of $(atom) includes $w, which is not a world of the frame"))
            end
        end
        new(frame, valuation)
    end
end

"""
    EpistemicModel(frame, valuation_pairs)

Convenience constructor where valuation is a `Vector{Pair{Symbol,Vector{Symbol}}}`.
Symbol keys are automatically wrapped in `Atom`.

# Example
```julia
frame = EpistemicFrame([:w1,:w2,:w3], [:a => [:w1=>:w2], :b => [:w1=>:w3]])
model = EpistemicModel(frame, [:p => [:w1,:w2], :q => [:w2]])
```
"""
function EpistemicModel(frame::EpistemicFrame, valuation::Vector{Pair{Symbol,Vector{Symbol}}})
    val = Dict{Atom,Set{Symbol}}()
    for (atom, worlds) in valuation
        val[Atom(atom)] = Set{Symbol}(worlds)
    end
    EpistemicModel(frame, val)
end

# ── Semantics (Definition 15.5 and 15.11) ──
#
# The propositional clauses (⊥, atoms, ¬, ∧, ∨, →, ↔) are the shared base
# clauses in src/semantics.jl — an epistemic model is a configuration of the
# base system, not a reimplementation. Only the epistemic operators are
# defined here.

# K_a B: true at w iff B is true at all R_a-successors (Definition 15.5,
# item 7, B&D) — a □ indexed by agent, plugged in via successor_worlds
successor_worlds(model::EpistemicModel, world::Symbol, f::Knowledge) =
    _successors(model.frame, f.agent, world)

# The model argument is deliberately untyped: on a model with no agent
# relations (e.g. a plain KripkeModel), the successor_worlds fallback gives
# an informative ArgumentError instead of a raw MethodError
satisfies(model, world::Symbol, f::Knowledge) =
    _universal_modal_satisfies(model, world, f)

# [B]C: true at w iff (M,w ⊩ B) implies (M|B, w ⊩ C)
function satisfies(model::EpistemicModel, world::Symbol, f::Announce)
    if !satisfies(model, world, f.announcement)
        return true  # vacuously true when announcement is false at w
    end
    restricted = restrict_model(model, f.announcement)
    satisfies(restricted, world, f.body)
end

# ── Model restriction (Definition 15.11, M|B) ──

"""
    restrict_model(model::EpistemicModel, announcement::Formula) -> EpistemicModel

Construct the *restricted model* M|B = ⟨W', R', V'⟩ where:
- W' = {u ∈ W : M,u ⊩ B}
- R'_a = R_a ∩ (W' × W') for each agent a
- V'(p) = {u ∈ W' : u ∈ V(p)}

(Definition 15.11, item 8b, B&D).
"""
function restrict_model(model::EpistemicModel, announcement::Formula)
    # W' = worlds where announcement holds
    w_prime = Set{Symbol}(w for w in model.frame.worlds if satisfies(model, w, announcement))

    # Build restricted relations
    new_rels = Dict{Symbol,Dict{Symbol,Set{Symbol}}}()
    for (agent, rel) in model.frame.relations
        new_rel = Dict{Symbol,Set{Symbol}}()
        for w in w_prime
            new_rel[w] = intersect(get(rel, w, Set{Symbol}()), w_prime)
        end
        new_rels[agent] = new_rel
    end

    # Restrict valuation to W'
    new_val = Dict{Atom,Set{Symbol}}()
    for (atom, worlds) in model.valuation
        new_val[atom] = intersect(worlds, w_prime)
    end

    EpistemicModel(EpistemicFrame(w_prime, new_rels), new_val)
end

# ── Group and common knowledge operators (Definition 15.3 and 15.6) ──

"""
    group_knows(model::EpistemicModel, world::Symbol, agents::Vector{Symbol}, formula::Formula) -> Bool

Check whether every agent in `agents` knows `formula` at `world`.
This is the "everybody knows" operator E_{G'} A = ⋀_{b∈G'} K_b A
(Definition 15.3, B&D).
"""
function group_knows(model::EpistemicModel, world::Symbol, agents::Vector{Symbol}, formula::Formula)
    all(a -> satisfies(model, world, Knowledge(a, formula)), agents)
end

"""
    common_knowledge(model::EpistemicModel, world::Symbol, group::Vector{Symbol}, formula::Formula) -> Bool

Check whether `formula` is common knowledge among `group` at `world`.
C_G A holds at w iff A holds at every world reachable via the transitive
closure of ⋃_{b∈G} R_b (Definition 15.6, B&D).

Computed by BFS over the union of agent accessibility relations. Per
Definition 15.6 this is the *transitive* closure (one or more steps), so
`world` itself is included only if it is reachable from itself. On reflexive
frames — the standard setting, since knowledge is veridical — this coincides
with the reflexive-transitive closure (issue #10).
"""
function common_knowledge(model::EpistemicModel, world::Symbol,
                          group::Vector{Symbol}, formula::Formula)
    # Seed with the immediate successors of `world`, not `world` itself:
    # visited = worlds reachable in ≥ 1 step (transitive closure).
    visited = Set{Symbol}()
    queue = Symbol[]
    for agent in group
        append!(queue, _successors(model.frame, agent, world))
    end
    while !isempty(queue)
        w = popfirst!(queue)
        w in visited && continue
        push!(visited, w)
        for agent in group
            for w_prime in _successors(model.frame, agent, w)
                w_prime in visited || push!(queue, w_prime)
            end
        end
    end
    # C_G A holds at world iff A holds at every reachable world
    all(w -> satisfies(model, w, formula), visited)
end

# ── Bisimulation (Definition 15.7) ──

"""
    is_bisimulation(M1::EpistemicModel, M2::EpistemicModel,
                    relation::Vector{Pair{Symbol,Symbol}}) -> Bool

Check whether `relation` (a set of world pairs) is a bisimulation between
M1 and M2 (Definition 15.7, B&D).

A relation ℛ ⊆ W₁ × W₂ is a bisimulation when for every ⟨w₁, w₂⟩ ∈ ℛ:
1. w₁ ∈ V₁(p) iff w₂ ∈ V₂(p) for all propositional variables p.
2. (Forth) For each agent a and v₁ ∈ W₁ with R_{a,1} w₁v₁, there exists
   v₂ ∈ W₂ with R_{a,2} w₂v₂ and ⟨v₁,v₂⟩ ∈ ℛ.
3. (Back) For each agent a and v₂ ∈ W₂ with R_{a,2} w₂v₂, there exists
   v₁ ∈ W₁ with R_{a,1} w₁v₁ and ⟨v₁,v₂⟩ ∈ ℛ.
"""
function is_bisimulation(M1::EpistemicModel, M2::EpistemicModel,
                          relation::Vector{Pair{Symbol,Symbol}})
    rel_set = Set(relation)
    # Collect all atoms from both models
    all_atoms = union(keys(M1.valuation), keys(M2.valuation))

    for (w1, w2) in rel_set
        # Clause 1: propositional agreement
        for p in all_atoms
            v1 = w1 in get(M1.valuation, p, Set{Symbol}())
            v2 = w2 in get(M2.valuation, p, Set{Symbol}())
            v1 == v2 || return false
        end

        # Gather agents in both models
        all_agents = union(agents(M1.frame), agents(M2.frame))

        for a in all_agents
            # Clause 2: forth — every R_a-successor of w1 in M1 has a partner in M2
            for v1 in _successors(M1.frame, a, w1)
                found = any(v2 -> (v1 => v2) in rel_set, _successors(M2.frame, a, w2))
                found || return false
            end

            # Clause 3: back — every R_a-successor of w2 in M2 has a partner in M1
            for v2 in _successors(M2.frame, a, w2)
                found = any(v1 -> (v1 => v2) in rel_set, _successors(M1.frame, a, w1))
                found || return false
            end
        end
    end
    true
end

"""
    bisimilar_worlds(M1::EpistemicModel, M2::EpistemicModel,
                     w1::Symbol, w2::Symbol,
                     relation::Vector{Pair{Symbol,Symbol}}) -> Bool

Check that ⟨M1, w1⟩ ⟺ ⟨M2, w2⟩ via the given bisimulation relation (that
is, `(w1 => w2)` is in the relation and the relation is a bisimulation).
"""
function bisimilar_worlds(M1::EpistemicModel, M2::EpistemicModel,
                           w1::Symbol, w2::Symbol,
                           relation::Vector{Pair{Symbol,Symbol}})
    (w1 => w2) in relation && is_bisimulation(M1, M2, relation)
end

# ── Convenience: convert KripkeModel to single-agent EpistemicModel ──

"""
    EpistemicModel(model::KripkeModel, agent::Symbol) -> EpistemicModel

Wrap a single-agent [`KripkeModel`](@ref) as an [`EpistemicModel`](@ref) with
one agent `agent` whose accessibility relation is the frame's relation.
"""
function EpistemicModel(model::KripkeModel, agent::Symbol)
    rel = Dict{Symbol,Set{Symbol}}(w => copy(succs)
                                    for (w, succs) in model.frame.relation)
    frame = EpistemicFrame(copy(model.frame.worlds),
                           Dict{Symbol,Dict{Symbol,Set{Symbol}}}(agent => rel))
    EpistemicModel(frame, copy(model.valuation))
end

# ── Epistemic modal systems ──

"""
    EpistemicSystem

An epistemic modal system: a name plus the frame conditions each agent's
accessibility relation must satisfy (Table 15.1, B&D). Mirrors
[`ModalSystem`](@ref): frame conditions are first-class data, stored as
named predicates on a single-agent `KripkeFrame` so the Chapter 2
frame-property checkers are reused unchanged.

Check a frame or model against a system with
[`is_valid_epistemic_frame`](@ref) / [`is_valid_epistemic_model`](@ref), or
get the specific failures from [`epistemic_frame_violations`](@ref).
"""
struct EpistemicSystem
    name::String
    conditions::Vector{Pair{Symbol,Function}}
end

Base.show(io::IO, s::EpistemicSystem) = print(io, s.name)

"""
    EPISTEMIC_K

The minimal epistemic system K (just the K axiom / closure principle).
The accessibility relations are unconstrained.
"""
const EPISTEMIC_K = EpistemicSystem("Epistemic K", Pair{Symbol,Function}[])

"""
    EPISTEMIC_KT

Knowledge system KT: K + Veridicality (K_a A → A).
Requires each agent's accessibility relation to be reflexive.
"""
const EPISTEMIC_KT = EpistemicSystem("Epistemic KT",
    [:reflexive => is_reflexive])

"""
    EPISTEMIC_S4

Knowledge system S4: K + Veridicality + Positive Introspection (K_a A → K_a K_a A).
Requires reflexivity + transitivity.
"""
const EPISTEMIC_S4 = EpistemicSystem("Epistemic S4",
    [:reflexive => is_reflexive, :transitive => is_transitive])

"""
    EPISTEMIC_S5

Full knowledge system S5: K + Veridicality + Negative Introspection (¬K_a A → K_a ¬K_a A).
Requires each agent's relation to be an equivalence relation (reflexive +
transitive + euclidean). Epistemic logics typically use S5 (Table 15.1, B&D).
"""
const EPISTEMIC_S5 = EpistemicSystem("Epistemic S5",
    [:reflexive => is_reflexive, :transitive => is_transitive,
     :euclidean => is_euclidean])

"""
    agent_frame(frame::EpistemicFrame, agent::Symbol) -> KripkeFrame

Extract one agent's accessibility relation as a single-relation
[`KripkeFrame`](@ref), so the Chapter 2 frame-property predicates apply to
it directly. The returned frame is an independent copy.
"""
function agent_frame(frame::EpistemicFrame, agent::Symbol)
    rel = get(frame.relations, agent, Dict{Symbol,Set{Symbol}}())
    KripkeFrame(copy(frame.worlds),
                Dict{Symbol,Set{Symbol}}(w => copy(s) for (w, s) in rel))
end

"""
    epistemic_frame_violations(frame::EpistemicFrame, system::EpistemicSystem)
        -> Vector{Tuple{Symbol,Symbol}}

Return `(agent, condition)` pairs for every frame condition of `system`
that some agent's relation violates; empty means `frame` is a legitimate
`system`-frame. E.g. on a non-reflexive frame, veridicality (K_a A → A)
can fail even though nothing enforces it at construction — this is the
check that makes the assumption explicit (issue #10 §M6).
"""
function epistemic_frame_violations(frame::EpistemicFrame, system::EpistemicSystem)
    violations = Tuple{Symbol,Symbol}[]
    for agent in sort!(collect(agents(frame)))
        af = agent_frame(frame, agent)
        for (condition, holds) in system.conditions
            holds(af) || push!(violations, (agent, condition))
        end
    end
    violations
end

"""
    is_valid_epistemic_frame(frame::EpistemicFrame, system::EpistemicSystem) -> Bool

Check that every agent's accessibility relation satisfies all frame
conditions of `system`. Validation is a separate check, not a constructor
constraint, so non-`system` frames remain constructible as teaching
counterexamples.
"""
is_valid_epistemic_frame(frame::EpistemicFrame, system::EpistemicSystem) =
    isempty(epistemic_frame_violations(frame, system))

"""
    is_valid_epistemic_model(model::EpistemicModel, system::EpistemicSystem) -> Bool

Check `model`'s frame against the frame conditions of `system`; see
[`is_valid_epistemic_frame`](@ref).
"""
is_valid_epistemic_model(model::EpistemicModel, system::EpistemicSystem) =
    is_valid_epistemic_frame(model.frame, system)
