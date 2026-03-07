# Julia Packages for Formal Logic and Lisp-Like Programming

A curated list of Julia packages relevant to formal logic, automated
reasoning, logic programming, symbolic systems, category theory, and
Lisp-style exploration.

------------------------------------------------------------------------

## Core Symbolic Logic & Term Rewriting

### Symbolics.jl

Computer algebra system in pure Julia.\
Symbolic expressions, transformation, and modeling.\
https://github.com/JuliaSymbolics/Symbolics.jl

### SymbolicUtils.jl

High-performance term rewriting and symbolic pattern matching.\
https://github.com/JuliaSymbolics/SymbolicUtils.jl

### Metatheory.jl

Equality saturation, e-graphs, and equational reasoning.\
https://github.com/JuliaSymbolics/Metatheory.jl

------------------------------------------------------------------------

## SAT / SMT / Automated Reasoning

### Z3.jl

Bindings to the Z3 SMT solver.\
https://github.com/zenna/Z3.jl

### SMTLib.jl

SMT-LIB construction and solver interfacing.\
https://github.com/zenna/SMTLib.jl

### Satisfiability.jl

Boolean satisfiability experimentation.\
https://github.com/dpsanders/Satisfiability.jl

------------------------------------------------------------------------

## Logic Programming (Prolog-Style)

### Julog.jl

Lightweight Prolog-style logic programming in Julia.\
https://github.com/ztangent/Julog.jl

### Suiron.jl

Minimal rule-based inference engine.\
https://github.com/IndrajeetPatil/Suiron.jl

### HerbSWIPL.jl

Julia interface to SWI-Prolog.\
https://github.com/Herb-AI/HerbSWIPL.jl

------------------------------------------------------------------------

## Sole Logic Ecosystem

### SoleLogics.jl

Propositional and modal logic, parsing, model checking.\
https://github.com/aclai-lab/SoleLogics.jl

### SoleReasoners.jl

Analytic tableau reasoning and automated theorem proving.\
https://github.com/aclai-lab/SoleReasoners.jl

### Sole.jl

Logic-based symbolic modeling framework.\
https://github.com/aclai-lab/Sole.jl

------------------------------------------------------------------------

## Lambda Calculus & Functional Foundations

### LambdaCalculus.jl

Representation and reduction of lambda terms.\
https://github.com/TotalVerb/LambdaCalculus.jl

### MLStyle.jl

Algebraic pattern matching for Julia.\
https://github.com/thautwarm/MLStyle.jl

------------------------------------------------------------------------

## Category-Theoretic & Structural Logic

### Catlab.jl

Applied category theory, algebraic theories, and string diagrams.\
https://github.com/AlgebraicJulia/Catlab.jl

### AlgebraicPetri.jl

Categorical Petri nets and compositional transition systems.\
https://github.com/AlgebraicJulia/AlgebraicPetri.jl

------------------------------------------------------------------------

## Algebraic Foundations

### AbstractAlgebra.jl

Algebraic structures including rings and fields.\
https://github.com/Nemocas/AbstractAlgebra.jl

### Oscar.jl

Commutative algebra and algebraic geometry system.\
https://github.com/oscar-system/Oscar.jl

------------------------------------------------------------------------

## Graphs & Structural Models

### Graphs.jl

Graph algorithms and data structures (useful for Kripke frames,
dependency graphs).\
https://github.com/JuliaGraphs/Graphs.jl

------------------------------------------------------------------------

## Parsing & DSL Construction

### ParserCombinator.jl

Parser combinators for custom formal languages.\
https://github.com/andrewcooke/ParserCombinator.jl

### CombinedParsers.jl

Efficient parser combinator library.\
https://github.com/gkappler/CombinedParsers.jl

------------------------------------------------------------------------

# Lisp-Like & Lisp-Oriented Packages

### LispSyntax.jl

Lisp-style S-expression syntax frontend for Julia.\
https://github.com/swadey/LispSyntax.jl

### MacroTools.jl

AST rewriting utilities for macro programming.\
https://github.com/FluxML/MacroTools.jl

### ExprTools.jl

Utilities for working with Julia expressions.\
https://github.com/invenia/ExprTools.jl

------------------------------------------------------------------------

# Minimal Stack for a Julia-Based Logic & Lisp Lab

Suggested core stack:

-   SymbolicUtils.jl
-   Metatheory.jl
-   Julog.jl
-   SoleLogics.jl
-   Z3.jl
-   Catlab.jl
-   LispSyntax.jl
-   MacroTools.jl
