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
| `tableaux.jl` | Table 6.4 (`TABLEAU_KB`) | adversarial review + sntownsend | 2026-07-10 | ⚠ → ✓ | Constant wrongly included T□/T◇ rules, proving KT-theorems in KB; docstring and an old test also stated B as `□p → ◇□p` (a KTB theorem) instead of `p → □◇p`. sntownsend confirmed the correct axiom. [#10](https://github.com/chapmanbe/Gamen.jl/issues/10) §C1 |
| `tableaux.jl` | Ch. 6 blocking (Goré §6.6) | adversarial review + sntownsend | 2026-07-09 | ⚠ → ✓ | Subset-at-birth, engine-global, sticky blocking made plain-K tableaux incomplete. Reworked by JC (852c392): ancestor-equality, per-system `uses_blocking`, recomputed per rule application. Repros re-verified 2026-07-10. [#10](https://github.com/chapmanbe/Gamen.jl/issues/10) §C2 |
| `tableaux.jl` | Def 6.2 (`is_closed`) | adversarial review + sntownsend | 2026-07-10 | ⚠ → ✓ | `σ T ⊥` did not close a branch (`⊥ → p` unprovable). sntownsend: closing on T ⊥ equals the standard closure condition since ⊥ ≡ φ∧¬φ. [#10](https://github.com/chapmanbe/Gamen.jl/issues/10) §C3 |
| `frame_properties.jl`, `axioms.jl`, `filtrations.jl` | Ch. 2/3/5 enumeration | adversarial review | 2026-07-10 | ⚠ → ✓ | Int64 overflow in `is_valid_on_frame`/`is_tautology`/`is_decidable_within` made ≥63-bit enumerations vacuously return "valid". Now guarded (`ArgumentError`) or computed without `2^n`. [#10](https://github.com/chapmanbe/Gamen.jl/issues/10) §C4 |
| `epistemic.jl` | Def 15.6 (`common_knowledge`) | adversarial review + sntownsend | 2026-07-10 | ⚠ → ✓ | BFS seeded with the evaluation world computed the *reflexive*-transitive closure. sntownsend: no difference under veridicality (reflexive frames); code now matches Def 15.6 exactly, a no-op on reflexive frames. [#10](https://github.com/chapmanbe/Gamen.jl/issues/10) §C5 |
| `temporal.jl`, `tableaux.jl` | Ch. 14 (temporal tableaux) | adversarial review + sntownsend | 2026-07-10 | ⚠ → ✓ | 𝐇/𝐏/`Since`/`Until` were silently treated as atoms (Kt-valid `p → 𝐆(𝐏p)` unprovable). Per sntownsend: B&D provides *no* temporal tableau rules; the 𝐆/𝐅 rules are by-analogy and now flagged as unsourced; unsupported operators throw. Extension quarantined pending a published source. [#10](https://github.com/chapmanbe/Gamen.jl/issues/10) §C6 |
| `temporal.jl` | Def 14.5 (`Since`/`Until`) | adversarial review + sntownsend | 2026-07-10 | ⚠ → ✓ | Endpoints were unconditionally exempted from the ∀-range. sntownsend ruled: B&D leaves ≺ free to be reflexive or not, so endpoints are in range exactly when the frame puts them there; exemptions removed. [#10](https://github.com/chapmanbe/Gamen.jl/issues/10) |
| `tableaux.jl`, `semantics.jl`, `completeness.jl`, `filtrations.jl`, `axioms.jl`, `temporal.jl` | Chs. 1–6, 14 (positive battery) | adversarial review | 2026-07-08 | ✓ | Confirmed correct under hostile testing: standard theorem/non-theorem battery, canonical accessibility direction, finest/coarsest filtrations + filtration lemma, local consequence (Def 3.36), Sahlqvist table, H/P converse direction, no branch aliasing. See `notes/adversarial-review-2026-07-08.md` §7. |

---

## Reviewer Notes

*Space for narrative check-in summaries. Add entries when a reviewer posts a broader assessment beyond a single issue.*

### sntownsend — 2026-04-25

Five issues filed covering: world-existence guard in `satisfies`, key-type consistency for `substitute` and `atoms`, naming confusion in `is_derivable_from`, and a design question about `is_instance` for `SchemaDual`. Issues #3, #4, #7 addressed and confirmed fixed. Issues #5 and #6 remain open pending discussion.

### sntownsend — 2026-07-09/10 (issue #10 adjudication)

Ruled on the adversarial-review findings: (1) T rules out of `TABLEAU_KB`, B axiom is `p → □◇p`; (2) blocking reworked to ancestor-equality (implemented in 852c392); (3) close branches on `σ T ⊥`; (4) common knowledge — under veridicality (reflexive R) transitive and reflexive-transitive closures coincide, so the Def 15.6 alignment is safe; (5) B&D presents no temporal tableau rules — the 𝐆/𝐅 rules were built by analogy, quarantine further temporal tableau work until a published source is adopted; (6) `Since`/`Until` endpoints follow ≺ with no exemption, since B&D deliberately leaves reflexivity of ≺ open.

---

## Status Key

| Symbol | Meaning |
|--------|---------|
| ✓ | Confirmed correct (or fixed and re-confirmed) |
| ⚠ open | Issue identified, not yet resolved |
| ⚠ → ✓ | Issue identified, fixed, awaiting reviewer re-confirmation |
| — | Not yet reviewed |
