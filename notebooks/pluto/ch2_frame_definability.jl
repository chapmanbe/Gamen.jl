### A Pluto.jl notebook ###
# v0.20.4

using Markdown
using InteractiveUtils

# ╔═╡ 2a2b3c4d-0001-0001-0001-000000000001
md"""
# Chapter 2: Frame Definability

This notebook follows Chapter 2 of [Boxes and Diamonds](https://bd.openlogicproject.org)
using the **Gamen.jl** package.

We cover:
- Validity on a frame (Definition 2.1)
- Frame properties: reflexivity, symmetry, transitivity, seriality, euclideanness (Definition 2.3)
- The correspondence between modal schemas and frame properties
- Normal modal logics: K, T, S4, S5, KD
"""

# ╔═╡ 2a2b3c4d-0002-0002-0002-000000000002
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	using Gamen
	import CairoMakie, GraphMakie, Graphs
end

# ╔═╡ 2a2b3c4d-0050-0050-0050-000000000050
md"""
## Why Frame Properties Matter

In Chapter 1, we saw that the truth of a modal formula depends on the **structure** of the accessibility relation — which worlds can see which. But we treated each model individually. Chapter 2 asks a deeper question:

> **What does the *shape* of the accessibility relation force to be true?**

This turns out to be one of the most powerful ideas in modal logic. Different shapes of accessibility correspond to different **logics** — different sets of valid formulas. And these logics map onto real reasoning domains:

| Frame property | Logic | Domain interpretation |
|:---------------|:------|:----------------------|
| Reflexive | T | "If p is necessary, then p is true" — knowledge (you know only truths) |
| Serial | KD | "If p is obligatory, then p is permitted" — deontic reasoning (obligations must be achievable) |
| Transitive | K4 | "If p is necessary, then it's necessarily necessary" — introspection |
| Equivalence relation | S5 | Within each equivalence class, worlds agree on what's possible — epistemic logic, provability |

The correspondence is not a coincidence. It was proved by Sahlqvist (1975) as a general theorem: a wide class of modal axioms correspond precisely to first-order conditions on frames. This chapter explores the specific correspondences that matter most.

**Why should you care?** When you choose a modal logic for an application — say, KD for clinical guidelines or S5 for epistemic reasoning — you are choosing which frame properties your models must satisfy. Understanding the correspondence tells you exactly what assumptions you are making. (Note: common knowledge requires a *multimodal* logic with separate accessibility relations for each agent, which goes beyond what we cover here.)

$(Markdown.MD(Markdown.Admonition("note", "Knowledge Representation Lens", [md"Davis, Shrobe & Szolovits (1993) argue that every knowledge representation plays five roles simultaneously, including serving as an *ontological commitment* — a decision about 'in what terms should I think about the world?' Choosing a frame property is exactly this kind of commitment. When you require seriality, you commit to a world where dead ends don't exist. When you require reflexivity, you commit to a world where the actual situation is always among the accessible alternatives. These are not technical implementation details — they are assumptions about the domain that determine what your system can and cannot represent."])))
"""

# ╔═╡ 2a2b3c4d-0003-0003-0003-000000000003
begin
	p = Atom(:p)
	q = Atom(:q)
end

# ╔═╡ 2a2b3c4d-0004-0004-0004-000000000004
md"""
## Validity on a Frame

Recall from Chapter 1 that a formula can be *true in a model*. But a model includes a specific valuation V. A stronger notion is **validity on a frame** (Definition 2.1):

A formula A is *valid on a frame* F = ⟨W, R⟩ if A is true in **every** model based on F — that is, for every possible valuation V.

This tells us what the frame's *structure* forces to be true, independent of which propositions hold where.
"""

# ╔═╡ 2a2b3c4d-0005-0005-0005-000000000005
begin
	frame_simple = KripkeFrame([:w1, :w2], [:w1 => :w2])

	md"""
	**Example:** On the frame below (w₁ → w₂, not reflexive):
	- □⊤ is valid — ⊤ is true everywhere, so □⊤ holds regardless of valuation
	- □p → p is **not** valid — we can find a valuation that falsifies it
	"""
