### A Pluto.jl notebook ###
# v0.20.4

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    return quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ 10a1b3c4d-0001-0001-0001-000000000001
md"""
# Decidability of Guideline Checking

## Clinical Scenario

It is 2 a.m. An alert fires in the ICU: *"Sepsis protocol: give antibiotics within 1 hour, obtain blood cultures before antibiotics, and do not give thrombolytics if active bleeding."* Three recommendations, automatically encoded from the Surviving Sepsis Campaign guidelines. The CDS system must decide, in real time, whether the full guideline set is **logically consistent** — i.e., whether there exists any patient state in which all three rules can be satisfied simultaneously.

A skeptical resident asks: *"Can a computer really always answer that question? For any guideline set, no matter how complex?"*

The answer is **yes** — but only because of a deep mathematical property of the modal logics we use: **decidability**. There is an algorithm that is *guaranteed to terminate* with the correct answer. This notebook explains why, and what it costs.

---

## Why This Matters

- An inconsistent guideline set could fire alerts that can never all be satisfied — creating alert fatigue (Braithwaite et al. 2020, the 60-30-10 challenge)
- Automated consistency checking requires knowing that the check will *finish* — undecidable formalisms cannot give this guarantee
- The same theoretical result (the finite model property) bounds the search space for any guideline formula

---

## Learning Outcomes

After working through this notebook you will be able to:

1. State the **finite model property** and explain why it implies decidability
2. Calculate the theoretical **model-size bound** (2ⁿ) for a given formula
3. Explain why **brute-force search** is feasible only for tiny problems (max 4 worlds)
4. Describe how **filtrations** collapse irrelevant clinical distinctions to produce the finite model
5. Contrast brute-force search with the **tableau method** as practical alternatives

This notebook parallels [Chapter 5 of Boxes and Diamonds](https://bd.openlogicproject.org) (Filtrations and Decidability).
"""

# ╔═╡ 10a1b3c4d-0002-0002-0002-000000000002
begin
	using Gamen
	using PlutoUI
	import CairoMakie, GraphMakie, Graphs
end

# ╔═╡ 10a1b3c4d-0003-0003-0003-000000000003
begin
	consent = Atom(:consent)
	cultures = Atom(:blood_cultures)
	antibiotics = Atom(:antibiotics)
	thrombolytic = Atom(:thrombolytic)
	bleeding = Atom(:active_bleeding)
	discharge = Atom(:discharge_plan)
	p = Atom(:p)
	q = Atom(:q)
end;

# ╔═╡ 10a1b3c4d-0004-0004-0004-000000000004
md"""
## The Finite Model Property

A logic has the **finite model property** (FMP) if every satisfiable formula is satisfiable in a *finite* model. Both K and KD (the logic of clinical guidelines) have this property.

**Clinical meaning**: when checking whether a set of guidelines is consistent, we never need to consider infinitely many clinical scenarios. A finite search through finite models always suffices. If there is any way to satisfy the guidelines simultaneously, there is a *finite* model that demonstrates it.
"""

# ╔═╡ 10a1b3c4d-0005-0005-0005-000000000005
md"""
### Example: Finite Countermodels

The formula `Box(consent) -> consent` ("if consent is obligatory, then consent is actually obtained") is not valid in K -- it requires reflexivity. The FMP guarantees a finite countermodel exists:
"""

# ╔═╡ 10a1b3c4d-0006-0006-0006-000000000006
begin
	fmp_k = has_finite_model_property(SYSTEM_K, Implies(Box(consent), consent))
	fmp_s5 = has_finite_model_property(SYSTEM_S5, Implies(Box(consent), consent))
	(K_has_FMP = fmp_k, S5_has_FMP = fmp_s5)
end

# ╔═╡ 10a1b3c4d-0007-0007-0007-000000000007
md"""
Both return `true`: K has the FMP because it imposes no frame conditions (Proposition 5.14, B&D), and S5 has it because filtrations preserve the equivalence-relation structure (Corollary 5.16).
"""

