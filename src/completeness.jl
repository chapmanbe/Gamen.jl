# Chapter 4: Completeness and Canonical Models (B&D)

# ── Subformulas ──

"""
    subformulas(φ::Formula) -> Set{Formula}

Return the set of all subformulas of `φ`, including `φ` itself.
"""
function subformulas end

subformulas(φ::Bottom) = Set{Formula}([φ])
subformulas(φ::Atom) = Set{Formula}([φ])
subformulas(φ::Not) = Set{Formula}([φ]) ∪ subformulas(φ.operand)
subformulas(φ::And) = Set{Formula}([φ]) ∪ subformulas(φ.left) ∪ subformulas(φ.right)
subformulas(φ::Or) = Set{Formula}([φ]) ∪ subformulas(φ.left) ∪ subformulas(φ.right)
subformulas(φ::Implies) = Set{Formula}([φ]) ∪ subformulas(φ.antecedent) ∪ subformulas(φ.consequent)
subformulas(φ::Iff) = Set{Formula}([φ]) ∪ subformulas(φ.left) ∪ subformulas(φ.right)
subformulas(φ::Box) = Set{Formula}([φ]) ∪ subformulas(φ.operand)
subformulas(φ::Diamond) = Set{Formula}([φ]) ∪ subformulas(φ.operand)

# ── Closure of a formula set ──

"""
    formula_closure(formulas) -> Vector{Formula}

Compute the closure of a set of formulas: all subformulas plus their
negations, sorted for deterministic enumeration. This gives a finite
"language" suitable for constructing canonical models over finite sets.
"""
function formula_closure(formulas)
    closed = Set{Formula}()
    for φ in formulas
        union!(closed, subformulas(φ))
    end
    # Add negations: for each formula A in the closure, ensure ¬A is present
    # (and for ¬A, ensure A is present)
    to_add = Set{Formula}()
    for φ in closed
        if φ isa Not
            push!(to_add, φ.operand)
        else
            push!(to_add, Not(φ))
        end
    end
    union!(closed, to_add)
    sort!(collect(closed); by=string)
end

# ── Derivability from a set (Definition 3.36) ──

"""
    is_derivable_from(system::ModalSystem, Γ, φ::Formula; max_worlds=4) -> Bool

Check whether `φ` is derivable from the set of formulas `Γ` in the modal
system `system` (Definition 3.36, B&D).

Γ ⊢_Σ A iff there exist B₁, …, Bₙ ∈ Γ such that
Σ ⊢ B₁ → (B₂ → ⋯ (Bₙ → A) ⋯).

By soundness and completeness, this is equivalent to: A holds at every
world of every model in the appropriate class where all formulas of Γ hold.
We check this semantically by enumerating frames up to `max_worlds` worlds.
"""
function is_derivable_from(system::ModalSystem, Γ, φ::Formula; max_worlds::Int=4)
    frame_filter = _frame_filter(system)
    all_atoms = Set{Symbol}()
    for f in Γ
        union!(all_atoms, atoms(f))
    end
    union!(all_atoms, atoms(φ))
    vars = collect(all_atoms)

    for n in 1:max_worlds
        worlds = [Symbol("w", i) for i in 1:n]
        for frame in _enumerate_frames(worlds)
            frame_filter(frame) || continue
            for val in _enumerate_valuations(worlds, vars)
                model = KripkeModel(frame, val)
                for w in worlds
                    if all(f -> satisfies(model, w, f), Γ) && !satisfies(model, w, φ)
                        return false
                    end
                end
            end
        end
    end
    return true
end

"""
    is_derivable_from(system::ModalSystem, Γ, φ::Formula, models) -> Bool

Check derivability semantically against a specific collection of models.
Returns true iff at every world of every model where all of Γ hold, φ also holds.
"""
function is_derivable_from(system::ModalSystem, Γ, φ::Formula, models)
    for model in models
        for w in model.frame.worlds
            if all(f -> satisfies(model, w, f), Γ) && !satisfies(model, w, φ)
                return false
            end
        end
    end
    return true
end

# ── Consistency (Definition 3.39) ──