end

# ╔═╡ 2a2b3c4d-0051-0051-0051-000000000051
begin
	model_simple = KripkeModel(frame_simple, [:p => [:w1]])
	visualize_model(model_simple,
		positions = Dict(:w1 => (0.0, 0.0), :w2 => (2.0, 0.0)),
		title = "Non-reflexive frame: w₁ → w₂")
end

# ╔═╡ 2a2b3c4d-0006-0006-0006-000000000006
begin
	# □⊤ is valid on any frame
	valid_box_top = is_valid_on_frame(frame_simple, Box(Top()))

	# □p → p is NOT valid on this frame — it's not reflexive
	valid_t_schema = is_valid_on_frame(frame_simple, Implies(Box(p), p))

	md"""
	| Formula | Valid on this frame? |
	|:--------|:--------------------|
	| □⊤ | $(valid_box_top) |
	| □p → p (Schema T) | $(valid_t_schema) |

	Schema T fails because at w₂ (which has no successors), □p is vacuously true but p can be false — the frame doesn't force w₂ to access itself.
	"""
end

# ╔═╡ 2a2b3c4d-0052-0052-0052-000000000052
md"""
### Practice: Validity vs. Truth

$(Markdown.MD(Markdown.Admonition("hint", "What's the difference between 'true in a model' and 'valid on a frame'?", [md"*True in a model*: the formula holds at every world, given a specific valuation. *Valid on a frame*: the formula holds at every world, for *every possible* valuation. Validity is much stronger — it depends only on the frame's structure, not on which propositions happen to be true where."])))
"""

# ╔═╡ 2a2b3c4d-0007-0007-0007-000000000007
md"""
## Frame Properties

The key insight of frame definability is that certain **structural properties** of the accessibility relation correspond to specific modal schemas (Definition 2.3, B&D).

The five main properties are:

| Property | Condition | Intuition |
|:---------|:----------|:----------|
| Reflexive | Every world accesses itself | You can always stay where you are |
| Symmetric | If w sees w', then w' sees w | Access goes both ways |
| Transitive | If w sees w' and w' sees w'', then w sees w'' | Access chains compose |
| Serial | Every world has at least one successor | There's always somewhere to go |
| Euclidean | If w sees w' and w sees w'', then w' sees w'' | Successors see each other |

Let's build frames with these properties and **see** what they look like:
"""

# ╔═╡ 2a2b3c4d-0008-0008-0008-000000000008
begin
	# A reflexive, transitive frame (a preorder) — this is an S4 frame
	preorder = KripkeFrame([:w1, :w2, :w3],
		[:w1 => :w1, :w2 => :w2, :w3 => :w3,   # reflexive loops
		 :w1 => :w2, :w2 => :w3, :w1 => :w3])   # transitive chain

	preorder_model = KripkeModel(preorder, [:p => [:w1, :w2], :q => [:w2, :w3]])
	visualize_model(preorder_model,
		positions = Dict(:w1 => (0.0, 0.0), :w2 => (2.0, 0.0), :w3 => (4.0, 0.0)),
		title = "Preorder (reflexive + transitive)")
end

# ╔═╡ 2a2b3c4d-0053-0053-0053-000000000053
begin
	(reflexive = is_reflexive(preorder),
	 symmetric = is_symmetric(preorder),
	 transitive = is_transitive(preorder),
	 serial = is_serial(preorder),
	 euclidean = is_euclidean(preorder))
end

