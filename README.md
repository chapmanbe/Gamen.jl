<p align="center">
  <img src="logo.svg" height="120" alt="Gamen.jl logo">
</p>

<h1 align="center">Gamen.jl</h1>

<p align="center">
  <em>Modal logic and game-theoretic reasoning in Julia</em>
</p>

<p align="center">
  <a href="https://bd.openlogicproject.org">
    <img src="https://img.shields.io/badge/textbook-Boxes%20%26%20Diamonds-blue" alt="Boxes and Diamonds">
  </a>
  <a href="https://chapmanbe.github.io/Gamen.jl/notebooks/">
    <img src="https://img.shields.io/badge/notebooks-browse%20online-orange" alt="Browse Notebooks">
  </a>
  <a href="https://mybinder.org/v2/gh/chapmanbe/Gamen.jl/main?urlpath=pluto">
    <img src="https://mybinder.org/badge_logo.svg" alt="Launch Binder">
  </a>
</p>

---

The name comes from Old English *gamen* (game, sport, joy), the ancestor of the modern word "game."

Gamen.jl is a Julia package for working with [modal logic](https://en.wikipedia.org/wiki/Modal_logic), following the presentation in [**Boxes and Diamonds: An Open Introduction to Modal Logic**](https://bd.openlogicproject.org) by Richard Zach (Open Logic Project). It provides type-safe formula construction, Kripke semantics, model checking, frame definability, proof systems, completeness, and filtrations.

## Features

- **Formula construction** — a full type hierarchy for propositional and modal formulas (`Atom`, `Not`, `And`, `Or`, `Implies`, `Iff`, `Box`, `Diamond`)
- **Kripke semantics** — frames, models, accessibility relations, and the satisfaction relation M, w &#8873; A
- **Model checking** — determine truth of formulas at worlds, in models, and across classes of models
- **Frame definability** — test frame properties (reflexive, symmetric, transitive, serial, euclidean) and verify correspondence with modal schemas (T, D, B, 4, 5)
- **Standard translation** — translate modal formulas into first-order logic
- **Axiomatic derivations** — substitution, tautology checking, axiom schemas, Hilbert-style proof checker
- **Modal systems** — K, KT, KD, KB, K4, K5, S4, S5
- **Completeness** — canonical model construction, Truth Lemma, Lindenbaum's Lemma
- **Filtrations** — finest, coarsest, symmetric, and transitive filtrations; finite model property; decidability
- **Modal tableaux** — prefixed signed tableau system for K, KT, KD, KB, K4, S4, S5; soundness and completeness
- **Visualization** — render Kripke models as directed graphs (optional, via CairoMakie)

## Installation

```julia
using Pkg
Pkg.add("Gamen")
```

Visualization support requires loading CairoMakie, GraphMakie, and Graphs:

```julia
using Gamen, CairoMakie, GraphMakie, Graphs
visualize_model(model)
```

## Quick Start

```julia
using Gamen

# Build formulas (Definition 1.2, B&D)
p = Atom(:p)
q = Atom(:q)
schema_k = Implies(Box(Implies(p, q)), Implies(Box(p), Box(q)))  # □(p→q) → (□p→□q)

# Create a Kripke model (Definition 1.6, B&D -- Figure 1.1)
frame = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w1 => :w3])
model = KripkeModel(frame, [:p => [:w1, :w2], :q => [:w2]])

# Model checking (Definition 1.7, B&D)
satisfies(model, :w1, Diamond(q))   # true  -- w2 is accessible and q holds there
satisfies(model, :w1, Box(q))       # false -- w3 is accessible but q fails there
satisfies(model, :w3, Box(Bottom())) # true  -- vacuously, w3 has no successors
```

## Frame Definability (Chapter 2)

```julia
s4_frame = KripkeFrame([:w1, :w2, :w3],
    [:w1 => :w1, :w2 => :w2, :w3 => :w3,
     :w1 => :w2, :w2 => :w3, :w1 => :w3])

is_reflexive(s4_frame)   # true
is_transitive(s4_frame)  # true

# Schema T (□p → p) is valid on reflexive frames (Proposition 2.5, B&D)
is_valid_on_frame(s4_frame, Implies(Box(p), p))  # true
```

| Schema | Formula | Frame Property |
|:-------|:--------|:---------------|
| **T** | `□p → p` | Reflexive |
| **D** | `□p → ◇p` | Serial |
| **B** | `p → □◇p` | Symmetric |
| **4** | `□p → □□p` | Transitive |
| **5** | `◇p → □◇p` | Euclidean |

## Axiomatic Derivations (Chapter 3)

```julia
# Check if a formula is derivable in a modal system
is_derivable_from(SYSTEM_KT, Formula[], Implies(Box(p), p))  # true
is_derivable_from(SYSTEM_K,  Formula[], Implies(Box(p), p))  # false

# Verify a Hilbert-style derivation
proof = [
    ProofStep(Tautology(), Implies(p, p)),
    ProofStep(Necessitation(1), Box(Implies(p, p))),
]
is_valid_derivation(SYSTEM_K, proof)  # true
```

## Completeness (Chapter 4)

```julia
# Build the canonical model for K over a finite language
cm = canonical_model(SYSTEM_K, [p, Box(p)])

# Verify the Truth Lemma: M^K, Δ ⊩ A iff A ∈ Δ
truth_lemma_holds(cm)  # true
```

## Filtrations and Decidability (Chapter 5)

```julia
# Build a filtration — collapses worlds that agree on all formulas in Γ
Γ = subformula_closure(Implies(Box(p), p))
filt = finest_filtration(model, Γ)   # fewest edges
filt = coarsest_filtration(model, Γ) # most edges

# Filtration Lemma: truth is preserved
filtration_lemma_holds(filt)  # true

# Check validity within a bounded search (decidability)
is_decidable_within(SYSTEM_K, Implies(Box(p), p)).valid  # false -- not K-valid
```

## Modal Tableaux (Chapter 6)

```julia
# Check derivability by tableau (prefixed signed formulas)
tableau_proves(TABLEAU_K, Formula[], Implies(And(Box(p), Box(q)), Box(And(p, q))))  # true
tableau_proves(TABLEAU_K, Formula[], Implies(Box(p), p))   # false -- not K-valid
tableau_proves(TABLEAU_KT, Formula[], Implies(Box(p), p))  # true  -- T axiom

# Multiple modal systems
tableau_proves(TABLEAU_K4, Formula[], Implies(Box(p), Box(Box(p))))  # true  -- 4 axiom
tableau_proves(TABLEAU_S5, Formula[], Implies(Diamond(p), Box(Diamond(p))))  # true  -- 5 axiom

# Consistency checking
tableau_consistent(TABLEAU_K,  Formula[Box(p), Not(p)])   # true  -- satisfiable in K
tableau_consistent(TABLEAU_KT, Formula[Box(p), Not(p)])   # false -- □p → p in KT
```

| System | Rules | Frame Property |
|:-------|:------|:---------------|
| `TABLEAU_K`  | K | (none) |
| `TABLEAU_KT` | K + T□, T◇ | Reflexive |
| `TABLEAU_KD` | K + D□, D◇ | Serial |
| `TABLEAU_KB` | K + B□, B◇ | Symmetric |
| `TABLEAU_K4` | K + 4□, 4◇ | Transitive |
| `TABLEAU_S4` | K + T□, T◇, 4□, 4◇ | Reflexive + transitive |
| `TABLEAU_S5` | K + T□, T◇, 4□, 4◇, 4T□, 4T◇ | Reflexive + transitive + euclidean |

## Textbook Coverage

| Chapter | Topic | Status |
|:--------|:------|:-------|
| 1 | Syntax and Semantics | ✓ Complete |
| 2 | Frame Definability | ✓ Complete |
| 3 | Axiomatic Derivations | ✓ Complete |
| 4 | Completeness and Canonical Models | ✓ Complete |
| 5 | Filtrations and Decidability | ✓ Complete |
| 6 | Modal Tableaux | ✓ Complete |
| Part IV | Applied Modal Logics | Coming soon |

## Project Structure

```
src/
  Gamen.jl              # Module definition and exports
  formulas.jl           # Formula type hierarchy
  kripke.jl             # Kripke frames and models
  semantics.jl          # Satisfaction, truth, validity, entailment
  frame_properties.jl   # Frame properties and frame validity (Ch2)
  fol.jl                # First-order logic and standard translation (Ch2)
  axioms.jl             # Axiom schemas, modal systems, derivations (Ch3)
  completeness.jl       # Canonical models, Truth Lemma (Ch4)
  filtrations.jl        # Filtrations, FMP, decidability (Ch5)
  tableaux.jl           # Prefixed tableau proof system (Ch6)
ext/
  GamenMakieExt/        # Optional visualization (CairoMakie + GraphMakie)
test/
  runtests.jl           # Test suite (553 tests)
docs/                   # Documenter.jl documentation
notebooks/
  Project.toml          # Notebook environment (includes visualization deps)
  pluto/                # B&D textbook companion notebooks
  health/               # Health application notebooks
  jupyter/              # Jupyter notebook versions
```

## Notebooks

Two parallel tracks of interactive notebooks:

### B&D Textbook Companion (`notebooks/pluto/`)

| Notebook | Topic |
|:---------|:------|
| `ch0_propositional_logic` | Propositional logic review |
| `ch1_syntax_and_semantics` | Formulas, models, model checking |
| `ch2_frame_definability` | Frame properties and correspondence |
| `ch3_axiomatic_derivations` | Proof systems and derivations |
| `ch4_completeness` | Canonical models and completeness |
| `ch5_filtrations` | Filtrations, FMP, and decidability |
| `ch6_tableaux` | Modal tableaux and proof search |

### Health Applications (`notebooks/health/`)

| Notebook | Topic |
|:---------|:------|
| `ch0_health_clinical_rules` | MYCIN, clinical production rules |
| `ch1_health_clinical_obligations` | Guideline obligations as □/◇ |
| `ch2_health_guideline_properties` | Frame properties for guidelines |
| `ch3_health_deontic_systems` | KD as the logic of clinical guidelines |
| `ch4_health_completeness` | Trusting consistency results |
| `ch5_health_decidability` | Decidability for guideline checking |
| `ch6_health_conflict_detection` | Automated guideline conflict detection |

Open with [Pluto.jl](https://github.com/fonsp/Pluto.jl):

```julia
using Pluto
Pluto.run(notebook="notebooks/pluto/ch5_filtrations.jl")
```

Or use the Jupyter versions in `notebooks/jupyter/`.

## Acknowledgment

This package implements concepts from:

> Richard Zach, *[Boxes and Diamonds: An Open Introduction to Modal Logic](https://bd.openlogicproject.org)*, Open Logic Project, Fall 2025. Licensed under [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).

The mathematical definitions, theorems, and proof structures follow B&D closely. The Julia implementation (code, docstrings, tests, and notebooks) is original work.

## License

The Gamen.jl source code is released under the [MIT License](LICENSE).

The textbook *Boxes and Diamonds* on which this package is based is © Richard Zach / Open Logic Project, licensed under CC BY 4.0.
