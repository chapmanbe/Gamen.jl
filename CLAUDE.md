# Gamen.jl — Claude Code Instructions

## Project Description

Gamen.jl — a Julia package for modal logic and game-theoretic reasoning. The name comes from Old English *gamen* (game, sport, joy), the ancestor of the modern word "game."

Supports multiple modal logics: base modal logic (boxes and diamonds), deontic logic, epistemic logic, and temporal logic.

## Julia Version

Requires Julia >= 1.10.

## Package Structure

Follow standard Julia package layout:

- `src/` — package source code
- `ext/` — package extensions (e.g., `GamenMakieExt` for visualization)
- `test/` — tests using the `Test` stdlib
- `docs/` — documentation built with Documenter.jl
- `notebooks/pluto/` — Pluto notebook demos
- `notebooks/jupyter/` — Jupyter notebook demos
- `notebooks/Project.toml` — separate environment for notebooks (includes CairoMakie, GraphMakie, Graphs)

## Coding Conventions

- Follow the [Julia Style Guide](https://docs.julialang.org/en/v1/manual/style-guide/).
- Types use `PascalCase`, functions and variables use `snake_case`.
- Develop as a distributable Julia package (proper `Project.toml`, UUID, etc.).

## Architectural Principles

These principles exist to ensure the package generalizes beyond the specific examples in B&D. Always apply them — do not optimize for the current example at the expense of generality.

- **Parametric frame conditions**: Frame conditions (reflexivity, transitivity, symmetry, seriality, Euclideanness, etc.) must be represented as first-class constraints on the accessibility relation, never hardcoded into proof procedures or model checkers.
- **Separation of concerns** (following Fitting's tableau decomposition):
  - **Syntax** — formula representation (type hierarchy)
  - **Semantics** — Kripke frame + valuation, always parametric
  - **Frame conditions** — axioms as constraints passed as data, not baked into logic
  - **Proof procedure** — tableau/sequent rules that call into frame conditions
- **Generality over examples**: Implementations must work for an arbitrary modal logic, not only the one currently illustrated in B&D. When implementing from a specific example, ask: *would this still work if the frame conditions changed?* If not, refactor before proceeding.
- **Logic variants as configurations**: Deontic, epistemic, and temporal logics should be expressible as configurations of the base system (specific frame conditions + operator aliases), not as parallel reimplementations.

## **Known Architectural Gap (Future Work)** 

`ModalSystem` (Hilbert-style axiomatics) and `TableauSystem` (proof procedure) are currently separate objects that share the same Sahlqvist table but are not automatically connected. A future step would allow `TableauSystem` to be derived from a `ModalSystem` via the Sahlqvist correspondence. This requires careful design — do not attempt to connect them without a written plan approved first.

## Core Abstractions

- **Formulas**: A type hierarchy rooted in an abstract `Formula` type, with concrete types for propositions, negation, conjunction, disjunction, implication, and modal operators (Box, Diamond, and logic-specific variants).
- **Kripke Structures**: Frames (worlds + accessibility relation) and models (frame + valuation function).
- **Operations**: Model checking (truth of a formula at a world), satisfiability checking, and validity checking.

## ⚠️ Performance Constraints

Frame enumeration in `is_decidable_within`, `is_derivable_from`, and `is_consistent` is **O(2^(n²))**. **Never increase `max_worlds` beyond 4.**

| max_worlds | Frames enumerated |
|------------|-------------------|
| 4          | 2^16 = 65,536 ✓  |
| 5          | 2^25 = 33 million ⚠️ |
| 16         | 2^256 = will exhaust all memory 💀 |

This is a fundamental complexity bound, not a bug to be fixed. Do not attempt to optimize around it by increasing the limit.

## Testing

- Use the `Test` stdlib with `@testset` and `@test`.
- CI via GitHub Actions using the standard `julia-runtest` workflow.
- **Known slow test:** The `Decidability (Theorem 5.17)` testset in Chapter 5 takes ~80 seconds due to exhaustive model enumeration. This is expected.
- All 399 tests pass.

## Documentation

- Built with [Documenter.jl](https://documenter.juliadocs.org/) and deployed to GitHub Pages.
- Docstrings on all public types and functions.

## Documentation Conventions

- Use Unicode characters (⟨, □, ◇, ⊥, ⊤, ↔, etc.) instead of LaTeX in docs — LaTeX renders as raw text on GitHub.
- Docstrings reference B&D definition numbers (e.g., "Definition 1.7, B&D").
- Avoid `Set` display in doctests — use equality checks or `length()` since iteration order is non-deterministic.

## Visualization

- `visualize_model` is only available via the `GamenMakieExt` package extension.
- **Never call `visualize_model` in core `src/` code** — it must only appear in extension, notebook, or documentation contexts where `CairoMakie`, `GraphMakie`, and `Graphs` are explicitly loaded.

## Notebooks

- Write Pluto notebooks first in `notebooks/pluto/`, one per chapter.
- Generate Jupyter notebooks using: `julia scripts/pluto_to_jupyter.jl notebooks/pluto/<file>.jl`
- Pluto cell IDs use the pattern `NaNbNcNd-XXXX-XXXX-XXXX-XXXXXXXXXXXX`.
- Both formats activate the notebooks environment with `Pkg.activate(joinpath(@__DIR__, ".."))`.
- Visualization (`visualize_model`) requires `using CairoMakie, GraphMakie, Graphs` — loaded via the `GamenMakieExt` package extension.

## Chapter Implementation Workflow

When implementing a new B&D chapter:

1. Read relevant PDF pages from `notes/bd-screen.pdf`
2. Create `src/<chapter_name>.jl` with implementations and docstrings
3. Add exports to `src/Gamen.jl`
4. Add tests to `test/runtests.jl` (organized by chapter testset)
5. Update `docs/src/book_reference.md` with definition → implementation mapping
6. Update `docs/src/api.md` with new docstring references
7. Update `docs/src/tutorial.md` with examples
8. Run doctests: `julia --project=docs docs/make.jl`
9. Run tests: `julia --project -e 'using Test, Gamen; include("test/runtests.jl")'`
10. Create Pluto notebook: `notebooks/pluto/chN_<name>.jl`
11. Generate Jupyter notebook: `julia scripts/pluto_to_jupyter.jl notebooks/pluto/chN_<name>.jl`
12. Commit implementation first, then commit notebooks separately

## Key References

- **Box and Diamonds (B&D)**: Primary textbook driving implementation. Local PDF at `notes/bd-screen.pdf`. Online: [bd.openlogicproject.org](https://bd.openlogicproject.org)
- **Fitting (1999)**: "Tableau Methods for Modal and Temporal Logics" (in *Handbook of Tableau Methods*) — canonical algorithmic reference for proof procedures; descriptions are close to pseudocode and generalize cleanly.
- **Blackburn, de Rijke & Venema (2001)**: *Modal Logic* (Cambridge) — Ch. 1 (parametric semantics, general frames), Ch. 3 (frame conditions as first-class objects, Sahlqvist correspondence), Ch. 4 (completeness and canonical models).
- **Gasquet et al. (2014)**: *Kripke's Worlds* (Birkhäuser) — explicitly about building modal logic tools; useful for generic architecture and the LoTREC prover design.
