# ADR-0001: Parametrize tableau rules over operator pairs

**Date:** 2026-07-13 (proposed) / 2026-07-14 (accepted)
**Status:** Accepted — Option A (Brian Chapman, 2026-07-14)
**Deciders:** Brian Chapman, Jeremiah Chapman

## Context

The 2026-07-08 adversarial review found that `src/temporal.jl` duplicates
eight base tableau rules verbatim (differing only in `isa Box` → `isa
FutureBox` type guards) and that the "base" tableau engine hardcodes temporal
dispatch in three places (§A2/§F7). Separately, the §C1 KB-unsoundness bug
was caused by a hand-built `TABLEAU_KB` constant drifting from the correct
`tableau_rules(::SchemaB)` mapping that already existed. Repo `CLAUDE.md`
forbids connecting `ModalSystem` and `TableauSystem` without a written,
approved plan — this ADR is the approval gate for that plan.

## Decision

**Accepted 2026-07-14: Option A**, with one addition prompted by the gamen-hs
comparison (its `closeForSystem` is a second hand-maintained encoding of the
axiom→frame-condition mapping): audit Gamen.jl for any second encoding of
per-system frame metadata and fold what is found into the derivation.
Findings of that audit: (a) `completeness.jl` already derives its frame
checks from schemas via `frame_predicate` — clean; (b) the `EPISTEMIC_*`
condition lists hand-copied the Sahlqvist table — now derived via
`EpistemicSystem(name, ::ModalSystem)`; (c) `extract_countermodel` applies
*no* per-system frame closure (the gap is the inverse of gamen-hs's drift
risk) — documented as a caveat and left as flagged future work; the new
`TableauSystem.schemas` metadata field is the single source that closure
will derive from. Sub-questions resolved per the design note's
recommendations: unsupported operators throw (Q2 yes), `OperatorPair` stays
internal/unexported (Q3 yes).

Original proposal (full design: `plans/tableau-parametrization.md`): add
`operator_pairs::Vector{OperatorPair}` to `TableauSystem`, make each rule
generic over the pair, delete the temporal copies, and make unsupported modal
operators throw the same `ArgumentError` as the existing temporal quarantine.
Recommended Option A additionally derives the `TABLEAU_*` constants from
`ModalSystem` schemas via `tableau_rules(::AxiomSchema)`, with
equivalence tests against the current hand-built rule lists before the
switch — making §C1-style drift structurally impossible. Three sub-questions
for the deciders are listed at the end of the design note.

## Consequences

Easier: adding a sourced temporal (or future epistemic) tableau becomes
declaring a pair; system constants cannot drift from their schemas (Option
A). Harder/accepted: `TableauSystem` construction gains one concept
(operator pairs); one visible behavior change — plain `TABLEAU_K` throws on
𝐆-formulas instead of silently applying temporal rules. The blocking design
(852c392) and the 𝐇/𝐏/Since/Until quarantine are explicitly unchanged.
