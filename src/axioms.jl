# Chapter 3: Axiomatic Derivations (B&D)

# ── Substitution ──

"""
    substitute(φ::Formula, σ) -> Formula

Apply substitution `σ` to formula `φ`, replacing each `Atom` that is a key
in `σ` with the corresponding formula. `σ` should be a
`Dict{Atom, <:Formula}` or similar mapping.
"""
function substitute end

substitute(φ::Bottom, _) = φ
substitute(φ::Atom, σ) = haskey(σ, φ) ? σ[φ] : φ
substitute(φ::Not, σ) = Not(substitute(φ.operand, σ))
substitute(φ::And, σ) = And(substitute(φ.left, σ), substitute(φ.right, σ))
substitute(φ::Or, σ) = Or(substitute(φ.left, σ), substitute(φ.right, σ))
substitute(φ::Implies, σ) = Implies(substitute(φ.antecedent, σ), substitute(φ.consequent, σ))
substitute(φ::Iff, σ) = Iff(substitute(φ.left, σ), substitute(φ.right, σ))
substitute(φ::Box, σ) = Box(substitute(φ.operand, σ))
substitute(φ::Diamond, σ) = Diamond(substitute(φ.operand, σ))

# ── Propositional evaluation ──

"""
    prop_eval(φ::Formula, assignment::Dict{Atom,Bool}) -> Bool

Evaluate a modal-free formula under a truth-value assignment.
"""
function prop_eval end

prop_eval(::Bottom, ::Dict{Atom,Bool}) = false
prop_eval(f::Atom, a::Dict{Atom,Bool}) = a[f]
prop_eval(f::Not, a::Dict{Atom,Bool}) = !prop_eval(f.operand, a)
prop_eval(f::And, a::Dict{Atom,Bool}) = prop_eval(f.left, a) && prop_eval(f.right, a)
prop_eval(f::Or, a::Dict{Atom,Bool}) = prop_eval(f.left, a) || prop_eval(f.right, a)
prop_eval(f::Implies, a::Dict{Atom,Bool}) = !prop_eval(f.antecedent, a) || prop_eval(f.consequent, a)
prop_eval(f::Iff, a::Dict{Atom,Bool}) = prop_eval(f.left, a) == prop_eval(f.right, a)

# ── Tautology checking ──

"""
    is_tautology(φ::Formula) -> Bool

Check whether the modal-free formula `φ` is a propositional tautology,
i.e., true under every truth-value assignment. Throws `ArgumentError`
if `φ` contains modal operators.
"""
function is_tautology(φ::Formula)
    is_modal_free(φ) || throw(ArgumentError("is_tautology requires a modal-free formula"))
    vars = sort(collect(atoms(φ)))
    n = length(vars)
    for i in 0:(2^n - 1)
        assignment = Dict{Atom,Bool}()
        for (j, v) in enumerate(vars)
            assignment[v] = (i >> (j - 1)) & 1 == 1
        end
        if !prop_eval(φ, assignment)
            return false
        end
    end
    return true
end

# ── Tautological instance ──

"""
    is_tautological_instance(φ::Formula) -> Bool

Check whether `φ` is an instance of a propositional tautology
(Definition 3.3, item 1, B&D). Extracts the propositional skeleton
by treating atoms and modal subformulas as propositional variables,
then checks whether the skeleton is a tautology.
"""
function is_tautological_instance(φ::Formula)
    skel, _ = _propositional_skeleton(φ)
    is_tautology(skel)
end

