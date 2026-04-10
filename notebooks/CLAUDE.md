# Gamen.jl Notebooks — Claude Code Instructions

## Purpose

Interactive Pluto notebooks for learning and exploring modal logic. Two parallel tracks:

1. **B&D track** — notebooks accompanying each chapter of *Boxes and Diamonds* (Zach 2025), using Gamen.jl to make the textbook's definitions, examples, and exercises interactive.
2. **Health track** — parallel notebooks that apply the same logic concepts to clinical scenarios (guideline validation, deontic reasoning about treatment obligations, temporal sequencing of clinical actions).

Each B&D chapter notebook has a corresponding health application notebook. They share the same logical foundations but differ in motivation and examples.

## Technology

- **Pluto.jl** — reactive notebooks (not Jupyter). Pluto's reactivity means students can modify a formula or model and see all dependent results update automatically.
- **PlutoUI.jl** — interactive widgets (sliders, dropdowns, checkboxes, text inputs) bound to Julia variables via `@bind`.
- **Gamen.jl** — the logic engine (formulas, Kripke models, tableau prover, etc.)
- **CairoMakie + GraphMakie + Graphs** — Kripke model visualization via `GamenMakieExt`
- **Pure Julia** — no Python, no external services. Everything runs locally.

## Notebook Naming Convention

```
notebooks/pluto/
  ch1_syntax_and_semantics.jl           # B&D Chapter 1
  ch1_health_clinical_obligations.jl    # Health parallel for Chapter 1
  ch2_frame_definability.jl             # B&D Chapter 2
  ch2_health_guideline_properties.jl    # Health parallel for Chapter 2
  ...
```

Existing B&D notebooks (ch1 through ch6, ch14, ch15) were created before this convention. Health parallels should be created alongside them.

## Environment

All notebooks activate the shared notebooks environment:

```julia
begin
    using Pkg
    Pkg.activate(joinpath(@__DIR__, ".."))
    using Gamen
end
```

The `notebooks/Project.toml` includes Gamen.jl (via local path), CairoMakie, GraphMakie, and Graphs. Add PlutoUI to this environment:

```
PlutoUI
```

## Pluto Cell IDs

Pluto cell IDs follow the pattern `NaNbNcNd-XXXX-XXXX-XXXX-XXXXXXXXXXXX` (established in CLAUDE.md at project root).

## Notebook Structure

Each notebook should follow this general structure:

### B&D track notebooks

1. **Title and overview** — which B&D chapter, what concepts are covered
2. **Setup cell** — activate environment, import packages
3. **Concept introduction** — markdown explaining the definition/theorem, referencing B&D definition numbers
4. **Interactive exploration** — Gamen.jl code with PlutoUI widgets letting students:
   - Build and modify formulas
   - Construct Kripke models (add/remove worlds, toggle accessibility)
   - Evaluate truth at worlds and see results update reactively
   - Run tableau provers with adjustable parameters
   - Visualize models with `visualize_model`
5. **Exercises** — prompted exploration tasks matching B&D exercises

### Health track notebooks

1. **Title and clinical scenario** — what clinical domain, which guidelines
2. **Setup cell** — same environment
3. **Clinical motivation** — why this logic matters for healthcare (reference Lomotan et al. 2010 for deontic interpretation, ACC/AHA guidelines for examples)
4. **Formalization** — translate clinical language ("must," "should," "before") into modal logic step by step, using widgets to let students experiment with the encoding
5. **Analysis** — run consistency checks, explore what happens when guidelines conflict
6. **Discussion** — implications for EHR implementation, clinical decision support

## Clinical Examples by Chapter

| B&D Chapter | Logic Concepts | Health Application |
|-------------|---------------|-------------------|
| Ch 1: Syntax & Semantics | Formulas, Kripke models, truth | Clinical obligations as Box/Diamond; "must prescribe" vs "may consider" |
| Ch 2: Frame Definability | Frame properties, validity | Seriality (D axiom) = obligations must be achievable; reflexivity in treatment protocols |
| Ch 3: Axiomatic Derivations | Hilbert-style proofs, modal systems | KD as the logic of clinical guidelines; why K alone is insufficient |
| Ch 4: Completeness | Canonical models, completeness | What completeness means for guideline validation — if no proof of inconsistency, a model exists |
| Ch 5: Filtrations | Finite model property, decidability | Decidability guarantees for automated guideline checking |
| Ch 6: Tableaux | Automated proving, consistency | Automated conflict detection in guideline pairs; `tableau_consistent` on real guidelines |
| Ch 14: Temporal Logic | G, F, H, P operators | "Before," "after," "always," "eventually" in clinical sequencing |
| Ch 15: Epistemic Logic | Knowledge, common knowledge | What clinicians know vs what the EHR system knows; information asymmetry |

## Data Sources for Health Notebooks

- `~/Code/Julia/guideline-validation/data/guidelines.yaml` — formalized ACC/AHA cholesterol guidelines
- `~/Code/Julia/guideline-validation/data/conflict_test.yaml` — intentionally conflicting guideline pairs
- `~/Code/Julia/guideline-validation/data/temporal_guidelines.yaml` — guidelines with temporal constraints
- `~/Code/Julia/guideline-validation/data/statin_rules.yaml` — ACC/AHA 2018 production rules
- Lomotan et al. (2010) — "How 'Should' We Write Guideline Recommendations?" (deontic term interpretation study)
- ACC/AHA 2018 Cholesterol Guidelines (Grundy et al. 2018)

## Widget Design Principles

- **Progressive disclosure** — start simple (pick a formula from a dropdown), allow complexity (type custom formulas)
- **Immediate feedback** — every widget change should visibly update results (Pluto reactivity handles this)
- **Side-by-side comparison** — show formal logic alongside clinical English so students see the correspondence
- **Error as learning** — let students construct inconsistent guideline sets and see the tableau close, then understand why

## Dependencies

The `notebooks/Project.toml` must include:

```toml
[deps]
CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
Gamen = "d58aead4-12fe-4bc4-9bd9-a7dede724567"
GraphMakie = "1ecd5474-83a3-4783-bb4f-06765db800d2"
Graphs = "86223c79-3864-5bf0-83f7-82e725a168b6"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
```

PlutoUI needs to be added (not currently in Project.toml).
