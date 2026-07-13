# Generic formula traversal protocol.
#
# Every structural operation on formulas (equality, hashing, collecting
# atoms, subformulas, substitution, modal-freeness) is derived from a
# two-method protocol — `children` and `similar_node` — instead of being
# hand-written per constructor. This removes the N×M matrix of per-type
# methods that made variant logics (temporal, epistemic) crash Ch. 4/5
# machinery with `MethodError` (issue #10 §M9) and restores reflexivity of
# `==` for subtypes that forget to define it (§M2).
#
# The default implementations use field reflection and assume, for each
# concrete `Formula` subtype:
#   1. every subformula is stored in a field whose *value* is a `Formula`
#      (fields like `Knowledge.agent::Symbol` are treated as node data), and
#   2. the type is constructible positionally from its fields in
#      declaration order.
# All in-repo formula types satisfy both. A subtype that does not (e.g. one
# storing children in a `Vector`) must override `children` and
# `similar_node` — everything else then follows.

"""
    children(φ::Formula) -> Tuple{Vararg{Formula}}

Return the immediate subformulas of `φ`, in field-declaration order.
Leaves (`Atom`, `Bottom`) return `()`.

Together with [`similar_node`](@ref) this is the traversal protocol from
which `atoms`, `subformulas`, `substitute`, `is_modal_free`, and structural
`==`/`hash` are derived generically. New `Formula` subtypes get all of these
for free; override only for types whose subformulas are not stored directly
in `Formula`-valued fields.
"""
function children(φ::Formula)
    out = Formula[]
    for i in 1:fieldcount(typeof(φ))
        v = getfield(φ, i)
        v isa Formula && push!(out, v)
    end
    Tuple(out)
end

"""
    similar_node(φ::Formula, new_children::Tuple) -> Formula

Rebuild a node of the same type as `φ` around `new_children`, preserving
all non-`Formula` fields (e.g. the agent of a `Knowledge` node). The number
of new children must equal `length(children(φ))`.
"""
function similar_node(φ::Formula, new_children::Tuple)
    T = typeof(φ)
    args = Vector{Any}(undef, fieldcount(T))
    k = 0
    for i in 1:fieldcount(T)
        v = getfield(φ, i)
        if v isa Formula
            k += 1
            k <= length(new_children) ||
                throw(ArgumentError("similar_node: $(nameof(T)) needs more children than the $(length(new_children)) given"))
            args[i] = new_children[k]
        else
            args[i] = v
        end
    end
    k == length(new_children) ||
        throw(ArgumentError("similar_node: $(nameof(T)) takes $k children, got $(length(new_children))"))
    T(args...)
end

# ── Structural equality and hashing ──
#
# Replaces the former `==(::Formula, ::Formula) = false` catch-all, which
# made any subtype lacking an explicit `==` unequal to itself (§M2), plus
# nine hand-written `==`/`hash` pairs. Two formulas are equal iff they have
# the same type and all fields (node data and children alike) are equal.

function Base.:(==)(a::Formula, b::Formula)
    typeof(a) === typeof(b) || return false
    for i in 1:fieldcount(typeof(a))
        getfield(a, i) == getfield(b, i) || return false
    end
    true
end

function Base.hash(φ::Formula, h::UInt)
    h = hash(typeof(φ), h)
    for i in 1:fieldcount(typeof(φ))
        h = hash(getfield(φ, i), h)
    end
    h
end

# ── Generic structural derivations ──

"""
    atoms(f::Formula) -> Set{Atom}

Collect all propositional variables (as `Atom` values) appearing in a formula.
"""
atoms(φ::Formula) = _atoms!(Set{Atom}(), φ)

function _atoms!(out::Set{Atom}, φ::Formula)
    if φ isa Atom
        push!(out, φ)
    else
        for c in children(φ)
            _atoms!(out, c)
        end
    end
    out
end

"""
    subformulas(φ::Formula) -> Set{Formula}

Return the set of all subformulas of `φ`, including `φ` itself.
"""
subformulas(φ::Formula) = _subformulas!(Set{Formula}(), φ)

function _subformulas!(out::Set{Formula}, φ::Formula)
    push!(out, φ)
    for c in children(φ)
        _subformulas!(out, c)
    end
    out
end

"""
    substitute(φ::Formula, σ) -> Formula

Apply substitution `σ` to formula `φ`, replacing each `Atom` that is a key
in `σ` with the corresponding formula. `σ` should be a
`Dict{Atom, <:Formula}` or similar mapping. Atoms not in `σ` are left
unchanged; all other nodes are rebuilt around their substituted children.
"""
substitute(φ::Atom, σ) = haskey(σ, φ) ? σ[φ] : φ

function substitute(φ::Formula, σ)
    cs = children(φ)
    isempty(cs) && return φ
    similar_node(φ, map(c -> substitute(c, σ), cs))
end

"""
    is_modal_free(f::Formula) -> Bool

Return `true` if the formula contains no modal operators. `Box` and
`Diamond` (and the temporal/epistemic operators, via their own methods) are
modal; every other node is modal-free iff all its children are.
"""
is_modal_free(::Box) = false
is_modal_free(::Diamond) = false
is_modal_free(φ::Formula) = all(is_modal_free, children(φ))
