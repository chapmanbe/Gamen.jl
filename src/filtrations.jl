# Chapter 5: Filtrations and Decidability (B&D)

# ── Closure properties (Definition 5.1) ──

"""
    is_closed_under_subformulas(Γ::Set{Formula}) -> Bool

A set Γ is *closed under subformulas* if it contains every subformula
of every formula in Γ (Definition 5.1, B&D).
"""
function is_closed_under_subformulas(Γ::Set{Formula})
    for φ in Γ
        if !issubset(subformulas(φ), Γ)
            return false
        end
    end
    true
end

"""
    is_modally_closed(Γ::Set{Formula}) -> Bool

A set Γ is *modally closed* if it is closed under subformulas and moreover
A ∈ Γ implies □A, ◇A ∈ Γ (Definition 5.1, B&D).

Note: any modally closed set containing even one formula is infinite (□A
requires □□A, and so on), so on the finite sets this package builds, this
predicate holds only for ∅. See `modal_closure` for the finite one-step
extension used in practice.
"""
function is_modally_closed(Γ::Set{Formula})
    is_closed_under_subformulas(Γ) || return false
    for φ in Γ
        if !(Box(φ) ∈ Γ && Diamond(φ) ∈ Γ)
            return false
        end
    end
    true
end

"""
    subformula_closure(φ::Formula) -> Set{Formula}

Return the set of all subformulas of φ, which is closed under subformulas
by construction. This is the natural Γ for building filtrations.
"""
function subformula_closure(φ::Formula)
    subformulas(φ)
end

"""
    modal_closure(φ::Formula) -> Set{Formula}

Return the **one-step modal extension** of the subformulas of φ: □A and ◇A
for every subformula A, plus the subformulas of those new formulas.

This is *not* the modally closed set in the sense of `is_modally_closed`
(closed under prefixing □ and ◇): true modal closure is infinite for any
nonempty starting set (□A brings □□A, and so on), so
`is_modally_closed(modal_closure(φ))` is always `false`. The one-step
extension is the finite fragment used for filtration constructions.
"""
function modal_closure(φ::Formula)
    base = subformulas(φ)
    result = copy(base)
    for A in base
        push!(result, Box(A))
        push!(result, Diamond(A))
    end
    # The new formulas may have subformulas not yet in result
    to_add = Set{Formula}()
    for A in result
        union!(to_add, subformulas(A))
    end
    union!(result, to_add)
    result
end

# ── Equivalence relation on worlds (Definition 5.2) ──

"""
    world_equivalent(model::KripkeModel, Γ::Set{Formula}, u::Symbol, v::Symbol) -> Bool

Two worlds u, v are Γ-equivalent (u ≡ v) iff they make the same formulas
from Γ true: ∀A ∈ Γ, M,u ⊩ A ⟺ M,v ⊩ A (Definition 5.2, B&D).
"""
function world_equivalent(model::KripkeModel, Γ::Set{Formula}, u::Symbol, v::Symbol)
    for A in Γ
        if satisfies(model, u, A) != satisfies(model, v, A)
            return false
        end
    end
    true
end

"""
    equivalence_classes(model::KripkeModel, Γ::Set{Formula}) -> Vector{Set{Symbol}}

Compute the equivalence classes [w] under the Γ-equivalence relation.
Returns a vector of sets of world symbols (Proposition 5.3, B&D).
"""
function equivalence_classes(model::KripkeModel, Γ::Set{Formula})
    worlds = sort(collect(model.frame.worlds))
    classes = Set{Symbol}[]
    assigned = Set{Symbol}()

    for w in worlds
        w ∈ assigned && continue
        cls = Set{Symbol}([w])
        for v in worlds
            v ∈ assigned && continue
            v == w && continue
            if world_equivalent(model, Γ, w, v)
                push!(cls, v)
            end
        end
        push!(classes, cls)
        union!(assigned, cls)
    end
    classes
end

"""
    equivalence_class(model::KripkeModel, Γ::Set{Formula}, w::Symbol) -> Set{Symbol}

Return the equivalence class [w] of world w under Γ-equivalence.
"""
function equivalence_class(model::KripkeModel, Γ::Set{Formula}, w::Symbol)
    cls = Set{Symbol}([w])
    for v in model.frame.worlds
        v == w && continue
        if world_equivalent(model, Γ, w, v)
            push!(cls, v)
        end
    end
    cls
end

# ── Filtration construction (Definition 5.4) ──