# ╔═╡ 10a1b3c4d-0031-0031-0031-000000000031
md"""
### Exercise 1: Finite Models in Clinical Logic

A colleague proposes encoding the clinical rule *"Every patient who is obligated to receive warfarin is actually receiving it"* as □warfarin → warfarin (the T schema).

**a)** In which modal system(s) is this formula **valid**: K, KD, KT, or S5?

**b)** Does the T schema have a finite countermodel in K? What does that mean practically for CDS checking?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**a)** Valid in KT and S5 (both require reflexivity, which is the frame condition corresponding to the T axiom). Not valid in K or KD. **b)** Yes — because K has the finite model property, any formula that fails in K fails in some *finite* model. The finite countermodel for □warfarin → warfarin in K is simply a two-world model where world w sees world v, warfarin is true at v but false at w. Practically: if your CDS system uses K (no frame constraints), it cannot derive that obligations are self-fulfilling — which is usually the correct clinical assumption (obligations and facts are distinct)."])))
"""

# ╔═╡ 10a1b3c4d-0008-0008-0008-000000000008
md"""
## Decidability

The FMP gives us decidability directly: given a formula A with n subformulas, any filtration has at most 2^n worlds (Proposition 5.12, B&D). So we can check all models up to that size. If A is satisfiable, we find a model; if not, we exhaustively confirm there is none. Either way, the algorithm **terminates**.

This is a remarkable guarantee. First-order logic, by contrast, is *undecidable* -- there is no algorithm that can always determine whether a first-order sentence is valid. Modal logic's decidability is one reason it is well-suited to automated guideline checking.
"""

# ╔═╡ 10a1b3c4d-0009-0009-0009-000000000009
md"""
### Decidability in Action

The function `is_decidable_within` checks validity by exhaustive search over finite models up to the bound implied by the subformula count:
"""

# ╔═╡ 10a1b3c4d-0010-0010-0010-000000000010
begin
	# The K axiom: □(p -> q) -> (□p -> □q) -- valid in K
	k_axiom = Implies(Box(Implies(p, q)), Implies(Box(p), Box(q)))
	result_k = is_decidable_within(SYSTEM_K, k_axiom)
	(formula = "K axiom", valid = result_k.valid,
	 subformulas = result_k.subformula_count, bound = result_k.bound)
end

# ╔═╡ 10a1b3c4d-0011-0011-0011-000000000011
begin
	# □(consent) -> consent -- NOT valid in K (needs reflexivity)
	t_schema = Implies(Box(consent), consent)
	result_t = is_decidable_within(SYSTEM_K, t_schema)
	(formula = "T schema", valid_in_K = result_t.valid,
	 subformulas = result_t.subformula_count, bound = result_t.bound)
end

# ╔═╡ 10a1b3c4d-0012-0012-0012-000000000012
begin
	# Same formula IS valid in KT (which has reflexivity)
	result_kt = is_decidable_within(SYSTEM_KT, t_schema)
	(formula = "T schema in KT", valid_in_KT = result_kt.valid)
end

# ╔═╡ 10a1b3c4d-0032-0032-0032-000000000032
md"""
### Exercise 2: Calculating the Decidability Bound

Consider the sepsis guideline conjunction:

□(cultures) ∧ □(antibiotics) ∧ (bleeding → □(¬thrombolytic))

**a)** How many atomic propositions does this formula use?

**b)** List all subformulas (hint: there are 10 including atoms).

**c)** What is the theoretical upper bound on model size for `is_decidable_within`? Is brute-force feasible?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**a)** 3 atoms: cultures, antibiotics, thrombolytic (bleeding is also an atom — 4 total). **b)** The 10 subformulas are: cultures, antibiotics, thrombolytic, bleeding, ¬thrombolytic, □cultures, □antibiotics, □(¬thrombolytic), bleeding → □(¬thrombolytic), and the full conjunction. **c)** Bound = min(2^10, 4) = 4 worlds (Gamen caps at 4). With 4 worlds: 4² = 16 possible edges → 2^16 = 65,536 frames to enumerate — feasible in seconds. For real guidelines with 50+ subformulas the bound would be 2^50 worlds — far beyond brute force; tableaux are required."])))
"""

