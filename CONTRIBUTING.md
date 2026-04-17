# Contributing to Gamen.jl

Thank you for your interest in contributing to Gamen.jl!

## Getting Started

1. Fork the repository and clone your fork
2. Install Julia 1.10 or later
3. Activate the project environment:
   ```julia
   using Pkg
   Pkg.activate(".")
   Pkg.instantiate()
   ```
4. Run the test suite to verify your setup:
   ```julia
   Pkg.test()
   ```

## Types of Contributions

- **Bug reports** — open an issue with a minimal reproducing example
- **New logic implementations** — Gamen.jl follows *Boxes and Diamonds* chapter-by-chapter; contributions extending to additional chapters or applied logics are welcome
- **Notebook improvements** — corrections, additional exercises, or new domain-application notebooks
- **Documentation** — typo fixes, improved docstrings, or tutorial content

## Development Guidelines

- Follow the [Julia Style Guide](https://docs.julialang.org/en/v1/manual/style-guide/)
- Types use `PascalCase`, functions and variables use `snake_case`
- Reference B&D definition numbers in docstrings (e.g., "Definition 1.7, B&D")
- Use Unicode characters (□, ◇, ⊥, ⊤, →) instead of LaTeX in documentation
- Domain knowledge belongs in data files, not in code (Buchanan's separation principle)
- Add tests for new functionality in `test/runtests.jl`

## Running Tests

```julia
julia --project -e 'using Test, Gamen; include("test/runtests.jl")'
```

Note: The Chapter 5 decidability tests take ~80 seconds due to exhaustive model enumeration. This is expected.

## Building Documentation

```julia
julia --project=docs docs/make.jl
```

## Notebooks

- Write Pluto notebooks in `notebooks/pluto/`
- Generate Jupyter versions: `julia scripts/pluto_to_jupyter.jl notebooks/pluto/<file>.jl`
- Notebooks use a separate environment (`notebooks/Project.toml`)

## Code of Conduct

We are committed to providing a welcoming and inclusive environment. Please be respectful and constructive in all interactions.

## Questions?

Open an issue or reach out to the maintainers.