"""
    is_consistent(system::ModalSystem, Γ; max_worlds=4) -> Bool

Check whether the set of formulas `Γ` is consistent relative to the modal
system `system` (Definition 3.39, B&D).

Γ is Σ-consistent iff Γ ⊬_Σ ⊥, equivalently, iff there exists a model
in the appropriate class with a world satisfying all formulas in Γ.
"""
function is_consistent(system::ModalSystem, Γ; max_worlds::Int=4)
    frame_filter = _frame_filter(system)
    all_atoms = Set{Symbol}()
    for f in Γ
        union!(all_atoms, atoms(f))
    end
    vars = collect(all_atoms)
    if isempty(vars)
        vars = [:_dummy]
    end

    for n in 1:max_worlds
        worlds = [Symbol("w", i) for i in 1:n]
        for frame in _enumerate_frames(worlds)
            frame_filter(frame) || continue
            for val in _enumerate_valuations(worlds, vars)
                model = KripkeModel(frame, val)
                for w in worlds
                    if all(f -> satisfies(model, w, f), Γ)
                        return true
                    end
                end
            end
        end
    end
    return false
end

# ── Complete Σ-consistent sets (Definition 4.1) ──

"""
    is_complete_consistent(system::ModalSystem, Γ, language; max_worlds=4) -> Bool

Check whether the set `Γ` is a *complete Σ-consistent* set relative to
the given `language` (a set of formulas).

Definition 4.1 (B&D): Γ is complete Σ-consistent iff:
1. Γ is Σ-consistent, and
2. For every formula A in the language, either A ∈ Γ or ¬A ∈ Γ.
"""
function is_complete_consistent(system::ModalSystem, Γ, language; max_worlds::Int=4)
    Γ_set = Set{Formula}(Γ)
    # Check completeness: for every formula in the language, A ∈ Γ or ¬A ∈ Γ
    for φ in language
        if φ isa Not
            # For ¬B, we need ¬B ∈ Γ or B ∈ Γ
            φ ∈ Γ_set || φ.operand ∈ Γ_set || return false
        else
            # For A, we need A ∈ Γ or ¬A ∈ Γ
            φ ∈ Γ_set || Not(φ) ∈ Γ_set || return false
        end
    end
    # Check consistency
    return is_consistent(system, Γ; max_worlds=max_worlds)
end

# ── Properties of complete consistent sets (Proposition 4.2) ──

"""
    box_set(Γ) -> Set{Formula}

□Γ = {□B : B ∈ Γ} (Definition 4.5, B&D).
"""
box_set(Γ) = Set{Formula}(Box(f) for f in Γ)

"""
    diamond_set(Γ) -> Set{Formula}

◇Γ = {◇B : B ∈ Γ} (Definition 4.5, B&D).
"""
diamond_set(Γ) = Set{Formula}(Diamond(f) for f in Γ)

"""
    box_inverse(Γ) -> Set{Formula}

□⁻¹Γ = {B : □B ∈ Γ} (Definition 4.5, B&D).
"""
function box_inverse(Γ)
    result = Set{Formula}()
    for f in Γ
        if f isa Box
            push!(result, f.operand)
        end
    end
    result
end

"""
    diamond_inverse(Γ) -> Set{Formula}

◇⁻¹Γ = {B : ◇B ∈ Γ} (Definition 4.5, B&D).
"""
function diamond_inverse(Γ)
    result = Set{Formula}()
    for f in Γ
        if f isa Diamond
            push!(result, f.operand)
        end
    end
    result
end

# ── Lindenbaum's Lemma (Theorem 4.3) ──