"""
    Filtration

A filtration M* of model M through Γ. Stores the original model, the
formula set Γ, the equivalence classes (worlds of M*), and the
filtration model M* = ⟨W*, R*, V*⟩.

Fields:
- `original::KripkeModel`: the original model M
- `Γ::Set{Formula}`: the set of formulas (closed under subformulas)
- `classes::Vector{Set{Symbol}}`: equivalence classes [w₁], [w₂], ...
- `model::KripkeModel`: the filtration model M*
"""
struct Filtration
    original::KripkeModel
    Γ::Set{Formula}
    classes::Vector{Set{Symbol}}
    model::KripkeModel
end

function Base.show(io::IO, f::Filtration)
    n_orig = length(f.original.frame.worlds)
    n_filt = length(f.classes)
    print(io, "Filtration: $n_orig worlds → $n_filt classes")
end

"""
    finest_filtration(model::KripkeModel, Γ::Set{Formula}) -> Filtration

Construct the *finest filtration* of M through Γ (Definition 5.7, B&D).

R*[u][v] iff ∃u' ∈ [u] ∃v' ∈ [v] : Ru'v'

This is the most restrictive (fewest edges) filtration.
"""
function finest_filtration(model::KripkeModel, Γ::Set{Formula})
    classes = equivalence_classes(model, Γ)
    _build_filtration(model, Γ, classes, :finest)
end

"""
    coarsest_filtration(model::KripkeModel, Γ::Set{Formula}) -> Filtration

Construct the *coarsest filtration* of M through Γ (Definition 5.9, B&D).

R*[u][v] iff for all □A ∈ Γ: if M,u ⊩ □A then M,v ⊩ A, and
              for all ◇A ∈ Γ: if M,v ⊩ A then M,u ⊩ ◇A.

This is the least restrictive (most edges) filtration.
"""
function coarsest_filtration(model::KripkeModel, Γ::Set{Formula})
    classes = equivalence_classes(model, Γ)
    _build_filtration(model, Γ, classes, :coarsest)
end

"""
    _build_filtration(model, Γ, classes, type) -> Filtration

Internal: build a filtration model from equivalence classes.
"""
function _build_filtration(model::KripkeModel, Γ::Set{Formula},
                            classes::Vector{Set{Symbol}}, type::Symbol)
    n = length(classes)
    # Map each original world to its class index
    world_to_class = Dict{Symbol,Int}()
    for (i, cls) in enumerate(classes)
        for w in cls
            world_to_class[w] = i
        end
    end

    # Create world names for the filtration model
    class_names = [Symbol("c", i) for i in 1:n]

    # Build accessibility relation R*
    relation = Pair{Symbol,Symbol}[]

    for i in 1:n
        for j in 1:n
            has_edge = if type == :finest
                _finest_edge(model, classes[i], classes[j])
            else  # :coarsest
                _coarsest_edge(model, Γ, classes[i], classes[j])
            end
            if has_edge
                push!(relation, class_names[i] => class_names[j])
            end
        end
    end

    # Build valuation V*(p) = {[u] : u ∈ V(p)}
    valuation = Dict{Atom,Set{Symbol}}()
    for (atom, true_worlds) in model.valuation
        val_classes = Symbol[]
        for (i, cls) in enumerate(classes)
            if any(w -> w ∈ true_worlds, cls)
                push!(val_classes, class_names[i])
            end
        end
        valuation[atom] = Set{Symbol}(val_classes)
    end

    frame = KripkeFrame(class_names, relation)
    filt_model = KripkeModel(frame, valuation)

    Filtration(model, Γ, classes, filt_model)
end

"""
    _finest_edge(model, class_i, class_j) -> Bool

Finest filtration: R*[u][v] iff ∃u' ∈ [u] ∃v' ∈ [v] : Ru'v'.
"""
function _finest_edge(model::KripkeModel, class_i::Set{Symbol}, class_j::Set{Symbol})
    for u in class_i
        for v in accessible(model.frame, u)
            if v ∈ class_j
                return true
            end
        end
    end
    false
end

"""
    _coarsest_edge(model, Γ, class_i, class_j) -> Bool

Coarsest filtration: R*[u][v] iff
  for all □A ∈ Γ: if M,u ⊩ □A then M,v ⊩ A, and
  for all ◇A ∈ Γ: if M,v ⊩ A then M,u ⊩ ◇A.
Since all worlds in a class agree on Γ, we can pick any representative.
"""
function _coarsest_edge(model::KripkeModel, Γ::Set{Formula},
                         class_i::Set{Symbol}, class_j::Set{Symbol})
    u = first(class_i)
    v = first(class_j)

    for A in Γ
        if A isa Box
            inner = A.operand
            if inner ∈ Γ
                # If M,u ⊩ □B then M,v ⊩ B
                if satisfies(model, u, A) && !satisfies(model, v, inner)
                    return false
                end
            end
        end
        if A isa Diamond
            inner = A.operand
            if inner ∈ Γ
                # If M,v ⊩ B then M,u ⊩ ◇B
                if satisfies(model, v, inner) && !satisfies(model, u, A)
                    return false
                end
            end
        end
    end
    true