# ╔═╡ 2a2b3c4d-0009-0009-0009-000000000009
begin
	# An equivalence relation (reflexive + symmetric + transitive) — this is an S5 frame
	equiv = KripkeFrame([:w1, :w2, :w3],
		[:w1 => :w1, :w2 => :w2, :w3 => :w3,
		 :w1 => :w2, :w2 => :w1,
		 :w2 => :w3, :w3 => :w2,
		 :w1 => :w3, :w3 => :w1])

	equiv_model = KripkeModel(equiv, [:p => [:w1], :q => [:w2, :w3]])
	visualize_model(equiv_model,
		positions = Dict(:w1 => (0.0, 0.0), :w2 => (2.0, 1.0), :w3 => (2.0, -1.0)),
		title = "Equivalence relation (S5 frame)")
end

# ╔═╡ 2a2b3c4d-0054-0054-0054-000000000054
begin
	(reflexive = is_reflexive(equiv),
	 symmetric = is_symmetric(equiv),
	 transitive = is_transitive(equiv),
	 serial = is_serial(equiv),
	 euclidean = is_euclidean(equiv))
end

# ╔═╡ 2a2b3c4d-0055-0055-0055-000000000055
md"""
### Practice: Identify Frame Properties

Look at each frame description and predict its properties before expanding the answer.

**1.** A frame with worlds {a, b} and relation {a→b, b→a}.

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**Symmetric** (yes), **Serial** (yes — each world has a successor), **Reflexive** (no — neither world accesses itself), **Transitive** (no — a→b→a but a↛a), **Euclidean** (no — euclidean requires that if wRw' and wRw'' then w'Rw''; since aRb and aRb, we'd need bRb, but b only accesses a)."])))

**2.** A frame with worlds {a, b, c} and relation {a→a, a→b, a→c}.

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**Reflexive** (no — only a accesses itself), **Serial** (no — b and c have no successors), **Symmetric** (no — a→b but b↛a), **Transitive** (yes — the only chains starting from a lead to b and c, which have no successors, so no new edges are required), **Euclidean** (no — a→b and a→c but b↛c)."])))

**3.** A single world {w} with relation {w→w}.

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**All five properties hold!** Reflexive (w→w), symmetric (trivially), transitive (trivially), serial (w has a successor), euclidean (trivially). This is the simplest S5 frame."])))
"""

# ╔═╡ 2a2b3c4d-0010-0010-0010-000000000010
md"""
## The Correspondence Results

The central results of Chapter 2 show that each frame property corresponds to a modal schema being valid on the frame. This is the **frame correspondence theorem** — the bridge between syntax (formulas) and semantics (frame structure).

| Schema | Name | Formula | Frame Property |
|:-------|:-----|:--------|:---------------|
| **K** | Distribution | □(p → q) → (□p → □q) | *All frames* |
| **T** | Reflexivity | □p → p | Reflexive |
| **D** | Seriality | □p → ◇p | Serial |
| **B** | Symmetry | p → □◇p | Symmetric |
| **4** | Transitivity | □p → □□p | Transitive |
| **5** | Euclideanness | ◇p → □◇p | Euclidean |

Let's verify each one with visualizations showing *why* the correspondence holds — and what goes wrong when the property fails.
"""

# ╔═╡ 2a2b3c4d-0011-0011-0011-000000000011
md"""
### Schema T: □p → p corresponds to Reflexivity (Proposition 2.5)

If every world can see itself, then whatever is necessary is actual. Conversely, if □p → p is valid, the frame must be reflexive.

**Intuition:** If w accesses itself, then □p at w requires p to hold at w (among other worlds). Remove the self-loop, and □p can be vacuously true while p is false.
"""

# ╔═╡ 2a2b3c4d-0014-0014-0014-000000000014
begin
	schema_t = Implies(Box(p), p)

	reflexive_frame = KripkeFrame([:w1, :w2],
		[:w1 => :w1, :w1 => :w2, :w2 => :w2])
	non_reflexive_frame = KripkeFrame([:w1, :w2], [:w1 => :w2])

	refl_model = KripkeModel(reflexive_frame, [:p => [:w1]])
	non_refl_model = KripkeModel(non_reflexive_frame, [:p => [:w1]])

	md"""
	| Frame | Reflexive? | Schema T valid? |
	|:------|:-----------|:----------------|
	| w₁⟲→w₂⟲ | $(is_reflexive(reflexive_frame)) | $(is_valid_on_frame(reflexive_frame, schema_t)) |
	| w₁→w₂ (no loops) | $(is_reflexive(non_reflexive_frame)) | $(is_valid_on_frame(non_reflexive_frame, schema_t)) |
	"""