"""
    lindenbaum_extend(system::ModalSystem, Γ, language; max_worlds=4) -> Set{Formula}

Extend a Σ-consistent set `Γ` to a complete Σ-consistent set over the
given `language` (Theorem 4.3, Lindenbaum's Lemma, B&D).

The algorithm processes formulas in `language` one at a time. For each
formula A, if Γ ∪ {A} is consistent, add A; otherwise add ¬A.

Throws `ArgumentError` if `Γ` is not Σ-consistent.
"""
function lindenbaum_extend(system::ModalSystem, Γ, language; max_worlds::Int=4)
    is_consistent(system, collect(Γ); max_worlds=max_worlds) ||
        throw(ArgumentError("Γ must be Σ-consistent"))

    Δ = Set{Formula}(Γ)
    for φ in language
        # Skip if already decided
        φ ∈ Δ && continue
        Not(φ) ∈ Δ && continue
        # Try adding φ
        candidate = collect(Δ ∪ Set{Formula}([φ]))
        if is_consistent(system, candidate; max_worlds=max_worlds)
            push!(Δ, φ)
        else
            push!(Δ, Not(φ))
        end
    end
    Δ
end

# ── Canonical model (Definition 4.11) ──

"""
    CanonicalModel

The canonical model M^Σ for a modal system Σ over a finite language
(Definition 4.11, B&D).

Fields:
- `system`: the modal system Σ
- `language`: the finite set of formulas
- `worlds`: vector of complete Σ-consistent sets (each a `Set{Formula}`)
- `model`: the corresponding `KripkeModel`
"""
struct CanonicalModel
    system::ModalSystem
    language::Vector{Formula}
    worlds::Vector{Set{Formula}}
    model::KripkeModel
end

function Base.show(io::IO, cm::CanonicalModel)
    print(io, "CanonicalModel(", cm.system, ", ",
          length(cm.worlds), " worlds, ",
          length(cm.language), " formulas)")
end

"""
    canonical_model(system::ModalSystem, language; max_worlds=4) -> CanonicalModel

Construct the canonical model M^Σ = ⟨W^Σ, R^Σ, V^Σ⟩ for the modal
system `system` over a finite `language` (Definition 4.11, B&D).

1. W^Σ = {Δ : Δ is a complete Σ-consistent set over the language}
2. R^Σ ΔΔ' holds iff □⁻¹Δ ⊆ Δ' (i.e., if □A ∈ Δ then A ∈ Δ')
3. V^Σ(p) = {Δ : p ∈ Δ}

The `language` should be a collection of formulas; it will be closed
under subformulas and negation automatically.
"""
function canonical_model(system::ModalSystem, language; max_worlds::Int=4)
    closed = formula_closure(language)

    # Enumerate all complete Σ-consistent sets
    worlds_sets = _enumerate_complete_consistent_sets(system, closed; max_worlds=max_worlds)

    isempty(worlds_sets) && error("No complete consistent sets found; language may be too large or max_worlds too small")

    # Assign world names
    world_names = [Symbol("Δ", i) for i in 1:length(worlds_sets)]

    # Build accessibility relation: R^Σ ΔΔ' iff □⁻¹Δ ⊆ Δ'
    relation = Dict{Symbol,Set{Symbol}}()
    for (i, Δ) in enumerate(worlds_sets)
        relation[world_names[i]] = Set{Symbol}()
        box_inv = box_inverse(Δ)
        for (j, Δ′) in enumerate(worlds_sets)
            if box_inv ⊆ Δ′
                push!(relation[world_names[i]], world_names[j])
            end
        end
    end

    frame = KripkeFrame(Set{Symbol}(world_names), relation)

    # Build valuation: V^Σ(p) = {Δ : p ∈ Δ}
    all_atoms_set = Set{Symbol}()
    for φ in closed
        union!(all_atoms_set, atoms(φ))
    end
    valuation = Dict{Symbol,Set{Symbol}}()
    for p in all_atoms_set
        valuation[p] = Set{Symbol}()
        atom_p = Atom(p)
        for (i, Δ) in enumerate(worlds_sets)
            if atom_p ∈ Δ
                push!(valuation[p], world_names[i])
            end
        end
    end

    model = KripkeModel(frame, valuation)
    CanonicalModel(system, closed, worlds_sets, model)
end

# ── Determination (Definition 4.13) ──

