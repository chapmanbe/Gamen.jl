# Gamen.jl Notebooks — Claude Code Instructions

## Purpose

Interactive Pluto notebooks for learning and exploring modal logic. Two parallel tracks:

1. **B&D track** — notebooks accompanying each chapter of *Boxes and Diamonds* (Zach 2025), using Gamen.jl to make the textbook's definitions, examples, and exercises interactive.
2. **Health track** — parallel notebooks that apply the same logic concepts to clinical scenarios (guideline validation, deontic reasoning about treatment obligations, temporal sequencing of clinical actions).

Each B&D chapter notebook has a corresponding health application notebook. They share the same logical foundations but differ in motivation and examples.

## Target Audience

The primary audience is **health informatics graduate students** — adult learners (clinicians, data analysts, public health practitioners) with no prior formal logic background. Secondary audience includes undergraduate/graduate students in logic, philosophy, and CS.

This means every notebook must:
- **Earn the student's attention** before diving into definitions. Address the skeptic: "Why do I need this? Can't an LLM do it?" (B&D track) or "Why does a surgeon/nurse need formal logic?" (Health track)
- **Ground abstract concepts in concrete examples** before introducing formalism
- **Provide hands-on exercises** — adult learners need to do, not just read

## Technology

- **Pluto.jl** — reactive notebooks (not Jupyter). Pluto's reactivity means students can modify a formula or model and see all dependent results update automatically.
- **PlutoUI.jl** — interactive widgets (sliders, dropdowns, checkboxes, text inputs) bound to Julia variables via `@bind`.
- **Gamen.jl** — the logic engine (formulas, Kripke models, tableau prover, etc.)
- **CairoMakie + GraphMakie + Graphs** — Kripke model visualization via `GamenMakieExt`
- **Pure Julia** — no Python, no external services. Everything runs locally.

## Notebook Directory Structure

The two tracks live in separate directories under `notebooks/`, sharing the same environment (`notebooks/Project.toml`):

```
notebooks/
  Project.toml                          # Shared environment (Gamen, CairoMakie, etc.)
  pluto/                                # B&D track — textbook companion notebooks
    ch0_propositional_logic.jl
    ch1_syntax_and_semantics.jl
    ch2_frame_definability.jl
    ...
    ext_deontic_temporal.jl             # Extension: combined logics
  health/                               # Health track — clinical application notebooks
    ch0_health_clinical_rules.jl
    ch1_health_clinical_obligations.jl
    ch2_health_guideline_properties.jl
    ...
    ext_health_guideline_conflicts.jl   # Extension: guideline conflicts
```

## Environment and Imports

All notebooks activate the shared notebooks environment:

```julia
begin
    using Pkg
    Pkg.activate(joinpath(@__DIR__, ".."))
    using Gamen
end
```

**CRITICAL: Use `import` not `using` for CairoMakie/GraphMakie/Graphs.** Both Gamen and Makie export `Box` and `Bottom`, causing ambiguity errors with `using`. `import` loads the packages (triggering the `GamenMakieExt` extension) without polluting the namespace:

```julia
begin
    using Pkg
    Pkg.activate(joinpath(@__DIR__, ".."))
    using Gamen
    import CairoMakie, GraphMakie, Graphs
end
```

The `notebooks/Project.toml` includes Gamen.jl (via local path), CairoMakie, GraphMakie, and Graphs.

## Pluto Cell IDs

Pluto cell IDs follow the pattern `NaNbNcNd-XXXX-XXXX-XXXX-XXXXXXXXXXXX` (established in CLAUDE.md at project root).

## Pluto Markdown Rendering Rules

Pluto's markdown renderer has quirks that affect how content displays:

- **Inline LaTeX at line endings causes line breaks.** Do NOT write `$W$:` at the end of a line — Pluto inserts a newline between the LaTeX and the colon. Instead, restructure as a complete sentence: "A nonempty set of worlds $W$" rather than "$W$: a nonempty set of worlds."
- **Use Unicode (□, ◇, ¬, ∧, ∨, →, ⊩) instead of LaTeX** for modal operators in prose. LaTeX like `$\square$` can cause line-splitting. Unicode renders reliably.
- **Admonitions with multiline content**: Use `md"single line"` (not `md"""multiline"""`) inside `Markdown.Admonition`. Triple-quoted strings nested inside `$()` interpolation within an outer `md"""..."""` cause parse errors.
- **Never mix LaTeX and admonitions in the same cell.** A `md"""..."""` block containing both LaTeX (`$W$`, `$Rww'$`) and `$(Markdown.MD(Markdown.Admonition(...)))` will fail — Pluto's parser can't distinguish LaTeX `$` from Julia interpolation `$`. Split them into separate cells.

## Notebook Structure

Each notebook should follow this general structure:

### B&D track notebooks