function _propositional_skeleton(φ::Formula)
    leaves = Dict{Formula, Symbol}()
    counter = Ref(0)

    function get_var(f::Formula)
        if !haskey(leaves, f)
            counter[] += 1
            leaves[f] = Symbol("__skel_", counter[])
        end
        return Atom(leaves[f])
    end

    function skel(f::Bottom)
        return f
    end
    function skel(f::Atom)
        return get_var(f)
    end
    function skel(f::Not)
        return Not(skel(f.operand))
    end
    function skel(f::And)
        return And(skel(f.left), skel(f.right))
    end
    function skel(f::Or)
        return Or(skel(f.left), skel(f.right))
    end
    function skel(f::Implies)
        return Implies(skel(f.antecedent), skel(f.consequent))
    end
    function skel(f::Iff)
        return Iff(skel(f.left), skel(f.right))
    end
    function skel(f::Box)
        return get_var(f)
    end
    function skel(f::Diamond)
        return get_var(f)
    end

    result = skel(φ)
    return result, collect(values(leaves))
end

# ── Axiom schemas ──

"""
    AxiomSchema

Abstract type for axiom schemas used in modal proof systems (Section 3.2, B&D).
"""
abstract type AxiomSchema end

"""
    SchemaK <: AxiomSchema

The K axiom schema: □(A → B) → (□A → □B) (Definition 3.5, B&D).
"""
struct SchemaK <: AxiomSchema end

"""
    SchemaDual <: AxiomSchema

The Dual axiom schema: ◇A ↔ ¬□¬A (Definition 3.5, B&D).
"""
struct SchemaDual <: AxiomSchema end

"""
    SchemaT <: AxiomSchema

Schema T: □A → A (Table 3.1, B&D).
"""
struct SchemaT <: AxiomSchema end

"""
    SchemaD <: AxiomSchema

Schema D: □A → ◇A (Table 3.1, B&D).
"""
struct SchemaD <: AxiomSchema end

"""
    SchemaB <: AxiomSchema

Schema B: A → □◇A (Table 3.1, B&D).
"""
struct SchemaB <: AxiomSchema end

"""
    Schema4 <: AxiomSchema

Schema 4: □A → □□A (Table 3.1, B&D).
"""
struct Schema4 <: AxiomSchema end

"""
    Schema5 <: AxiomSchema

Schema 5: ◇A → □◇A (Table 3.1, B&D).
"""
struct Schema5 <: AxiomSchema end

Base.show(io::IO, ::SchemaK) = print(io, "K")
Base.show(io::IO, ::SchemaDual) = print(io, "Dual")
Base.show(io::IO, ::SchemaT) = print(io, "T")
Base.show(io::IO, ::SchemaD) = print(io, "D")
Base.show(io::IO, ::SchemaB) = print(io, "B")
Base.show(io::IO, ::Schema4) = print(io, "4")
Base.show(io::IO, ::Schema5) = print(io, "5")

# ── Sahlqvist correspondence: axiom schema → frame predicate ──

"""
    frame_predicate(schema::AxiomSchema) -> Union{Function, Nothing}

Return the frame property predicate corresponding to `schema` via Sahlqvist
correspondence (BdRV Ch.3, Table 3.1), or `nothing` if the schema imposes
no first-order frame condition.

This mapping is the Sahlqvist table:
- SchemaT  → is_reflexive   (∀x xRx)
- SchemaD  → is_serial      (∀x ∃y xRy)
- SchemaB  → is_symmetric   (∀xy xRy → yRx)
- Schema4  → is_transitive  (∀xyz xRy ∧ yRz → xRz)
- Schema5  → is_euclidean   (∀xyz xRy ∧ xRz → yRz)
"""
frame_predicate(::AxiomSchema)  = nothing
frame_predicate(::SchemaT)      = is_reflexive
frame_predicate(::SchemaD)      = is_serial
frame_predicate(::SchemaB)      = is_symmetric
frame_predicate(::Schema4)      = is_transitive
frame_predicate(::Schema5)      = is_euclidean

"""
    is_instance(φ::Formula, schema::AxiomSchema) -> Bool

Check whether `φ` is an instance of the given axiom `schema`.
"""
function is_instance end

# K: □(A → B) → (□A → □B)
function is_instance(φ::Formula, ::SchemaK)
    φ isa Implies || return false
    φ.antecedent isa Box || return false
    φ.antecedent.operand isa Implies || return false
    φ.consequent isa Implies || return false
    φ.consequent.antecedent isa Box || return false
    φ.consequent.consequent isa Box || return false
    a = φ.antecedent.operand.antecedent
    b = φ.antecedent.operand.consequent
    return φ.consequent.antecedent.operand == a && φ.consequent.consequent.operand == b
