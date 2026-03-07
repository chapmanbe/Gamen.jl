# Gamen.jl

```@raw html
<div style="text-align: center;">
  <img src="assets/logo.svg" width="240" alt="Gamen.jl logo" style="margin-bottom: 1em;">
</div>
```

*A Julia package for modal logic and game-theoretic reasoning.*

The name comes from Old English *gamen* (game, sport, joy), the ancestor of the modern word "game."

## Overview

Gamen.jl provides tools for working with modal logics, following the presentation in
[**Boxes and Diamonds: An Open Introduction to Modal Logic**](https://bd.openlogicproject.org) by Richard Zach (Open Logic Project).

The package supports:

- **Formula construction** with a type-safe representation of propositional and modal formulas
- **Kripke semantics** with frames, models, and accessibility relations
- **Model checking** to determine truth of formulas at worlds
- **Frame definability** -- frame properties and their correspondence with modal schemas
- **Multiple modal logics** (planned): base modal logic, deontic, epistemic, and temporal logic

## Installation

```julia
using Pkg
Pkg.add("Gamen")
```

## Quick Start

```jldoctest
julia> using Gamen

julia> p = Atom(:p); q = Atom(:q);

julia> Box(Implies(p, q))
□(p → q)

julia> frame = KripkeFrame([:w1, :w2], [:w1 => :w2]);

julia> model = KripkeModel(frame, [:p => [:w1, :w2], :q => [:w2]]);

julia> satisfies(model, :w1, Diamond(q))
true

julia> satisfies(model, :w1, Box(q))
true
```

## Textbook

This package implements concepts from:

> Richard Zach, *[Boxes and Diamonds: An Open Introduction to Modal Logic](https://bd.openlogicproject.org)*, Open Logic Project, 2019+.

See the [Book Reference](@ref) page for a detailed mapping of definitions and propositions to their implementations.
