# Design note: Tableau rule parametrization over operator pairs

*Written 2026-07-13 (Phase 2 gated half, per `plans/adversarial-review-refactor.md`
task 6). Requires Brian's explicit approval before implementation — this is
the CLAUDE.md-gated step that touches the `ModalSystem` ↔ `TableauSystem`
boundary. Findings addressed: review §A2 (verbatim temporal rule copies) and
§F7 (engine hardcodes temporal dispatch).*

## Problem

1. **Verbatim rule copies.** `src/temporal.jl:~215–395` duplicates eight base
   tableau rules (`apply_futurebox_true/false`, `apply_futurediamond_true/false`,
   `apply_temporal_T_*`, `apply_temporal_4_*`), each differing from its
   `tableaux.jl` original *only* in the type guard (`isa Box` → `isa FutureBox`).
2. **Engine knows about temporal.** The "base" engine hardcodes temporal
   dispatch in three places: `_try_priority1_rules` (𝐆T/𝐅F), Priority 2a
   (`FutureBox`+`FalseSign`), Priority 2b (`FutureDiamond`+`TrueSign`). A base
   system like `TABLEAU_K` therefore silently *applies temporal rules* if fed a
   temporal formula, whether or not the system means to support 𝐆/𝐅.
3. **Hand-built constants drift.** §C1 (the KB unsoundness bug) happened
   because `TABLEAU_KB` was assembled by hand while the correct rule set
   already existed in `tableau_rules(::SchemaB)`. Nothing ties the constants
   to the schemas they claim to embody.

## Proposed design

### 1. Operator pairs as data

```julia
struct OperatorPair
    box::DataType       # e.g. Box, FutureBox — the universal operator
    diamond::DataType   # e.g. Diamond, FutureDiamond — its existential dual
end

const BASE_PAIR     = OperatorPair(Box, Diamond)
const TEMPORAL_PAIR = OperatorPair(FutureBox, FutureDiamond)
```

`TableauSystem` gains a field:

```julia
struct TableauSystem
    name::Symbol
    operator_pairs::Vector{OperatorPair}   # NEW — default [BASE_PAIR]
    used_prefix_rules::Vector{Function}
    witness_rules::Vector{Function}
    uses_blocking::Bool
end
```

`TABLEAU_K…TABLEAU_S5` declare `[BASE_PAIR]`; `TABLEAU_KDt` declares
`[BASE_PAIR, TEMPORAL_PAIR]` (it is the combined deontic-temporal system used
by the ext notebooks).

### 2. Rules take the pair as an argument

Each of the four K-shape rules and the six frame-condition rule families
becomes a single generic function with the operator type read from the pair:

```julia
function apply_box_true_rule(pf, branch, pair::OperatorPair)
    pf.sign isa TrueSign && pf.formula isa pair.box || return NoRule()
    …unchanged body…
end
```

The eight temporal copies in `temporal.jl` are **deleted**. The engine loops
over `system.operator_pairs` at the three dispatch sites instead of
hardcoding `Box`/`FutureBox` cases; `system.used_prefix_rules` /
`witness_rules` keep their current one-argument closure signature by storing
`pf, branch -> apply_T_box_rule(pf, branch, pair)` partial applications built
at system-construction time (so the engine loop shape does not change).

Semantic invariant: **zero behavior change** for every existing system on
every existing input. The 706-test battery plus the ext notebook are the net.

### 3. Unsupported operators become errors, not silent no-ops

`_check_tableau_supported` currently hardcodes the quarantine list (𝐇/𝐏/
Since/Until). It becomes pair-aware: a modal operator whose type appears in
no `operator_pair` of the system throws the same `ArgumentError` the
quarantine already uses. Concretely: feeding `FutureBox` formulas to plain
`TABLEAU_K` stops silently applying 𝐆-rules (current behavior, arguably a
bug) and instead reports that K has no rules for 𝐆. The temporal quarantine
(Jeremiah's ruling, issue #10) is **unchanged**: no pair for 𝐇/𝐏/Since/Until
exists, so they throw exactly as today.

### 4. Deriving system constants from schemas (the ModalSystem ↔ TableauSystem question)

Two options; recommendation below.

**Option A (recommended): derivation constructor + equivalence tests.**

```julia
TableauSystem(ms::ModalSystem; operator_pairs=[BASE_PAIR])
```

maps each `AxiomSchema` in `ms.schemas` to its rule set via the existing
per-schema `tableau_rules(::SchemaX)` functions (already correct — §C1 showed
the *hand-built constant*, not the schema mapping, was wrong), and sets
`uses_blocking = true` iff the schema set includes `Schema4` (transitivity —
the settled criterion from the 852c392 blocking rework; temporal transitivity
is declared explicitly by `TABLEAU_KDt`, which is hand-assembled either way
since B&D provides no temporal schema objects). The eight existing constants
are then **defined as derivations** (`const TABLEAU_KT =
TableauSystem(SYSTEM_KT)`), and a new testset asserts the derived rule lists
match the current hand-built ones function-for-function before the
definitions are switched over. This makes a §C1-style drift structurally
impossible.

**Option B (fallback): parametrization only.** Keep hand-built constants;
land only §§1–3. Loses the drift protection; keeps this PR smaller.

The Sahlqvist table shared by `ModalSystem` and `TableauSystem` already
encodes the correspondence — Option A does not *add* theory, it removes the
hand-copied middle step. This note is the written plan CLAUDE.md requires
for exactly that connection; approving Option A approves connecting them
through `tableau_rules(::AxiomSchema)` **only** (no reverse derivation, no
automatic frame-condition synthesis).

## Explicitly unchanged / out of scope

- **Blocking design** (852c392): ancestor-equality, per-system flag,
  recomputed per rule application. `uses_blocking` stays a per-system Bool;
  it is not made per-pair (KDt is the only multi-pair system and needs it).
- **Temporal quarantine**: no rules for 𝐇/𝐏/Since/Until until a published
  rule set is adopted. This refactor makes adding them *later* a matter of
  declaring a pair + citing the source, but adds none now.
- **Priority structure** (1 → 2a → 2b → 2c) and the Fitting-style prefix
  discipline: untouched.

## Testing plan

- Equivalence testset: for each existing constant, derived-vs-hand-built rule
  list identity (Option A) or unchanged behavior battery (Option B).
- Regression: `TABLEAU_K` + `FutureBox` input → `ArgumentError` (new,
  documents the intended behavior change from §3 — the only visible change).
- Full 706-test suite + `notebooks/theory/pluto/ext_deontic_temporal.jl`
  smoke run (KDt exercises both pairs).

## Open questions for Brian / Jeremiah

1. Option A (derive constants, equivalence-tested) vs Option B
   (parametrize only)? Recommendation: **A**.
2. §3's behavior change: is throwing on 𝐆-formulas in plain `TABLEAU_K` the
   right call (my reading: yes — matches the C6 precedent of "no silent
   treatment of unsupported operators"), or should base systems keep
   silently applying temporal rules?
3. Should `OperatorPair` be exported (users could define, e.g., an epistemic
   pair for a future K_a tableau) or internal until a second consumer exists?
   Recommendation: internal (`_OperatorPair` not exported) until the
   epistemic tableau question is actually on the table.