end

"""
    symmetric_filtration(model::KripkeModel, Γ::Set{Formula}) -> Filtration

Construct a *symmetric filtration* of M through Γ (Theorem 5.18.1, B&D).

R*[u][v] iff C₁(u,v) ∧ C₂(u,v), where:
- C₁: if □A ∈ Γ and M,u ⊩ □A then M,v ⊩ A; and if ◇A ∈ Γ and M,v ⊩ A then M,u ⊩ ◇A
- C₂: if □A ∈ Γ and M,v ⊩ □A then M,u ⊩ A; and if ◇A ∈ Γ and M,u ⊩ A then M,v ⊩ ◇A

If M is symmetric, then this is a filtration and R* is symmetric.
"""
function symmetric_filtration(model::KripkeModel, Γ::Set{Formula})
    classes = equivalence_classes(model, Γ)
    _build_filtration_custom(model, Γ, classes, :symmetric)
end

"""
    transitive_filtration(model::KripkeModel, Γ::Set{Formula}) -> Filtration

Construct a *transitive filtration* of M through Γ (Theorem 5.18.2, B&D).

R*[u][v] iff C₁(u,v) ∧ C₃(u,v), where:
- C₁: coarsest filtration condition
- C₃: if □A ∈ Γ and M,u ⊩ □A then M,v ⊩ □A; and if ◇A ∈ Γ and M,v ⊩ ◇A then M,u ⊩ ◇A

If M is transitive, then this is a filtration and R* is transitive.
"""
function transitive_filtration(model::KripkeModel, Γ::Set{Formula})
    classes = equivalence_classes(model, Γ)
    _build_filtration_custom(model, Γ, classes, :transitive)
end

function _build_filtration_custom(model::KripkeModel, Γ::Set{Formula},
                                   classes::Vector{Set{Symbol}}, type::Symbol)
    n = length(classes)
    world_to_class = Dict{Symbol,Int}()
    for (i, cls) in enumerate(classes)
        for w in cls
            world_to_class[w] = i
        end
    end

    class_names = [Symbol("c", i) for i in 1:n]
    relation = Pair{Symbol,Symbol}[]

    for i in 1:n
        for j in 1:n
            has_edge = if type == :symmetric
                _c1(model, Γ, classes[i], classes[j]) && _c2(model, Γ, classes[i], classes[j])
            else  # :transitive
                _c1(model, Γ, classes[i], classes[j]) && _c3(model, Γ, classes[i], classes[j])
            end
            if has_edge
                push!(relation, class_names[i] => class_names[j])
            end
        end
    end

    valuation = Dict{Atom,Set{Symbol}}()
    for (atom, true_worlds) in model.valuation
        val_classes = Symbol[]
        for (i, cls) in enumerate(classes)
            if any(w -> w ∈ true_worlds, cls)
                push!(val_classes, class_names[i])
            end
        end
        valuation[atom] = Set{Symbol}(val_classes)
    end

    frame = KripkeFrame(class_names, relation)
    filt_model = KripkeModel(frame, valuation)
    Filtration(model, Γ, classes, filt_model)
end

# C₁(u,v): the coarsest filtration condition (Definition 5.9)
function _c1(model::KripkeModel, Γ::Set{Formula}, class_i::Set{Symbol}, class_j::Set{Symbol})
    _coarsest_edge(model, Γ, class_i, class_j)
end

# C₂(u,v): symmetric of C₁ — swap u and v
function _c2(model::KripkeModel, Γ::Set{Formula}, class_i::Set{Symbol}, class_j::Set{Symbol})
    _coarsest_edge(model, Γ, class_j, class_i)
end

# C₃(u,v): if □A ∈ Γ and M,u ⊩ □A then M,v ⊩ □A; and if ◇A ∈ Γ and M,v ⊩ ◇A then M,u ⊩ ◇A
function _c3(model::KripkeModel, Γ::Set{Formula}, class_i::Set{Symbol}, class_j::Set{Symbol})
    u = first(class_i)
    v = first(class_j)
    for A in Γ
        if A isa Box
            if satisfies(model, u, A) && !satisfies(model, v, A)
                return false
            end
        end
        if A isa Diamond
            if satisfies(model, v, A) && !satisfies(model, u, A)
                return false
            end
        end
    end
    true