# ╔═╡ 10a1b3c4d-0013-0013-0013-000000000013
md"""
## The Cost of Decidability

Decidability is a *theoretical* guarantee -- it says an algorithm exists. It says nothing about how fast that algorithm runs. The brute-force approach (enumerate all frames and valuations) is **O(2^(n^2))** where n is the number of worlds, because the accessibility relation is a binary relation on n worlds (n^2 possible edges, each present or absent).

The table below shows why this matters:

| max\_worlds | Frames enumerated | Time estimate |
|:-----------|:-----------------|:-------------|
| 4 | 2^16 = 65,536 | seconds |
| 5 | 2^25 = 33,554,432 | minutes to hours |
| 6 | 2^36 ~ 69 billion | days |
| 16 | 2^256 | more than atoms in the universe |

Gamen.jl caps `max_worlds` at 4 for brute-force search. This is not a bug -- it is a fundamental complexity bound.
"""

# ╔═╡ 10a1b3c4d-0014-0014-0014-000000000014
md"""
### Interactive: Exponential Blowup

Use the slider to see how quickly frame counts explode:
"""

# ╔═╡ 10a1b3c4d-0015-0015-0015-000000000015
@bind n_worlds Slider(1:10, default=4, show_value=true)

# ╔═╡ 10a1b3c4d-0016-0016-0016-000000000016
begin
	n_edges = n_worlds^2
	n_frames = BigInt(2)^n_edges
	md"""
	**$(n_worlds) worlds** --> $(n_edges) possible edges --> **$(n_frames) frames** to enumerate

	$(n_worlds <= 4 ? "Feasible for brute-force search." : n_worlds <= 5 ? "Borderline -- will take minutes." : "Infeasible for brute-force enumeration. Tableaux required.")
	"""
end

# ╔═╡ 10a1b3c4d-0017-0017-0017-000000000017
md"""
## Consistency Checking for Guidelines

The `is_consistent` function checks whether a set of formulas can all be satisfied simultaneously in a model of the given system. For clinical guidelines, this is the core question: **can all the guidelines be followed at once?**
"""

# ╔═╡ 10a1b3c4d-0018-0018-0018-000000000018
begin
	# Two compatible guidelines
	g1 = Box(consent)                          # must obtain consent
	g2 = Diamond(antibiotics)                  # may give antibiotics
	compatible = is_consistent(SYSTEM_KD, [g1, g2])

	# Two conflicting guidelines
	g3 = Box(discharge)                        # must plan discharge
	g4 = Box(Not(discharge))                   # must NOT plan discharge
	conflicting = is_consistent(SYSTEM_KD, [g3, g4])

	(compatible_guidelines = compatible, conflicting_guidelines = conflicting)
end

# ╔═╡ 10a1b3c4d-0019-0019-0019-000000000019
md"""
The first pair is consistent -- there exists a model where consent is obligatory and antibiotics are permitted. The second pair is inconsistent -- no model can make both `Box(discharge)` and `Box(Not(discharge))` true at the same world (assuming at least one accessible world, which KD guarantees via the D axiom).
"""

# ╔═╡ 10a1b3c4d-0033-0033-0033-000000000033
md"""
### Exercise 3: Predicting Consistency

Before running `is_consistent`, predict whether each pair of guidelines is consistent in KD, and explain your reasoning.

**Pair A:** □(antibiotics) and □(antibiotics → cultures)

**Pair B:** □(antibiotics) and ¬◇(antibiotics)

**Pair C:** □(consent) and ◇(¬consent)

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"**Pair A: Consistent.** Both can be satisfied: if every accessible world has antibiotics true, and in every accessible world antibiotics implies cultures, then both hold simultaneously. No contradiction. **Pair B: Inconsistent.** □antibiotics means antibiotics is true in all accessible worlds. ¬◇antibiotics means no accessible world has antibiotics true (it is the dual: ¬◇p = □¬p). In KD there is always at least one accessible world, so □antibiotics and □(¬antibiotics) cannot both hold — contradiction. **Pair C: Consistent.** □consent means the current world obliges consent in all accessible worlds. ◇(¬consent) means there exists *some* accessible world without consent. But that world does not have to be the same one — wait, actually □consent requires consent in *all* accessible worlds, while ◇(¬consent) requires consent absent in *some* accessible world. These directly contradict each other. **Pair C is inconsistent** in KD (with at least one accessible world)."])))
"""

