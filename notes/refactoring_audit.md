# Gamen.jl Architectural Audit and Refactoring

**Date:** 2026-03-10
**Scope:** `src/tableaux.jl`, `src/completeness.jl`, `src/axioms.jl`
**References:** B&D Ch.6, BdRV Ch.1/3/4, Fitting (1999)

---

## Theoretical Grounding

The three BdRV chapters, together with B&D Ch.6, establish a single unified principle:

> **Everything is parameterized by frame conditions; frame conditions are first-class data, not hardcoded logic.**

- **BdRV Ch.1** (Def. 1.11–1.23): A modal logic is parameterized by a *similarity type* τ = (O, ρ). A τ-frame carries one accessibility relation R_△ per operator △. Nothing about the frame is fixed in advance.
- **BdRV Ch.3** (Def. 3.1–3.5, Sahlqvist): Axiom schemas *correspond* to first-order frame conditions via a computable algorithm. T ↔ reflexivity, D ↔ seriality, B ↔ symmetry, 4 ↔ transitivity, 5 ↔ euclideanness — entries in a table, not branches in an `if` chain.
- **BdRV Ch.4** (Def. 4.18, canonicity): The canonical model for Λ has exactly the frame properties corresponding to Λ's axioms. Same table as Ch.3.
- **B&D Ch.6** (Tables 6.1–6.3): The tableau rules for extended systems encode frame conditions directly. A `TableauSystem` is a *configuration* of which frame-condition rules to include, not a named case.

---

## Audit: What Was Wrong

### Site 1: `src/tableaux.jl` — `TableauSystem` was a name tag

```julia
struct TableauSystem
    name::Symbol          # the ONLY field
end
```

All system-specific behavior recovered by matching this symbol in three functions:

| Function | Hardcoding |
|:---------|:-----------|
| `_try_priority1_rules` | `sys == :S5`, `sys ∈ (:KT,:KB,:S4,:S5)`, `sys ∈ (:KB,:S5)`, `sys ∈ (:K4,:S4,:S5)`, `sys == :S5` |
| `_apply_all_rules` | `system.name == :KD` (priority-2c block) |
| `_try_new_prefix_rules` | `system.name == :KD` |

Additionally, `apply_box_true_rule`, `apply_diamond_true_rule`, and `apply_diamond_false_rule` carried an `all_prefixes::Bool` parameter existing solely as a proxy for "is this S5?" — a frame-condition concern leaked into rule-application functions.

### Site 2: `src/completeness.jl` — `_frame_filter` was a hardcoded dispatch table

```julia
function _frame_filter(system::ModalSystem)
    for schema in system.schemas
        if schema isa SchemaT     → is_reflexive
        elseif schema isa SchemaD → is_serial
        elseif schema isa SchemaB → is_symmetric
        elseif schema isa Schema4 → is_transitive
        elseif schema isa Schema5 → is_euclidean
        end
    end
    ...
end
```

Adding a new schema required editing this function. The schema→frame-predicate mapping should be declared on the schema type, not in a consumer function.

### Site 3: `src/axioms.jl` — `AxiomSchema` subtypes carried no frame information

`SchemaT`, `SchemaD`, etc. knew only their syntactic form (`is_instance`). The frame predicate they correspond to was known only to `_frame_filter` in a different file. The data should travel with the type.

---

## The Sahlqvist Table (spine of the correct architecture)

| Axiom Schema | Frame condition | Frame predicate | Tableau rules (used-prefix) | Tableau rules (witness) |
|:------------|:----------------|:----------------|:----------------------------|:------------------------|
| K, Dual | — | `nothing` | `[]` | `[]` |
| SchemaT | ∀x Rxx | `is_reflexive` | T□, T◇ | `[]` |
| SchemaD | ∀x ∃y Rxy | `is_serial` | `[]` | D□, D◇ |
| SchemaB | ∀xy Rxy→Ryx | `is_symmetric` | B□, B◇ | `[]` |
| Schema4 | ∀xyz Rxy∧Ryz→Rxz | `is_transitive` | 4□, 4◇ | `[]` |
| Schema5 | ∀xyz Rxy∧Rxz→Ryz | `is_euclidean` | 4T□, 4T◇ | `[]` |

---

## Refactoring Plan

### Step A: Declare the Sahlqvist correspondence on `AxiomSchema`

**Files:** `src/axioms.jl` (frame predicates), `src/tableaux.jl` (tableau rules)

Add dispatch functions:

```julia
# axioms.jl
frame_predicate(::AxiomSchema)  = nothing
frame_predicate(::SchemaT)      = is_reflexive
frame_predicate(::SchemaD)      = is_serial
frame_predicate(::SchemaB)      = is_symmetric
frame_predicate(::Schema4)      = is_transitive
frame_predicate(::Schema5)      = is_euclidean

# tableaux.jl
tableau_rules(::AxiomSchema)  = Function[]
tableau_rules(::SchemaT)      = Function[apply_T_box_rule, apply_T_diamond_rule]
tableau_rules(::SchemaB)      = Function[apply_B_box_rule, apply_B_diamond_rule]
tableau_rules(::Schema4)      = Function[apply_4_box_rule, apply_4_diamond_rule]
tableau_rules(::Schema5)      = Function[apply_4T_box_rule, apply_4T_diamond_rule]

tableau_witness_rules(::AxiomSchema)  = Function[]
tableau_witness_rules(::SchemaD)      = Function[apply_D_box_rule, apply_D_diamond_rule]
```