1. **Title and overview** — which B&D chapter, what concepts are covered
2. **Setup cell** — activate environment, import packages
3. **Motivational opener** — address the skeptical student: why does this topic matter? What can it do that an LLM can't? Brief historical context where appropriate. This section should make the student *want* to learn the formalism.
4. **Concept introduction** — markdown explaining the definition/theorem, referencing B&D definition numbers
5. **Concrete examples first** — before abstract definitions, give tangible examples (game states, treatment scenarios, everyday reasoning) that build intuition for the formal concept
6. **Interactive exploration** — Gamen.jl code with PlutoUI widgets letting students:
   - Build and modify formulas
   - Construct Kripke models (add/remove worlds, toggle accessibility)
   - Evaluate truth at worlds and see results update reactively
   - Run tableau provers with adjustable parameters
   - Visualize models with `visualize_model`
7. **Translation exercises with reveals** — "Translate this English sentence into a formula" with collapsible answers using `Markdown.Admonition("hint", "Reveal answer", [md"..."])`. Intersperse these throughout the notebook, not just at the end.
8. **Exercises** — prompted exploration tasks matching B&D exercises

### Health track notebooks

1. **Title and clinical scenario** — what clinical domain, which guidelines
2. **Setup cell** — same environment
3. **Motivational opener** — address the skeptical clinician: "Why does a surgeon need formal logic?" Connect to real clinical failures (inconsistent CDS alerts, the Lomotan 'should' problem, guideline conflicts)
4. **Clinical motivation** — why this logic matters for healthcare (reference Lomotan et al. 2010 for deontic interpretation, ACC/AHA guidelines for examples)
5. **Formalization** — translate clinical language ("must," "should," "before") into modal logic step by step, using widgets to let students experiment with the encoding
6. **Translation exercises with reveals** — clinical sentences to formalize, with collapsible answers
7. **Analysis** — run consistency checks, explore what happens when guidelines conflict
8. **Discussion** — implications for EHR implementation, clinical decision support

## Exercise and Reveal Pattern

Use Pluto's admonition rendering for collapsible reveal-style exercises:

```julia
md"""
**1. "The patient must receive antibiotics within 1 hour."**

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"`Box(antibiotics_1hr)` — □p. This is an obligation: in all guideline-compliant scenarios, antibiotics are given within 1 hour."])))
"""
```

Rules:
- Always use single-line `md"..."` inside admonitions (never `md\"\"\"...\"\"\"`).
- Place exercises **throughout** the notebook after each new concept, not just at the end.
- Include a mix of: translate English → formula, evaluate formula on a model by hand, identify whether a sentence is modal or propositional, construct a model that satisfies/falsifies a given formula.

## Knowledge Representation Lens (Recurring Thread)

Each notebook should include 1-2 "Knowledge Representation Lens" sidebars that connect the chapter's formal concepts to Davis, Shrobe & Szolovits (1993), "What Is a Knowledge Representation?" and related sources from the PUBH 5106 curriculum. These are rendered as `"note"` admonitions (visually distinct from `"hint"` exercise reveals):

```julia
$(Markdown.MD(Markdown.Admonition("note", "Knowledge Representation Lens", [md"Content connecting to Davis et al. or other course sources..."])))
```

The mapping of Davis et al.'s five roles across chapters:

| Davis et al. Role | Chapter | Connection |
|:---|:---|:---|
| **1. Surrogate** | Ch0, Ch1 | A Kripke model is a surrogate for a real scenario; "perfect fidelity is impossible" (Davis et al.) — the model always differs from the thing it represents |
| **2. Ontological commitment** | Ch2 | Choosing frame properties = choosing "in what terms should I think about the world?" Seriality commits to achievable obligations; reflexivity commits to factive knowledge |
| **3. Theory of reasoning** | Ch3, Ch6 | Which inferences are *sanctioned* (derivable in the proof system) vs *recommended* (tractable to compute). Hilbert proofs sanction; tableaux recommend. |
| **4. Medium for computation** | Ch5, Ch6 | Filtrations make reasoning tractable (finite model property). Tableaux make it automated. The representation must be structured for efficient computation. |
| **5. Human expression** | Ch0, Ch1, all health notebooks | Translating clinical English into formal logic. "A language for communicating knowledge between humans and systems." |

Additional sources from PUBH 5106 to weave in where appropriate:
- **Clark (2003)** *Natural-Born Cyborgs* — extended mind theory; formal logic tools as cognitive augmentation
- **Buchanan (2006)** "Knowledge Is Power" — "making assumptions explicit is valuable, whether or not the system is correct" (connects to frame definability and completeness)
- **Lomotan et al. (2010)** — deontic ambiguity in guidelines (connects to Ch0 health, Ch1 health, Ch2 health, Ch6 health)
- **Braithwaite et al. (2020)** 60-30-10 challenge — why formal CDS matters (connects to Ch0 health motivation)

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