# ╔═╡ 10a1b3c4d-0020-0020-0020-000000000020
md"""
### Interactive: Pick Guidelines to Check

Select which guidelines to include and see whether they are jointly consistent:
"""

# ╔═╡ 10a1b3c4d-0021-0021-0021-000000000021
begin
	md"""
	Include G1 -- "must obtain consent" (Box(consent)): $(@bind inc_g1 CheckBox(default=true))

	Include G2 -- "may give antibiotics" (Diamond(antibiotics)): $(@bind inc_g2 CheckBox(default=true))

	Include G3 -- "must plan discharge" (Box(discharge)): $(@bind inc_g3 CheckBox(default=false))

	Include G4 -- "must NOT plan discharge" (Box(Not(discharge))): $(@bind inc_g4 CheckBox(default=false))

	Include G5 -- "if bleeding, must not give thrombolytics": $(@bind inc_g5 CheckBox(default=false))
	"""
end

# ╔═╡ 10a1b3c4d-0022-0022-0022-000000000022
begin
	selected_formulas = Formula[]
	selected_names = String[]
	if inc_g1
		push!(selected_formulas, Box(consent))
		push!(selected_names, "Box(consent)")
	end
	if inc_g2
		push!(selected_formulas, Diamond(antibiotics))
		push!(selected_names, "Diamond(antibiotics)")
	end
	if inc_g3
		push!(selected_formulas, Box(discharge))
		push!(selected_names, "Box(discharge)")
	end
	if inc_g4
		push!(selected_formulas, Box(Not(discharge)))
		push!(selected_names, "Box(Not(discharge))")
	end
	if inc_g5
		push!(selected_formulas, Implies(bleeding, Box(Not(thrombolytic))))
		push!(selected_names, "bleeding -> Box(Not(thrombolytic))")
	end

	if isempty(selected_formulas)
		md"*Select at least one guideline above.*"
	else
		consistent = is_consistent(SYSTEM_KD, selected_formulas)
		status = consistent ? "**Consistent** -- these guidelines can all be satisfied simultaneously." : "**Inconsistent** -- no model in KD satisfies all of these guidelines at once."
		md"""
		### Checking $(length(selected_formulas)) guideline(s):
		$(join(["- " * n for n in selected_names], "\n"))

		Result: $(status)
		"""
	end
end

# ╔═╡ 10a1b3c4d-0023-0023-0023-000000000023
md"""
## Practical Implications

For clinical guidelines involving a handful of propositions (3-5 atomic facts), decidability is not a practical problem. The brute-force search terminates in seconds for models with up to 4 worlds.

But real guideline sets can involve dozens of recommendations, each mentioning several clinical variables. With 20 atomic propositions, the subformula closure of a complex guideline formula could have 50+ elements, requiring models with up to 2^50 worlds -- far beyond brute force.

This is why we need smarter algorithms.
"""

# ╔═╡ 10a1b3c4d-0024-0024-0024-000000000024
md"""
## Tableaux as a Practical Decision Procedure

The **tableau method** (Chapter 6) implements decidability without enumerating all frames. Instead of asking "is there *any* model that satisfies these formulas?", a tableau asks "can I derive a contradiction from assuming they are all true?"

The tableau:
1. Assumes all guidelines hold at some world
2. Applies decomposition rules (breaking formulas into subformulas)
3. Applies modal rules (creating new worlds as needed)
4. Checks for contradictions (a proposition and its negation at the same world)

If every branch closes (contradiction found), the guidelines are **inconsistent**. If some branch stays open, the open branch *describes* a satisfying model.

**Key advantage**: the tableau often terminates much faster than brute force because it prunes branches early. It does not enumerate all possible frames -- it builds only the structure it needs.

See the [Chapter 6 notebook](ch6_tableaux.jl) for the full tableau treatment.
"""