end

# Dual: ◇A ↔ ¬□¬A
function is_instance(φ::Formula, ::SchemaDual)
    φ isa Iff || return false
    φ.left isa Diamond || return false
    φ.right isa Not || return false
    φ.right.operand isa Box || return false
    φ.right.operand.operand isa Not || return false
    return φ.left.operand == φ.right.operand.operand.operand
end

# T: □A → A
function is_instance(φ::Formula, ::SchemaT)
    φ isa Implies || return false
    φ.antecedent isa Box || return false
    return φ.antecedent.operand == φ.consequent
end

# D: □A → ◇A
function is_instance(φ::Formula, ::SchemaD)
    φ isa Implies || return false
    φ.antecedent isa Box || return false
    φ.consequent isa Diamond || return false
    return φ.antecedent.operand == φ.consequent.operand
end

# B: A → □◇A
function is_instance(φ::Formula, ::SchemaB)
    φ isa Implies || return false
    φ.consequent isa Box || return false
    φ.consequent.operand isa Diamond || return false
    return φ.antecedent == φ.consequent.operand.operand
end

# 4: □A → □□A
function is_instance(φ::Formula, ::Schema4)
    φ isa Implies || return false
    φ.antecedent isa Box || return false
    φ.consequent isa Box || return false
    φ.consequent.operand isa Box || return false
    return φ.antecedent.operand == φ.consequent.operand.operand
end

# 5: ◇A → □◇A
function is_instance(φ::Formula, ::Schema5)
    φ isa Implies || return false
    φ.antecedent isa Diamond || return false
    φ.consequent isa Box || return false
    φ.consequent.operand isa Diamond || return false
    return φ.antecedent.operand == φ.consequent.operand.operand
end

# ── Modal systems ──

"""
    ModalSystem

A modal proof system defined by a name and a set of axiom schemas
(Definition 3.9, B&D). Every normal modal system includes the K and
Dual axiom schemas; additional schemas determine the specific system.
"""
struct ModalSystem
    name::String
    schemas::Vector{AxiomSchema}
end

Base.show(io::IO, s::ModalSystem) = print(io, s.name)

"""The basic modal system K with axioms K and Dual."""
const SYSTEM_K  = ModalSystem("K",  [SchemaK(), SchemaDual()])
"""KT = K + Schema T (□A → A)."""
const SYSTEM_KT = ModalSystem("KT", [SchemaK(), SchemaDual(), SchemaT()])
"""KD = K + Schema D (□A → ◇A)."""
const SYSTEM_KD = ModalSystem("KD", [SchemaK(), SchemaDual(), SchemaD()])
"""KB = K + Schema B (A → □◇A)."""
const SYSTEM_KB = ModalSystem("KB", [SchemaK(), SchemaDual(), SchemaB()])
"""K4 = K + Schema 4 (□A → □□A)."""
const SYSTEM_K4 = ModalSystem("K4", [SchemaK(), SchemaDual(), Schema4()])
"""K5 = K + Schema 5 (◇A → □◇A)."""
const SYSTEM_K5 = ModalSystem("K5", [SchemaK(), SchemaDual(), Schema5()])
"""S4 = K + T + 4."""
const SYSTEM_S4 = ModalSystem("S4", [SchemaK(), SchemaDual(), SchemaT(), Schema4()])
"""S5 = K + T + 5."""
const SYSTEM_S5 = ModalSystem("S5", [SchemaK(), SchemaDual(), SchemaT(), Schema5()])

# ── Proof steps and derivations ──

"""
    Justification

Abstract type for proof step justifications in a derivation.
"""
abstract type Justification end

"""
    Tautology <: Justification

The formula is a tautological instance (Definition 3.3, item 1, B&D).
"""
struct Tautology <: Justification end