end

# ╔═╡ 2a2b3c4d-0056-0056-0056-000000000056
visualize_model(refl_model,
	positions = Dict(:w1 => (0.0, 0.0), :w2 => (2.0, 0.0)),
	title = "Reflexive frame: □p → p is valid")

# ╔═╡ 2a2b3c4d-0057-0057-0057-000000000057
visualize_model(non_refl_model,
	positions = Dict(:w1 => (0.0, 0.0), :w2 => (2.0, 0.0)),
	title = "Non-reflexive frame: □p → p fails at w₂")

# ╔═╡ 2a2b3c4d-0015-0015-0015-000000000015
md"""
### Schema D: □p → ◇p corresponds to Seriality (Proposition 2.7)

If every world has at least one successor, then whatever is necessary is at least possible. A world with no successors makes □p vacuously true while ◇p is false — the "dead end" problem.

**Why this matters for deontic logic:** If □ means "obligatory" and ◇ means "permitted," then seriality says *obligations must be achievable*. A system where something is obligatory but not even permitted is incoherent — and seriality prevents exactly this.
"""

# ╔═╡ 2a2b3c4d-0016-0016-0016-000000000016
begin
	schema_d = Implies(Box(p), Diamond(p))

	serial_frame = KripkeFrame([:w1, :w2], [:w1 => :w2, :w2 => :w1])
	non_serial_frame = KripkeFrame([:w1, :w2], [:w1 => :w2])

	serial_model = KripkeModel(serial_frame, [:p => [:w1]])
	non_serial_model = KripkeModel(non_serial_frame, [:p => [:w1]])

	md"""
	| Frame | Serial? | Schema D valid? |
	|:------|:--------|:----------------|
	| w₁⇄w₂ | $(is_serial(serial_frame)) | $(is_valid_on_frame(serial_frame, schema_d)) |
	| w₁→w₂ (dead end) | $(is_serial(non_serial_frame)) | $(is_valid_on_frame(non_serial_frame, schema_d)) |
	"""
end

# ╔═╡ 2a2b3c4d-0058-0058-0058-000000000058
visualize_model(serial_model,
	positions = Dict(:w1 => (0.0, 0.0), :w2 => (2.0, 0.0)),
	title = "Serial frame: □p → ◇p is valid")

# ╔═╡ 2a2b3c4d-0059-0059-0059-000000000059
visualize_model(non_serial_model,
	positions = Dict(:w1 => (0.0, 0.0), :w2 => (2.0, 0.0)),
	title = "Non-serial frame: □p → ◇p fails at w₂ (dead end)")

# ╔═╡ 2a2b3c4d-0017-0017-0017-000000000017
md"""
### Schema B: p → □◇p corresponds to Symmetry (Proposition 2.9)

If you can go back wherever you came from, then if p is true here, it's necessarily possible — every accessible world can see back to where p holds.
"""

# ╔═╡ 2a2b3c4d-0018-0018-0018-000000000018
begin
	schema_b = Implies(p, Box(Diamond(p)))

	symmetric_frame = KripkeFrame([:w1, :w2],
		[:w1 => :w2, :w2 => :w1, :w1 => :w1, :w2 => :w2])
	non_symmetric_frame = KripkeFrame([:w1, :w2], [:w1 => :w2, :w2 => :w2])

	sym_model = KripkeModel(symmetric_frame, [:p => [:w1]])
	non_sym_model = KripkeModel(non_symmetric_frame, [:p => [:w1]])

	(symmetric = is_valid_on_frame(symmetric_frame, schema_b),
	 non_symmetric = is_valid_on_frame(non_symmetric_frame, schema_b))