# ╔═╡ 10a1b3c4d-0025-0025-0025-000000000025
md"""
## Filtrations: The Theoretical Engine

The decidability proof relies on **filtrations** -- a technique for collapsing a potentially infinite model into a finite one while preserving truth of all relevant formulas.

### The Idea

Given a model M and a finite set of formulas Gamma (typically the subformulas of the formula we are checking), a filtration identifies ("collapses") worlds that agree on every formula in Gamma. If two worlds make exactly the same formulas from Gamma true, they are **Gamma-equivalent** and get merged into a single equivalence class.

### The Clinical Analogy

Consider a hospital with thousands of patients. For a guideline about anticoagulation, only a few clinical facts matter: is the patient on warfarin? Is the INR above 3? Is there active bleeding? Two patients who agree on these facts are *equivalent with respect to this guideline*, even if they differ in age, weight, diagnosis, and a thousand other variables.

Filtration captures exactly this: irrelevant clinical details are collapsed away, leaving only the distinctions that matter for the formulas in question.
"""

# ╔═╡ 10a1b3c4d-0026-0026-0026-000000000026
begin
	# Demonstrate filtration collapsing equivalent worlds
	frame_big = KripkeFrame(
		[:s1, :s2, :s3, :s4],
		[:s1 => :s2, :s1 => :s3, :s1 => :s4]
	)
	# s2 and s3 agree on consent (both true); s4 differs
	model_big = KripkeModel(frame_big, [:consent => [:s1, :s2, :s3]])

	gamma = subformula_closure(Box(consent))
	classes = equivalence_classes(model_big, gamma)
	filt = finest_filtration(model_big, gamma)

	(original_worlds = length(model_big.frame.worlds),
	 equivalence_classes = length(classes),
	 filtration_preserves_truth = filtration_lemma_holds(filt))
end

# ╔═╡ 10a1b3c4d-0034-0034-0034-000000000034
md"""
**Before filtration** — four clinical scenarios (s1 sees s2, s3, s4):
"""

# ╔═╡ 10a1b3c4d-0035-0035-0035-000000000035
visualize_model(model_big)

# ╔═╡ 10a1b3c4d-0036-0036-0036-000000000036
md"""
**After filtration** — s2 and s3 merged into one equivalence class (both made consent true; same truth-value assignment for every formula in Γ = {consent, □consent}):
"""

# ╔═╡ 10a1b3c4d-0037-0037-0037-000000000037
visualize_model(filt.model)

# ╔═╡ 10a1b3c4d-0027-0027-0027-000000000027
md"""
Four clinical scenarios collapsed to $(length(classes)) equivalence classes. Worlds s2 and s3 were equivalent with respect to `{consent, Box(consent)}` -- they agreed on all relevant formulas -- so the filtration merged them. The **Filtration Lemma** (Theorem 5.5, B&D) guarantees that truth is preserved: `Box(consent)` is true at s1 in the original model if and only if it is true at the corresponding class in the filtration.
"""

# ╔═╡ 10a1b3c4d-0028-0028-0028-000000000028
md"""
### The Finiteness Bound

If Gamma has n formulas, the filtration has at most **2^n** equivalence classes -- one for each possible truth-value assignment to the n formulas. For a guideline formula with 5 subformulas, that means at most 32 worlds in the filtrated model, regardless of how many patients (worlds) the original model had.
"""

# ╔═╡ 10a1b3c4d-0029-0029-0029-000000000029
begin
	phi = And(Box(consent), Diamond(antibiotics))
	gamma2 = subformula_closure(phi)
	n_sub = length(gamma2)
	(formula_subformulas = n_sub, max_filtration_worlds = 2^n_sub)
end

# ╔═╡ 10a1b3c4d-0030-0030-0030-000000000030
md"""
## Summary

| Concept | Meaning for Guideline Checking |
|:--------|:-------------------------------|
| Finite model property | If guidelines are satisfiable at all, they are satisfiable in a finite model |
| Decidability | An algorithm always terminates with the correct consistency verdict |
| 2^n bound | The maximum model size needed, where n = number of subformulas |
| O(2^(n²)) brute force | Enumerating all frames is feasible only for tiny problems (max 4 worlds) |
| Filtration | Collapses irrelevant clinical distinctions, reducing model size |
| Tableau method | The practical decision procedure -- prunes early, avoids exhaustive enumeration |

**The bottom line**: decidability guarantees that automated guideline checking always terminates. The finite model property is the theoretical foundation. For practical performance on real guideline sets, the tableau method (Chapter 6) is essential -- it delivers the same guarantee without the exponential cost of brute-force enumeration.
"""