end

# ── Filtration Lemma (Theorem 5.5) ──

"""
    filtration_lemma_holds(filt::Filtration) -> Bool

Verify the Filtration Lemma (Theorem 5.5, B&D): for every A ∈ Γ and
every world w, M,w ⊩ A iff M*,[w] ⊩ A.
"""
function filtration_lemma_holds(filt::Filtration)
    world_to_class = Dict{Symbol,Symbol}()
    for (i, cls) in enumerate(filt.classes)
        cname = Symbol("c", i)
        for w in cls
            world_to_class[w] = cname
        end
    end

    for A in filt.Γ
        for w in filt.original.frame.worlds
            orig_val = satisfies(filt.original, w, A)
            filt_val = satisfies(filt.model, world_to_class[w], A)
            if orig_val != filt_val
                return false
            end
        end
    end
    true
end

# ── Finite model property (Definition 5.13) ──

"""
    has_finite_model_property(system::ModalSystem, formula::Formula; max_worlds=4) -> NamedTuple

Look for a *witness* of the finite model property (Definition 5.13, B&D) for
this specific formula: a finite countermodel showing the formula is not
valid in `system`.

Returns `(witnessed, countermodel, world)`:
- `witnessed = true`, with the finite `countermodel::KripkeModel` and
  refuting `world::Symbol` — the FMP instance for this formula is verified.
- `witnessed = missing`, with `countermodel = world = nothing` — no
  countermodel with ≤ `max_worlds` worlds exists. Inconclusive: the formula
  may be valid (in which case FMP holds vacuously) or may only have larger
  countermodels.

This is a bounded computational check — it cannot prove the finite model
property of a *system* (Proposition 5.14, B&D, is a theorem about all
formulas at once); it can only exhibit the finite countermodel for a
formula that has one within the bound.
"""
function has_finite_model_property(system::ModalSystem, formula::Formula; max_worlds=4)
    result = is_entailed_by(system, Formula[], formula; max_worlds=max_worlds)
    if result.entailed === false
        return (witnessed=true, countermodel=result.countermodel, world=result.world)
    end
    (witnessed=missing, countermodel=nothing, world=nothing)
end

# ── Decidability check (Theorem 5.17) ──

"""
    is_decidable_within(system::ModalSystem, formula::Formula; max_worlds=nothing) -> NamedTuple

Check whether `formula` is valid/invalid in `system` by searching for a
countermodel over finite models up to a size bound determined by the
formula's subformulas.

By Proposition 5.12, any filtration has at most 2^n worlds where n = |Γ|,
the subformula count. For systems with the finite model property this makes
validity decidable by searching up to 2^n worlds (Theorem 5.17, B&D). In
practice the search bound is capped at 4 worlds (the O(2^(n²)) enumeration
wall), so the theorem's guarantee applies only when 2^n fits under the cap.

Returns `(valid, bound, subformula_count, countermodel, world)`:
- `valid = false`, with `countermodel`/`world` — a countermodel was found;
  definitive.
- `valid = true` — no countermodel exists within `bound`, **and** the
  searched bound covers the filtration bound 2^n, so by Theorem 5.17 the
  search was exhaustive; definitive.
- `valid = missing` — no countermodel within `bound`, but `bound < 2^n`,
  so the Theorem 5.17 guarantee does not apply; inconclusive.
"""
function is_decidable_within(system::ModalSystem, formula::Formula; max_worlds=nothing)
    Γ = subformulas(formula)
    n = length(Γ)
    # min(2^n, 4) written naively overflows Int64 at n ≥ 63, giving a
    # non-positive bound and a vacuous "valid" verdict (issue #10); the
    # cap is 4 for any n ≥ 2, so never compute 2^n for large n.
    bound = max_worlds === nothing ? (n >= 2 ? 4 : 2^n) : max_worlds

    result = is_entailed_by(system, Formula[], formula; max_worlds=bound)
    if result.entailed === false
        return (valid=false, bound=bound, subformula_count=n,
                countermodel=result.countermodel, world=result.world)
    end
    # No countermodel within bound: exhaustive iff bound covers the 2^n
    # filtration bound (n ≥ 63 would overflow 2^n and can never fit anyway)
    exhaustive = n < 63 && bound >= 2^n
    (valid=exhaustive ? true : missing, bound=bound, subformula_count=n,
     countermodel=nothing, world=nothing)
end