**Test impact:** Pure addition, zero behavior change.

### Step B: Simplify `_frame_filter` in `completeness.jl`

Replace 15-line if-elseif chain:

```julia
function _frame_filter(system::ModalSystem)
    checks = filter(!isnothing, frame_predicate.(system.schemas))
    isempty(checks) ? (_ -> true) : (frame -> all(c -> c(frame), checks))
end
```

**Test impact:** Behavior identical.

### Step C: Replace `TableauSystem.name` dispatch with explicit rule vectors

Replace:
```julia
struct TableauSystem
    name::Symbol
end
```

With:
```julia
struct TableauSystem
    name::Symbol                        # retained for display only
    used_prefix_rules::Vector{Function} # priority-1 frame-condition rules
    witness_rules::Vector{Function}     # priority-2c witness-creation rules
end
```

Declarative constants:
```julia
const TABLEAU_K  = TableauSystem(:K,  Function[], Function[])
const TABLEAU_KT = TableauSystem(:KT, Function[apply_T_box_rule, apply_T_diamond_rule], Function[])
const TABLEAU_KD = TableauSystem(:KD, Function[], Function[apply_D_box_rule, apply_D_diamond_rule])
const TABLEAU_KB = TableauSystem(:KB, Function[apply_T_box_rule, apply_T_diamond_rule,
                                               apply_B_box_rule, apply_B_diamond_rule], Function[])
const TABLEAU_K4 = TableauSystem(:K4, Function[apply_4_box_rule, apply_4_diamond_rule], Function[])
const TABLEAU_S4 = TableauSystem(:S4, Function[apply_T_box_rule, apply_T_diamond_rule,
                                               apply_4_box_rule, apply_4_diamond_rule], Function[])
const TABLEAU_S5 = TableauSystem(:S5, Function[apply_T_box_rule,  apply_T_diamond_rule,
                                               apply_B_box_rule,  apply_B_diamond_rule,
                                               apply_4_box_rule,  apply_4_diamond_rule,
                                               apply_4T_box_rule, apply_4T_diamond_rule], Function[])
```

`_try_priority1_rules` becomes a loop:
```julia
function _try_priority1_rules(pf, branch, system)
    r = apply_propositional_rule(pf, branch)
    r isa NoRule || return r
    r = apply_box_true_rule(pf, branch)
    r isa NoRule || return r
    r = apply_diamond_false_rule(pf, branch)
    r isa NoRule || return r
    for rule in system.used_prefix_rules
        r = rule(pf, branch)
        r isa NoRule || return r
    end
    NoRule()
end
```

`_try_witness_rules` replaces `_try_new_prefix_rules`:
```julia
function _try_witness_rules(pf, branch, system)
    for rule in system.witness_rules
        r = rule(pf, branch)
        r isa NoRule || return r
    end
    NoRule()
end
```

`all_prefixes::Bool` removed from `apply_box_true_rule`, `apply_diamond_true_rule`,
`apply_diamond_false_rule` — S5 works correctly through its rule vector alone.

**Pre-check:** grep confirmed `TableauSystem(...)` only appears in the seven constants, not in tests.
**Test impact:** Zero — public API (`TABLEAU_K` etc.) unchanged.

---

## Results

All three steps executed sequentially, tests run after each:

| Step | Files changed | Tests |
|:-----|:-------------|:------|
| A | `src/axioms.jl`, `src/tableaux.jl`, `src/Gamen.jl` | 436/436 ✓ |
| B | `src/completeness.jl` | 436/436 ✓ |
| C | `src/tableaux.jl` | 436/436 ✓ |

### Net effect

- `_frame_filter`: 15-line if-elseif → 2 lines
- `_try_priority1_rules`: 48-line Symbol-matching → 8-line loop
- `_apply_all_rules` priority-2c block: `system.name == :KD` check → `!isempty(system.witness_rules)` check
- `all_prefixes::Bool`: eliminated from 3 rule function signatures
- Adding a new modal logic: requires only new `ModalSystem(name, schemas)` and `TableauSystem(name, rules, witness_rules)` — **no edits to any function body**

---

## What Was Not Done (by design)

`tableau_rules` and `tableau_witness_rules` are exported but the `TABLEAU_*` constants are built by hand rather than derived from `SYSTEM_*` schemas. `ModalSystem` (Hilbert-style) and `TableauSystem` (proof procedure) are separate objects that happen to share the same Sahlqvist table. Automatically deriving a `TableauSystem` from a `ModalSystem` is a possible future step but was not required by CLAUDE.md and needs careful design.