# ╔═╡ 10a1b3c4d-0038-0038-0038-000000000038
md"""
$(Markdown.MD(Markdown.Admonition("note", "Knowledge Representation Lens", [md"Davis, Shrobe & Szolovits (1993) identify five roles a knowledge representation must play. Role 4 is **medium for efficient computation**: 'The representation must be structured so that reasoning can be carried out efficiently.' Decidability and the finite model property are what make modal logic a tractable medium for automated guideline checking. First-order logic is undecidable — it cannot serve as an efficient computational medium for the consistency-checking task. Filtrations are the mathematical device that makes the computation tractable: they collapse the search space from potentially infinite models to models bounded by 2^n worlds (Proposition 5.12, B&D). The tableau method (Chapter 6) then delivers this same decidability guarantee without the 2^(n²) cost of brute-force frame enumeration — it is the engineering realisation of Role 4 for the guideline-checking problem. See also Buchanan (2006): 'making assumptions explicit is valuable' — the frame conditions we choose (K, KD, KT) determine what filtrations preserve and thus what the decision procedure can prove."])))
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
Gamen = "d58aead4-12fe-4bc4-9bd9-a7dede724567"
GraphMakie = "1ecd5474-83a3-4783-bb4f-06765db800d2"
Graphs = "86223c79-3864-5bf0-83f7-82e725a168b6"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"

[compat]
CairoMakie = "0.15"
Gamen = "~0.2"
GraphMakie = "0.6"
Graphs = "1"
PlutoUI = "~0.7.80"
"""

# ╔═╡ Cell order:
# ╟─10a1b3c4d-0001-0001-0001-000000000001
# ╟─10a1b3c4d-0002-0002-0002-000000000002
# ╟─10a1b3c4d-0003-0003-0003-000000000003
# ╟─10a1b3c4d-0004-0004-0004-000000000004
# ╟─10a1b3c4d-0005-0005-0005-000000000005
# ╟─10a1b3c4d-0006-0006-0006-000000000006
# ╟─10a1b3c4d-0007-0007-0007-000000000007
# ╟─10a1b3c4d-0031-0031-0031-000000000031
# ╟─10a1b3c4d-0008-0008-0008-000000000008
# ╟─10a1b3c4d-0009-0009-0009-000000000009
# ╟─10a1b3c4d-0010-0010-0010-000000000010
# ╟─10a1b3c4d-0011-0011-0011-000000000011
# ╟─10a1b3c4d-0012-0012-0012-000000000012
# ╟─10a1b3c4d-0032-0032-0032-000000000032
# ╟─10a1b3c4d-0013-0013-0013-000000000013
# ╟─10a1b3c4d-0014-0014-0014-000000000014
# ╟─10a1b3c4d-0015-0015-0015-000000000015
# ╟─10a1b3c4d-0016-0016-0016-000000000016
# ╟─10a1b3c4d-0017-0017-0017-000000000017
# ╟─10a1b3c4d-0018-0018-0018-000000000018
# ╟─10a1b3c4d-0019-0019-0019-000000000019
# ╟─10a1b3c4d-0033-0033-0033-000000000033
# ╟─10a1b3c4d-0020-0020-0020-000000000020
# ╟─10a1b3c4d-0021-0021-0021-000000000021
# ╟─10a1b3c4d-0022-0022-0022-000000000022
# ╟─10a1b3c4d-0023-0023-0023-000000000023
# ╟─10a1b3c4d-0024-0024-0024-000000000024
# ╟─10a1b3c4d-0025-0025-0025-000000000025
# ╟─10a1b3c4d-0026-0026-0026-000000000026
# ╟─10a1b3c4d-0034-0034-0034-000000000034
# ╟─10a1b3c4d-0035-0035-0035-000000000035
# ╟─10a1b3c4d-0036-0036-0036-000000000036
# ╟─10a1b3c4d-0037-0037-0037-000000000037
# ╟─10a1b3c4d-0027-0027-0027-000000000027
# ╟─10a1b3c4d-0028-0028-0028-000000000028
# ╟─10a1b3c4d-0029-0029-0029-000000000029
# ╟─10a1b3c4d-0030-0030-0030-000000000030
# ╟─10a1b3c4d-0038-0038-0038-000000000038
# ╟─00000000-0000-0000-0000-000000000001