"""
    determines(model::KripkeModel, system::ModalSystem, language; max_worlds=4) -> Bool

A model M *determines* a normal modal logic Σ if for every formula A
in the language: M ⊩ A if and only if Σ ⊢ A (Definition 4.13, B&D).

Uses semantic checking for derivability.
"""
function determines(model::KripkeModel, system::ModalSystem, language; max_worlds::Int=4)
    for φ in language
        valid_in_model = is_true_in(model, φ)
        derivable = is_derivable_from(system, Formula[], φ; max_worlds=max_worlds)
        valid_in_model == derivable || return false
    end
    return true
end

"""
    truth_lemma_holds(cm::CanonicalModel) -> Bool

Verify the Truth Lemma (Proposition 4.12, B&D) for a canonical model:
for every formula A in the language and every world Δ,
M^Σ, Δ ⊩ A if and only if A ∈ Δ.
"""
function truth_lemma_holds(cm::CanonicalModel)
    for φ in cm.language
        for (i, Δ) in enumerate(cm.worlds)
            wname = Symbol("Δ", i)
            sem = satisfies(cm.model, wname, φ)
            mem = φ ∈ Δ
            sem == mem || return false
        end
    end
    return true
end

# ── Internal helpers ──

"""Return a frame filter predicate for the given modal system.

Uses the Sahlqvist correspondence declared on each AxiomSchema via
`frame_predicate` (BdRV Ch.3): each schema carries its own frame
condition, so this function simply collects them.
"""
function _frame_filter(system::ModalSystem)
    checks = filter(!isnothing, frame_predicate.(system.schemas))
    isempty(checks) ? (_ -> true) : (frame -> all(c -> c(frame), checks))
end

"""Lazily enumerate all possible frames on the given worlds."""
function _enumerate_frames(worlds::Vector{Symbol})
    n = length(worlds)
    n_edges = n * n
    (begin
        rel = Dict{Symbol,Set{Symbol}}(w => Set{Symbol}() for w in worlds)
        for (k, (i, j)) in enumerate(Iterators.product(1:n, 1:n))
            if (bits >> (k - 1)) & 1 == 1
                push!(rel[worlds[i]], worlds[j])
            end
        end
        KripkeFrame(Set{Symbol}(worlds), rel)
    end for bits in 0:(BigInt(2)^n_edges - 1))
end

"""Lazily enumerate all valuations for the given worlds and variables."""
function _enumerate_valuations(worlds::Vector{Symbol}, vars::Vector{Symbol})
    n = length(worlds)
    n_vals = length(vars)
    if n_vals == 0
        return (Dict{Symbol,Set{Symbol}}() for _ in 1:1)
    end
    total = (BigInt(1) << n) ^ n_vals
    (begin
        val = Dict{Symbol,Set{Symbol}}()
        remainder = i
        for v in vars
            bits = remainder & ((BigInt(1) << n) - 1)
            remainder >>= n
            val[v] = Set{Symbol}(worlds[j] for j in 1:n if (bits >> (j - 1)) & 1 == 1)
        end
        val
    end for i in BigInt(0):(total - 1))
end

"""Enumerate all complete Σ-consistent sets over a closed language."""
function _enumerate_complete_consistent_sets(system::ModalSystem, language::Vector{Formula}; max_worlds::Int=4)
    # Collect the "base" formulas: for each pair (A, ¬A) pick just A
    base_formulas = Formula[]
    seen = Set{Formula}()
    for φ in language
        φ ∈ seen && continue
        if φ isa Not
            push!(seen, φ)
            push!(seen, φ.operand)
            push!(base_formulas, φ.operand)
        else
            push!(seen, φ)
            push!(seen, Not(φ))
            push!(base_formulas, φ)
        end
    end

    n = length(base_formulas)
    results = Set{Formula}[]

    # For each subset assignment (include A or ¬A), check consistency
    for bits in 0:(2^n - 1)
        candidate = Set{Formula}()
        for (j, φ) in enumerate(base_formulas)
            if (bits >> (j - 1)) & 1 == 1
                push!(candidate, φ)
            else
                push!(candidate, Not(φ))
            end
        end
        # Check consistency
        if is_consistent(system, collect(candidate); max_worlds=max_worlds)
            push!(results, candidate)
        end
    end
    results
end
