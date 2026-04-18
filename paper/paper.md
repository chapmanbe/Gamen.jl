---
title: 'Gamen.jl: Interactive Modal Logic Education with Julia and Pluto Notebooks'
tags:
  - Julia
  - modal logic
  - Kripke semantics
  - Pluto notebooks
  - logic education
  - deontic logic
  - epistemic logic
  - temporal logic
authors:
  - name: Brian E. Chapman
    orcid: 0000-0003-0815-5448
    affiliation: 1
  - name: Jeremiah Chapman
    orcid: 0000-0003-3023-6287
    affiliation: 2
affiliations:
  - name: Department of Population and Data Sciences, UT Southwestern Medical Center, Dallas, TX, USA
    index: 1
  - name: Department of Philosophy, Linguistics, and Theory of Science, University of Gothenburg, Gothenburg, Sweden
    index: 2
date: TODO
bibliography: paper.bib
---

# Summary

Gamen.jl is a Julia package that makes modal logic accessible to
interdisciplinary learners — particularly health informatics students — by
combining a standard textbook curriculum with domain-grounded interactive
notebooks. It serves as a computational companion to *Boxes and Diamonds: An
Open Introduction to Modal Logic* [@zach2025], an open-access textbook from the
Open Logic Project.

The package implements the core machinery of modal logic: type-safe formula
construction, Kripke semantics, model checking, frame definability,
Hilbert-style proof systems, canonical model construction, filtrations, and
prefixed tableau provers across multiple systems (K, KT, KD, KB, K4, S4, S5).
It extends beyond the base textbook with deontic, epistemic, and temporal
logics — the modal logics most relevant to health informatics applications.

Gamen.jl is accompanied by 20 interactive Pluto notebooks [@fonsp2021]: a
prerequisite pair reviewing propositional logic through clinical examples, eight
that follow the textbook chapter-by-chapter, eight parallel health-application
notebooks that apply the same formal concepts to clinical reasoning scenarios
(guideline obligations, prescribing permissions, diagnostic knowledge), and two
extension notebooks exploring combined logics. The reactive notebook environment
lets students construct models, modify formulas, and see the consequences
immediately — supporting the hands-on learning that adult learners in
professional graduate programs require.

The name comes from Old English *gamen* (game, sport, joy), the ancestor of
the modern word "game."

# Statement of Need

Modern clinical practice demands a kind of reasoning that human cognition is
not well equipped to perform unaided. As Clark [-@clark2003natural] observes,
the brain is "bad at logic and good at Frisbee" — expert at perception and
pattern recognition, but poorly suited to the systematic, multi-step inference
that integrating clinical guidelines, drug interactions, and treatment
protocols requires. The consequences are measurable: only about 60% of care
delivered is consistent with current evidence, with approximately 30% wasteful
and 10% potentially harmful [@pmid32362273]. Logic-based clinical decision
support — the direct descendant of early expert systems like MYCIN — is one of
the primary tools for closing this evidence-practice gap, and its core concepts
(obligations, permissions, prohibitions, temporal constraints) are modal-logical
in nature [@mcnamara2021].

Yet health informatics students typically arrive with no exposure to formal
logic. These students are overwhelmingly adult learners — working clinicians,
data analysts, and public health practitioners returning to graduate education —
who learn most effectively through hands-on engagement with problems drawn from
their own domain. The standard approach to teaching modal logic (definition,
theorem, proof) assumes a mathematics or philosophy background and offers no
connection to applied domains. Existing software tools are designed for
researchers (Isabelle, Lean) or for logic students who already have the
prerequisite background (LoTREC; @gasquet2014). None provide an on-ramp for
interdisciplinary learners who need to understand *why* formal methods matter
for their field before engaging with the formalism itself.

The need for such an on-ramp is sharpened by the ambiguity of natural-language
guideline terms. @lomotan2010deontic surveyed 445 health services professionals
and found that terms like "should" and "is recommended" are interpreted with
wide variation — the same guideline verb triggers a hard-stop alert in one EHR
implementation and a silent pass in another. Deontic logic (the modal logic of
obligation, permission, and prohibition) provides a formal vocabulary that
resolves this ambiguity, but only if students can see the connection between the
formalism and the clinical problem it addresses.

Gamen.jl addresses this gap by pairing a standard modal logic curriculum with
domain-grounded notebooks that make the relevance immediate:

- **Textbook-aligned**: Each notebook maps directly to a chapter of *Boxes and
  Diamonds* [@zach2025], an open-access textbook, so students move between
  reading definitions and computing with them
- **Domain-motivated**: Parallel health-application notebooks present the same
  formal concepts through clinical scenarios — guideline obligations,
  prescribing permissions, contraindication prohibitions — giving adult learners
  the real-world anchoring that supports transfer
- **Interactive and reactive**: Pluto notebooks provide immediate feedback;
  when a student modifies a model or formula, all dependent results
  (evaluations, visualizations, proofs) update automatically
- **Full curriculum arc**: The package covers syntax, semantics, proof theory,
  completeness, decidability, and automated reasoning, so a single tool serves
  an entire course

The primary audience is graduate students in health informatics and related
fields who need working knowledge of formal reasoning. The materials are also
suitable for undergraduate and graduate students in logic, philosophy, and
computer science, and for any instructor seeking reusable, open-source
notebooks for teaching modal logic computationally.