end

# ╔═╡ 2a2b3c4d-0060-0060-0060-000000000060
visualize_model(sym_model,
	positions = Dict(:w1 => (0.0, 0.0), :w2 => (2.0, 0.0)),
	title = "Symmetric frame: p → □◇p is valid")

# ╔═╡ 2a2b3c4d-0019-0019-0019-000000000019
md"""
### Schema 4: □p → □□p corresponds to Transitivity (Proposition 2.11)

If accessibility chains compose, then knowing something is necessary means knowing it's necessarily necessary — you can't "escape" necessity by going further along the chain.
"""

# ╔═╡ 2a2b3c4d-0020-0020-0020-000000000020
begin
	schema_4 = Implies(Box(p), Box(Box(p)))

	transitive_frame = KripkeFrame([:w1, :w2, :w3],
		[:w1 => :w2, :w2 => :w3, :w1 => :w3])
	non_transitive_frame = KripkeFrame([:w1, :w2, :w3],
		[:w1 => :w2, :w2 => :w3])

	trans_model = KripkeModel(transitive_frame, [:p => [:w2, :w3]])
	non_trans_model = KripkeModel(non_transitive_frame, [:p => [:w2, :w3]])

	(transitive = is_valid_on_frame(transitive_frame, schema_4),
	 non_transitive = is_valid_on_frame(non_transitive_frame, schema_4))
end

# ╔═╡ 2a2b3c4d-0061-0061-0061-000000000061
visualize_model(trans_model,
	positions = Dict(:w1 => (0.0, 0.0), :w2 => (2.0, 0.0), :w3 => (4.0, 0.0)),
	title = "Transitive frame: □p → □□p is valid")

# ╔═╡ 2a2b3c4d-0062-0062-0062-000000000062
visualize_model(non_trans_model,
	positions = Dict(:w1 => (0.0, 0.0), :w2 => (2.0, 0.0), :w3 => (4.0, 0.0)),
	title = "Non-transitive: w₁ can't directly see w₃")

# ╔═╡ 2a2b3c4d-0021-0021-0021-000000000021
md"""
### Schema 5: ◇p → □◇p corresponds to Euclideanness (Proposition 2.13)

If all successors of a world can see each other, then if something is possible, it's necessarily possible — every accessible world agrees on what's possible.
"""

# ╔═╡ 2a2b3c4d-0022-0022-0022-000000000022
begin
	schema_5 = Implies(Diamond(p), Box(Diamond(p)))

	euclidean_frame = KripkeFrame([:w1, :w2, :w3],
		[:w1 => :w2, :w1 => :w3, :w2 => :w2, :w2 => :w3, :w3 => :w2, :w3 => :w3])
	non_euclidean_frame = KripkeFrame([:w1, :w2, :w3],
		[:w1 => :w2, :w1 => :w3])

	euc_model = KripkeModel(euclidean_frame, [:p => [:w2]])
	non_euc_model = KripkeModel(non_euclidean_frame, [:p => [:w2]])

	(euclidean = is_valid_on_frame(euclidean_frame, schema_5),
	 non_euclidean = is_valid_on_frame(non_euclidean_frame, schema_5))
end

# ╔═╡ 2a2b3c4d-0063-0063-0063-000000000063
visualize_model(euc_model,
	positions = Dict(:w1 => (0.0, 0.0), :w2 => (2.0, 1.0), :w3 => (2.0, -1.0)),
	title = "Euclidean frame: ◇p → □◇p is valid")

