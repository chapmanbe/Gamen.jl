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

## Notebooks

Demonstrations should be implemented in parallel as both Pluto and Jupyter notebooks, covering:

- Basic usage and formula construction
- Building and querying Kripke models
- Examples for each logic variant (deontic, epistemic, temporal)
- Interactive exploration of modal reasoning

## Resources

- [Boxes and Diamonds](https://bd.openlogicproject.org) — Open access introduction to modal logic from the Open Logic Project