# Content and Instructional Design

## Textbook Companion Notebooks

A prerequisite Chapter 0 notebook reviews propositional logic — propositions,
connectives, truth tables, modus ponens, tautologies — assuming no prior
background. Its health parallel introduces the same concepts through MYCIN-style
clinical production rules, then motivates the transition to modal logic by
showing that guideline language ("must," "should," "may") cannot be captured
propositionally.

The eight core notebooks then follow *Boxes and Diamonds* chapter-by-chapter,
covering the standard curriculum of a modal logic course:

1. **Syntax and Semantics** (Ch. 1) — Formula construction, Kripke frames and
   models, the satisfaction relation, validity, and entailment.
2. **Frame Definability** (Ch. 2) — Frame properties (reflexivity, symmetry,
   transitivity, seriality, Euclideanness), correspondence with axiom schemas
   (T, D, B, 4, 5), and the standard translation to first-order logic.
3. **Axiomatic Derivations** (Ch. 3) — Hilbert-style proof systems, axiom
   schemas, modal systems (K through S5), and soundness.
4. **Completeness** (Ch. 4) — Canonical model construction, maximal consistent
   sets, Lindenbaum's Lemma, and the Truth Lemma.
5. **Filtrations** (Ch. 5) — Finest and coarsest filtrations, the Filtration
   Lemma, the finite model property, and decidability.
6. **Modal Tableaux** (Ch. 6) — Prefixed signed tableau systems, systematic
   proof search, soundness, and completeness for seven modal systems.
7. **Temporal Logics** (Ch. 14) — Until/since operators, ancestor-based
   blocking for termination, temporal frame conditions.
8. **Epistemic Logics** (Ch. 15) — Knowledge and belief operators,
   multi-agent frames, common knowledge.

Each notebook references specific B&D definition numbers, allowing students to
read a definition, then immediately construct examples, check properties, and
build intuition through computation. Kripke frames are rendered as interactive
directed graphs using CairoMakie, giving students a visual representation of
accessibility relations.

## Health-Application Notebooks

A parallel set of eight notebooks applies the same formal machinery to clinical
reasoning problems:

- **Clinical Obligations** — Modeling treatment guidelines as deontic
  obligations using Kripke frames with seriality constraints
- **Guideline Properties** — Frame definability applied to properties of
  clinical guideline systems
- **Deontic Systems** — Formalizing "must treat," "may prescribe," and
  "must not combine" in standard deontic logic
- **Completeness and Decidability** — Verifying that clinical reasoning systems
  have the formal properties needed for automated checking
- **Conflict Detection** — Using tableaux to detect inconsistencies between
  overlapping clinical guidelines
- **Temporal and Epistemic Clinical Reasoning** — Modeling time-dependent
  obligations and clinician knowledge states

These notebooks follow Buchanan's separation principle: domain knowledge
(guidelines, drug interactions, clinical rules) is stored in YAML data files,
not in code, so instructors can substitute their own domain examples without
modifying the package.

## Pedagogical Approach

The notebooks are designed around the principle of *constructive exploration*:
rather than presenting modal logic as a finished formal system, students build
it incrementally. Each notebook section introduces one concept, provides a
working code example, then poses exercises that require modifying the model or
formula. This structure manages cognitive load by limiting each interaction to
a single new idea while building on prior notebook sections.

The Pluto notebook environment reinforces this approach through reactivity —
when a student changes a formula or model definition, all dependent cells
(truth evaluations, visualizations, proof results) update automatically,
providing immediate feedback on the consequences of their choices.

# Experience of Use

Gamen.jl has been used in PUBH 5106 ("AI for Health") at UT Southwestern
Medical Center, a graduate course in the Department of Population and Data
Sciences. The students are health informatics professionals — clinicians, data
analysts, and public health practitioners — with no prior background in formal
logic.

The course follows a deliberate arc: Module 1 introduces AI through three
paradigms (logic-based, learning-based, and probabilistic), framing AI as
cognitive augmentation rather than replacement [@clark2003natural]. Module 2
covers LLMs. Module 3, "The Role of Logic in AI for Health," traces the
evolution from MYCIN's production rules through deontic and temporal logic to
contemporary neurosymbolic AI — arguing that logic-based AI did not disappear
but evolved into clinical decision support, knowledge graphs, and formal
verification of AI systems. Gamen.jl notebooks anchor the formal content of
Module 3: students construct Kripke models of clinical scenarios, evaluate
whether guideline obligations hold across accessible worlds, and explore how
frame conditions (particularly seriality) ensure the consistency of normative
systems. By grounding the formalism in familiar clinical problems — statin
prescribing guidelines, drug interaction prohibitions — the notebooks give
students a concrete reason to engage with abstract concepts like accessibility
relations and modal satisfaction before encountering them in their general form.
Course materials are publicly available at
https://github.com/utsw-hdsb/pubh5106-m3-notebooks.

# Acknowledgements

The mathematical content of Gamen.jl follows *Boxes and Diamonds* by Richard
Zach (Open Logic Project), licensed under CC BY 4.0. The algorithmic design of
the tableau systems draws on @fitting1999 and @fitting1983.

# References
