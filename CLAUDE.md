## Project Description

Gamen.jl — a Julia package for modal logic and game-theoretic reasoning. The name comes from Old English *gamen* (game, sport, joy), the ancestor of the modern word "game."

Supports multiple modal logics: base modal logic (boxes and diamonds), deontic logic, epistemic logic, and temporal logic.

## Julia Version

Requires Julia >= 1.10.

## Package Structure

Follow standard Julia package layout:

- `src/` — package source code
- `test/` — tests using the `Test` stdlib
- `docs/` — documentation built with Documenter.jl
- `notebooks/pluto/` — Pluto notebook demos
- `notebooks/jupyter/` — Jupyter notebook demos

## Coding Conventions

- Follow the [Julia Style Guide](https://docs.julialang.org/en/v1/manual/style-guide/).
- Types use `PascalCase`, functions and variables use `snake_case`.
- Develop as a distributable Julia package (proper `Project.toml`, UUID, etc.).

## Core Abstractions

- **Formulas**: A type hierarchy rooted in an abstract `Formula` type, with concrete types for propositions, negation, conjunction, disjunction, implication, and modal operators (Box, Diamond, and logic-specific variants).
- **Kripke Structures**: Frames (worlds + accessibility relation) and models (frame + valuation function).
- **Operations**: Model checking (truth of a formula at a world), satisfiability checking, and validity checking.

## Testing

- Use the `Test` stdlib with `@testset` and `@test`.
- CI via GitHub Actions using the standard `julia-runtest` workflow.

## Documentation

- Built with [Documenter.jl](https://documenter.juliadocs.org/) and deployed to GitHub Pages.
- Docstrings on all public types and functions.

## Documentation Conventions

- Use Unicode characters (⟨, □, ◇, ⊥, ⊤, ↔, etc.) instead of LaTeX in docs — LaTeX renders as raw text on GitHub.
- Docstrings reference B&D definition numbers (e.g., "Definition 1.7, B&D").
- Avoid `Set` display in doctests — use equality checks or `length()` since iteration order is non-deterministic.

## Notebooks

- Write Pluto notebooks first in `notebooks/pluto/`, one per chapter.
- Generate Jupyter notebooks using: `julia scripts/pluto_to_jupyter.jl notebooks/pluto/<file>.jl`
- Pluto cell IDs use the pattern `NaNbNcNd-XXXX-XXXX-XXXX-XXXXXXXXXXXX`.
- Both formats activate the project with `Pkg.activate(joinpath(@__DIR__, "..", ".."))`.

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

## Resources

- [Boxes and Diamonds](https://bd.openlogicproject.org) — Open access introduction to modal logic from the Open Logic Project
- Local PDF: `notes/bd-screen.pdf`