# ╔═╡ 2a2b3c4d-0064-0064-0064-000000000064
md"""
### Practice: Match the Schema

For each scenario, identify which schema (T, D, B, 4, or 5) is relevant and whether the frame satisfies it.

**1.** A frame where every world has a successor, but no world accesses itself. Which schema is guaranteed to be valid?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**Schema D** (□p → ◇p). The frame is serial but not reflexive. Schema T (□p → p) is NOT guaranteed — seriality is weaker than reflexivity."])))

**2.** A frame where w₁→w₂ and w₂→w₃ but w₁↛w₃. Does □p → □□p (Schema 4) hold?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**No.** The frame is not transitive. At w₁, □p requires p at w₂. But □□p requires □p at w₂, which requires p at w₃. Since w₁ doesn't directly see w₃, there's a gap: □p can hold at w₁ (only checks w₂) while □□p fails (w₂ must check w₃)."])))

**3.** An equivalence relation (reflexive + symmetric + transitive). Which schemas are valid?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**All five schemas listed in section 2.3:** T (reflexive), B (symmetric), 4 (transitive), 5 (equivalence implies euclidean), D (reflexive implies serial). This is why S5 is such a strong logic — equivalence relations satisfy all the standard frame properties."])))
"""

# ╔═╡ 2a2b3c4d-0023-0023-0023-000000000023
md"""
## Normal Modal Logics

Combining schemas gives named systems of modal logic. Each system corresponds to a class of frames:

| System | Axioms | Frame Class | Application |
|:-------|:-------|:------------|:------------|
| **K** | K | All frames | Minimal modal logic |
| **KD** | K + D | Serial frames | Deontic logic (obligations) |
| **T** (= KT) | K + T | Reflexive frames | Knowledge (factive) |
| **K4** | K + 4 | Transitive frames | Provability logic |
| **S4** | K + T + 4 | Preorders (reflexive + transitive) | Intuitionistic logic |
| **S5** | K + T + 5 | Equivalence relations (reflexive + symmetric + transitive) | Epistemic logic |

A **preorder** is a relation that is both reflexive and transitive — it lets you chain accessibility but always includes the starting point. An **equivalence relation** adds symmetry: you can always go back. These are standard notions from order theory.

Let's verify which schemas are valid on S4 and S5 frames:
"""

# ╔═╡ 2a2b3c4d-0024-0024-0024-000000000024
begin
	# S4 frame: reflexive and transitive (preorder)
	s4_frame = KripkeFrame([:w1, :w2, :w3],
		[:w1 => :w1, :w2 => :w2, :w3 => :w3,
		 :w1 => :w2, :w2 => :w3, :w1 => :w3])

	schema_k = Implies(Box(Implies(p, q)), Implies(Box(p), Box(q)))

	md"""
	### S4 frame (preorder):

	| Schema | Valid? |
	|:-------|:-------|
	| K: □(p→q) → (□p→□q) | $(is_valid_on_frame(s4_frame, schema_k)) |
	| T: □p → p | $(is_valid_on_frame(s4_frame, schema_t)) |
	| D: □p → ◇p | $(is_valid_on_frame(s4_frame, schema_d)) |
	| B: p → □◇p | $(is_valid_on_frame(s4_frame, schema_b)) |
	| 4: □p → □□p | $(is_valid_on_frame(s4_frame, schema_4)) |
	| 5: ◇p → □◇p | $(is_valid_on_frame(s4_frame, schema_5)) |
	"""
end

# ╔═╡ 2a2b3c4d-0026-0026-0026-000000000026
begin
	# S5 frame: equivalence relation
	s5_frame = KripkeFrame([:w1, :w2, :w3],
		[:w1 => :w1, :w2 => :w2, :w3 => :w3,
		 :w1 => :w2, :w2 => :w1,
		 :w2 => :w3, :w3 => :w2,
		 :w1 => :w3, :w3 => :w1])

	md"""
	### S5 frame (equivalence relation):

	| Schema | Valid? |
	|:-------|:-------|
	| K: □(p→q) → (□p→□q) | $(is_valid_on_frame(s5_frame, schema_k)) |
	| T: □p → p | $(is_valid_on_frame(s5_frame, schema_t)) |
	| D: □p → ◇p | $(is_valid_on_frame(s5_frame, schema_d)) |
	| B: p → □◇p | $(is_valid_on_frame(s5_frame, schema_b)) |
	| 4: □p → □□p | $(is_valid_on_frame(s5_frame, schema_4)) |
	| 5: ◇p → □◇p | $(is_valid_on_frame(s5_frame, schema_5)) |

	S5 validates all five standard schemas (K, T, D, B, 4, 5) — the equivalence relation satisfies all the standard frame properties.
	"""