"""
    AxiomInst <: Justification

The formula is an instance of an axiom schema (Definition 3.3, item 2, B&D).
"""
struct AxiomInst <: Justification
    schema::AxiomSchema
end

"""
    ModusPonens <: Justification

The formula follows by modus ponens from two earlier steps (Definition 3.1, B&D).
`minor` is the step index of A; `major` is the step index of A → B.
"""
struct ModusPonens <: Justification
    minor::Int
    major::Int
end

"""
    Necessitation <: Justification

The formula □A follows by necessitation from an earlier step proving A
(Definition 3.2, B&D).
"""
struct Necessitation <: Justification
    step::Int
end

"""
    ProofStep

A single step in a derivation: a formula together with its justification.
"""
struct ProofStep
    formula::Formula
    justification::Justification
end

"""
    Derivation

A derivation (Definition 3.3, B&D): a sequence of proof steps where each
step is justified as a tautological instance, axiom instance, or follows
by modus ponens or necessitation from earlier steps.
"""
struct Derivation
    steps::Vector{ProofStep}
end

"""
    conclusion(d::Derivation) -> Formula

Return the formula proved by the derivation (its last step).
"""
conclusion(d::Derivation) = d.steps[end].formula

# Pretty printing
_justification_str(::Tautology) = "Taut"
_justification_str(j::AxiomInst) = string(j.schema)
_justification_str(j::ModusPonens) = "MP $(j.minor),$(j.major)"
_justification_str(j::Necessitation) = "Nec $(j.step)"

function Base.show(io::IO, d::Derivation)
    for (i, step) in enumerate(d.steps)
        print(io, i, ". ", step.formula, "  [", _justification_str(step.justification), "]")
        i < length(d.steps) && println(io)
    end
end

"""
    is_valid_derivation(system::ModalSystem, deriv::Derivation) -> Bool

Check whether every step in `deriv` is correctly justified in the given
modal `system` (Definition 3.10, B&D).
"""
function is_valid_derivation(system::ModalSystem, deriv::Derivation)
    for (i, step) in enumerate(deriv.steps)
        _is_valid_step(system, deriv.steps, i, step) || return false
    end
    return true
end

function _is_valid_step(system::ModalSystem, steps::Vector{ProofStep}, i::Int, step::ProofStep)
    j = step.justification
    if j isa Tautology
        return is_tautological_instance(step.formula)
    elseif j isa AxiomInst
        return j.schema in system.schemas && is_instance(step.formula, j.schema)
    elseif j isa ModusPonens
        (1 <= j.minor < i && 1 <= j.major < i) || return false
        a = steps[j.minor].formula
        cond = steps[j.major].formula
        cond isa Implies || return false
        return cond.antecedent == a && cond.consequent == step.formula
    elseif j isa Necessitation
        (1 <= j.step < i) || return false
        step.formula isa Box || return false
        return step.formula.operand == steps[j.step].formula
    end
    return false
end

# ── Dual formulas ──

"""
    dual(φ::Formula) -> Formula

Compute the dual of formula `φ` (Definition 3.26, B&D). The dual swaps
⊥ ↔ ⊤, ∧ ↔ ∨, and □ ↔ ◇. Atoms are negated, and ¬ distributes through
the dual. The key property is that ⊢ A ↔ ¬(dual(A)).
"""
function dual end

dual(::Bottom) = Not(Bottom())
dual(f::Atom) = Not(f)
dual(f::Not) = Not(dual(f.operand))
dual(f::And) = Or(dual(f.left), dual(f.right))
dual(f::Or) = And(dual(f.left), dual(f.right))
dual(f::Implies) = And(Not(dual(f.antecedent)), dual(f.consequent))
dual(f::Iff) = Or(
    And(Not(dual(f.left)), dual(f.right)),
    And(Not(dual(f.right)), dual(f.left))
)
dual(f::Box) = Diamond(dual(f.operand))
dual(f::Diamond) = Box(dual(f.operand))
