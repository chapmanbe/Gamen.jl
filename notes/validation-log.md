# Validation Log — Gamen.jl

This log records completed validation work by external reviewers, keyed to B&D sections and source modules. It complements the GitHub issue tracker (which records defects) by preserving positive confirmation that specific logic is correct. The log is citable for the JOSE submission.

**How to use:**
- When a module section passes review with no issues, add a ✓ row.
- When a review finds a problem, add a ⚠ row referencing the GitHub issue, then update to ✓ once fixed and re-confirmed.
- Keep one row per (module × B&D section × reviewer) pairing. Add a new row if the same section is re-reviewed after a significant change.

---

## Validation Table

| Module | B&D Reference | Reviewer | Date | Result | Notes / Linked Issues |
|--------|---------------|----------|------|--------|----------------------|
| `semantics.jl` | Def 1.7 (`satisfies`) | sntownsend | 2026-04-25 | ⚠ → ✓ | `satisfies` returned nonsense for non-worlds. Fixed by adding world-existence check. [#3](https://github.com/chapmanbe/Gamen.jl/issues/3) |
| `axioms.jl` | Ch. 3 (`substitute`) | sntownsend | 2026-04-25 | ⚠ → ✓ | `substitute` used `Dict{Symbol,<:Formula}`; changed to `Dict{Atom,<:Formula}` for consistency with valuation key type. [#4](https://github.com/chapmanbe/Gamen.jl/issues/4) |
| `axioms.jl` | Ch. 3 (`SchemaDual`, `is_instance`) | sntownsend | 2026-04-25 | ⚠ open | Reviewer suggests accepting both orderings of `◇A ↔ ¬□¬A`. Under discussion — see [#5](https://github.com/chapmanbe/Gamen.jl/issues/5). |
| `completeness.jl` | Def 3.36 (`is_derivable_from`) | sntownsend | 2026-04-25 | ⚠ open | Function name implies syntactic derivation but implementation is semantic. Rename to `is_entailed_by` pending. [#6](https://github.com/chapmanbe/Gamen.jl/issues/6) |
| `frame_properties.jl` | Ch. 1 (`atoms`) | sntownsend | 2026-04-25 | ⚠ → ✓ | `atoms` returned `Set{Symbol}` (names); changed to `Set{Atom}` for consistency. [#7](https://github.com/chapmanbe/Gamen.jl/issues/7) |

---

## Reviewer Notes

*Space for narrative check-in summaries. Add entries when a reviewer posts a broader assessment beyond a single issue.*

### sntownsend — 2026-04-25

Five issues filed covering: world-existence guard in `satisfies`, key-type consistency for `substitute` and `atoms`, naming confusion in `is_derivable_from`, and a design question about `is_instance` for `SchemaDual`. Issues #3, #4, #7 addressed and confirmed fixed. Issues #5 and #6 remain open pending discussion.

---

## Status Key

| Symbol | Meaning |
|--------|---------|
| ✓ | Confirmed correct (or fixed and re-confirmed) |
| ⚠ open | Issue identified, not yet resolved |
| ⚠ → ✓ | Issue identified, fixed, awaiting reviewer re-confirmation |
| — | Not yet reviewed |