end

# ╔═╡ 2a2b3c4d-0065-0065-0065-000000000065
visualize_model(KripkeModel(s5_frame, [:p => [:w1, :w2]]),
	positions = Dict(:w1 => (0.0, 0.0), :w2 => (2.0, 1.0), :w3 => (2.0, -1.0)),
	title = "S5 frame: all worlds see all worlds")

# ╔═╡ 2a2b3c4d-0066-0066-0066-000000000066
md"""
### Practice: Choose the Right Logic

**1.** You are modeling clinical guideline obligations. A guideline that obliges something impossible is incoherent. Which is the weakest logic that prevents this?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**KD.** Seriality (Schema D: □p → ◇p) ensures that if p is obligatory, then p is at least permitted — there exists an acceptable world where p holds. You don't need reflexivity (T) because obligations don't need to be *actual*, just *achievable*."])))

**2.** You are modeling an agent's knowledge. If the agent knows p, then p must actually be true — there is no false knowledge. What is the weakest logic that captures this?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**T (= KT)** at minimum. Schema T (□p → p) says: if you know p, then p is true. This is the *factivity* of knowledge — distinguishing knowledge from mere belief. Most epistemic logics use S4 or S5, which add introspection (knowing that you know)."])))

**3.** You want a logic where within each equivalence class of worlds, what is possible and necessary is agreed upon. Which logic?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**S5.** Schema 5 (◇p → □◇p) guarantees that if something is possible at a world, every world accessible from it agrees. In an equivalence relation, the frame partitions into classes where all worlds within a class see each other — so within each class, necessity and possibility are uniform. Note: this is *not* the same as a universal frame (where every world sees every world); S5 frames can have multiple disconnected equivalence classes."])))
"""

# ╔═╡ 2a2b3c4d-0067-0067-0067-000000000067
md"""
$(Markdown.MD(Markdown.Admonition("note", "Knowledge Representation Lens", [md"Davis et al. (1993) describe a knowledge representation's third role as a *fragmentary theory of intelligent reasoning* — it determines which inferences are *sanctioned* (licensed as valid) and which are *recommended* (worth actually computing). The frame correspondence theorem makes this concrete: choosing reflexivity *sanctions* the inference from □p to p; choosing seriality *sanctions* the inference from □p to ◇p. Each frame property adds sanctioned inferences. But more sanctioned inferences means more computation — S5 validates more schemas than K, but checking validity on equivalence relations is not cheaper than checking on arbitrary frames. The tension between expressiveness and tractability is a recurring theme in knowledge representation, and it reappears in Chapter 5 (filtrations) and Chapter 6 (tableaux)."])))
"""

# ╔═╡ 2a2b3c4d-0027-0027-0027-000000000027
md"""
## Exercises

**1.** Build a frame that is transitive but not reflexive (K4 but not S4) and verify that Schema 4 is valid but T is not.

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"Try `KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w2 => :w3, :w1 => :w3])`. This is transitive (w₁→w₂→w₃ and w₁→w₃) but not reflexive. `is_valid_on_frame(f, schema_4)` returns `true`, `is_valid_on_frame(f, schema_t)` returns `false`."])))

**2.** Does reflexivity imply seriality? Check whether Schema D is valid on all reflexive frames.

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"Yes! If w→w (reflexive), then w has at least one successor (itself), so seriality holds. Every reflexive frame is serial. `is_valid_on_frame(reflexive_frame, schema_d)` returns `true`."])))

**3.** Construct a frame that is serial but not reflexive. Verify that D holds but T does not.

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"Try `KripkeFrame([:w1, :w2], [:w1 => :w2, :w2 => :w1])`. Each world has a successor (serial) but neither accesses itself (not reflexive). This is exactly the kind of frame used in standard deontic logic (KD)."])))

**4. Challenge:** Can a frame be euclidean without being transitive? Build one and test.

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"Yes! Try `KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w2 => :w2, :w2 => :w3, :w3 => :w3, :w3 => :w2])`. Check: w₁'s only successor is w₂, so euclidean is vacuous at w₁. At w₂: w₂→w₂ and w₂→w₃, so we need w₂→w₃ and w₃→w₃ and w₃→w₂ — all present. At w₃: similarly satisfied. But NOT transitive: w₁→w₂→w₃ yet w₁↛w₃. Verify with `is_euclidean(f)` and `is_transitive(f)`."])))

"""

# ╔═╡ Cell order:
# ╟─2a2b3c4d-0001-0001-0001-000000000001
# ╠═2a2b3c4d-0002-0002-0002-000000000002
# ╟─2a2b3c4d-0050-0050-0050-000000000050
# ╠═2a2b3c4d-0003-0003-0003-000000000003
# ╟─2a2b3c4d-0004-0004-0004-000000000004
# ╟─2a2b3c4d-0005-0005-0005-000000000005
# ╠═2a2b3c4d-0051-0051-0051-000000000051
# ╟─2a2b3c4d-0006-0006-0006-000000000006
# ╟─2a2b3c4d-0052-0052-0052-000000000052
# ╟─2a2b3c4d-0007-0007-0007-000000000007
# ╠═2a2b3c4d-0008-0008-0008-000000000008
# ╠═2a2b3c4d-0053-0053-0053-000000000053
# ╠═2a2b3c4d-0009-0009-0009-000000000009
# ╠═2a2b3c4d-0054-0054-0054-000000000054
# ╟─2a2b3c4d-0055-0055-0055-000000000055
# ╟─2a2b3c4d-0010-0010-0010-000000000010
# ╟─2a2b3c4d-0011-0011-0011-000000000011
# ╠═2a2b3c4d-0014-0014-0014-000000000014
# ╠═2a2b3c4d-0056-0056-0056-000000000056
# ╠═2a2b3c4d-0057-0057-0057-000000000057
# ╟─2a2b3c4d-0015-0015-0015-000000000015
# ╠═2a2b3c4d-0016-0016-0016-000000000016
# ╠═2a2b3c4d-0058-0058-0058-000000000058
# ╠═2a2b3c4d-0059-0059-0059-000000000059
# ╟─2a2b3c4d-0017-0017-0017-000000000017
# ╠═2a2b3c4d-0018-0018-0018-000000000018
# ╠═2a2b3c4d-0060-0060-0060-000000000060
# ╟─2a2b3c4d-0019-0019-0019-000000000019
# ╠═2a2b3c4d-0020-0020-0020-000000000020
# ╠═2a2b3c4d-0061-0061-0061-000000000061
# ╠═2a2b3c4d-0062-0062-0062-000000000062
# ╟─2a2b3c4d-0021-0021-0021-000000000021
# ╠═2a2b3c4d-0022-0022-0022-000000000022
# ╠═2a2b3c4d-0063-0063-0063-000000000063
# ╟─2a2b3c4d-0064-0064-0064-000000000064
# ╟─2a2b3c4d-0023-0023-0023-000000000023
# ╠═2a2b3c4d-0024-0024-0024-000000000024
# ╠═2a2b3c4d-0026-0026-0026-000000000026
# ╠═2a2b3c4d-0065-0065-0065-000000000065
# ╟─2a2b3c4d-0066-0066-0066-000000000066
# ╟─2a2b3c4d-0067-0067-0067-000000000067
# ╟─2a2b3c4d-0027-0027-0027-000000000027
