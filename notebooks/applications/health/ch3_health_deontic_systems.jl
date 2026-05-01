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

# ╔═╡ 8a1b1c1d-0001-0001-0001-000000000001
md"""
# Modal Systems and Clinical Reasoning

**A sepsis protocol reads**: "The clinician *must* draw blood cultures before administering antibiotics." An EHR alert fires this rule on every sepsis patient — but the hospital's ICU has a documented shortage of culture bottles. The rule fires. The bottles don't exist. Is the obligation still binding?

This is not a rhetorical question. It is a formal one, and the answer depends entirely on which **modal system** underlies your clinical decision support logic. If your system permits "dead-end" states where an obligation holds but compliance is literally impossible, the alert is worse than useless — it is actively misleading.

This notebook parallels [Chapter 3 of Boxes and Diamonds](https://bd.openlogicproject.org) (Axiomatic Derivations). We will work through the hierarchy of normal modal systems — K, KD, KT, S4, S5 — and show why **KD** is the minimal adequate logic for clinical guideline formalization. Every axiom corresponds to a structural assumption about clinical reality; getting that assumption wrong produces either an unsound system (one that proves false things) or an inadequate one (one that cannot prove true things).

By the end of this notebook, you will be able to:

- Explain what each standard axiom schema (K, D, T, 4, 5) means when Box is read as "is obligatory"
- Verify that an axiom schema is satisfied on a specific Kripke frame
- Identify why system K alone is insufficient for clinical obligations
- Explain why the T axiom collapses obligation into truth and is inappropriate for deontic reasoning
- Use Gamen.jl to check derivability of clinical inferences within different modal systems
"""

# ╔═╡ 8a1b1c1d-0002-0002-0002-000000000002
begin
	using Gamen
	using PlutoUI
	import CairoMakie, GraphMakie, Graphs
end

# ╔═╡ 8a1b1c1d-0003-0003-0003-000000000003
md"""
## Axiom Schemas in Clinical Terms

Every normal modal logic includes the **K** axiom. Additional schemas strengthen the system. Here is what each schema means when we read Box as "is obligatory":

| Schema | Formula | Clinical Reading |
|:-------|:--------|:-----------------|
| **K** | Box(A -> B) -> (Box(A) -> Box(B)) | If it's obligatory that A implies B, and A is obligatory, then B is obligatory |
| **D** | Box(A) -> Diamond(A) | If something is obligatory, it must be permitted (achievability) |
| **T** | Box(A) -> A | If something is obligatory, it's already the case |
| **4** | Box(A) -> Box(Box(A)) | If A is obligatory, it's obligatory that A is obligatory |
| **5** | Diamond(A) -> Box(Diamond(A)) | If A is permitted, it's obligatory that A is permitted |

Schema **K** is uncontroversial -- obligation distributes over implication. Schema **D** is the *achievability principle*: no obligation without the possibility of compliance. Schema **T** is too strong for deontic logic -- it collapses obligation into truth. Schemas **4** and **5** concern introspection of the normative system itself.
"""

# ╔═╡ 8a1b1c1d-0004-0004-0004-000000000004
md"""
### Checking Axiom Instances

Gamen.jl can verify that a formula matches an axiom schema via `is_instance`:
"""

# ╔═╡ 8a1b1c1d-0005-0005-0005-000000000005
begin
	# Clinical atoms
	consent = Atom(:consent)
	cultures = Atom(:cultures)
	antibiotics = Atom(:antibiotics)
	discharge = Atom(:discharge)
	p = Atom(:p)
	q = Atom(:q)

	# K instance: □(consent -> cultures) -> (□consent -> □cultures)
	k_clinical = Implies(
		□(Implies(consent, cultures)),
		Implies(□(consent), □(cultures))
	)

	# D instance: □consent -> ◇consent
	d_clinical = Implies(□(consent), ◇(consent))

	# T instance: □consent -> consent
	t_clinical = Implies(□(consent), consent)

	# 4 instance: □consent -> □□consent
	four_clinical = Implies(□(consent), □(□(consent)))

	(K = is_instance(k_clinical, SchemaK()),
	 D = is_instance(d_clinical, SchemaD()),
	 T = is_instance(t_clinical, SchemaT()),
	 four = is_instance(four_clinical, Schema4()))
end

# ╔═╡ 8a1b1c1d-0006-0006-0006-000000000006
md"""
### Semantic Validity on Different Frame Classes

Each axiom schema corresponds to a **frame condition** via the Sahlqvist correspondence (a systematic translation between modal axioms and first-order properties of the accessibility relation). A *frame condition* is a structural constraint on which worlds can access which others. We can check whether a formula is valid on frames with specific properties:
"""

# ╔═╡ 8a1b1c1d-0007-0007-0007-000000000007
begin
	# A serial frame -- every world has at least one successor (∀w ∃w' wRw')
	# This models "no dead-end clinical states": there is always an achievable next step
	serial_frame = KripkeFrame([:w1, :w2], [:w1 => :w2, :w2 => :w1])

	# A non-serial frame (w2 is a dead end) -- D may fail
	nonserial_frame = KripkeFrame([:w1, :w2], [:w1 => :w2])

	# A reflexive frame -- validates T (and D, since reflexive implies serial)
	reflexive_frame = KripkeFrame([:w1, :w2],
		[:w1 => :w1, :w2 => :w2, :w1 => :w2])

	d_axiom = Implies(□(p), ◇(p))
	t_axiom = Implies(□(p), p)

	(D_on_serial = is_valid_on_frame(serial_frame, d_axiom),
	 D_on_nonserial = is_valid_on_frame(nonserial_frame, d_axiom),
	 T_on_reflexive = is_valid_on_frame(reflexive_frame, t_axiom),
	 T_on_serial = is_valid_on_frame(serial_frame, t_axiom))
end

# ╔═╡ 8a1b1c1d-0028-0028-0028-000000000028
md"""
**Exercise 1.** A clinical informaticist argues: *"Our ICU protocol for ventilator weaning requires that at every point in care, there is always some next action available — the protocol never puts the patient in a state with no options."* Which frame condition does this commit to, and which axiom schema does it validate?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"The commitment is to **seriality**: every world wRw' has at least one successor w'. This is exactly the frame condition for the **D axiom** (□A → ◇A). If there is always a next clinical state, then whenever an action is obligatory (□A), there exists a reachable state where it can be performed (◇A). The appropriate modal system is **KD**. If the informaticist had instead said 'the current care state always satisfies all active obligations,' that would be reflexivity and the T axiom — but that collapses obligation into current fact, which is too strong."])))
"""

# ╔═╡ 8a1b1c1d-0008-0008-0008-000000000008
md"""
## Modal Systems Compared

Gamen.jl provides pre-defined modal systems. Each system is a collection of axiom schemas:
"""

# ╔═╡ 8a1b1c1d-0009-0009-0009-000000000009
begin
	systems = [
		(sys=SYSTEM_K,  interp="Minimal -- no assumptions about obligation structure"),
		(sys=SYSTEM_KD, interp="Obligations are achievable (serial frames)"),
		(sys=SYSTEM_KT, interp="Obligations are already fulfilled (reflexive frames)"),
		(sys=SYSTEM_S4, interp="Obligations are reflexive and transitive"),
		(sys=SYSTEM_S5, interp="Obligations form equivalence classes"),
	]

	table_rows = map(systems) do s
		schemas = join(string.(s.sys.schemas), ", ")
		"| **$(s.sys.name)** | $(schemas) | $(s.interp) |"
	end

	Markdown.parse("""
| System | Axioms | Clinical Interpretation |
|:-------|:-------|:----------------------|
$(join(table_rows, "\n"))
""")
end

# ╔═╡ 8a1b1c1d-0010-0010-0010-000000000010
md"""
## KD as the Logic of Clinical Guidelines

### Why K Alone is Insufficient

In system K, frames may contain **dead-end worlds** -- worlds with no accessible successors. At a dead-end world, *every* Box formula is vacuously true. This means a world can satisfy "consent is obligatory" even when consent is impossible to achieve:
"""

# ╔═╡ 8a1b1c1d-0011-0011-0011-000000000011
begin
	# A frame where w1 has a dead-end successor
	deadend_frame = KripkeFrame([:w1, :w2], [:w1 => :w2])
	# w2 has no successors -- every obligation is vacuously true there

	# At w2: □consent is true (vacuously), but ◇consent is false
	deadend_model = KripkeModel(deadend_frame, [:consent => Symbol[]])

	(obligation_at_deadend = satisfies(deadend_model, :w2, □(consent)),
	 permission_at_deadend = satisfies(deadend_model, :w2, ◇(consent)),
	 contradiction_obligatory = satisfies(deadend_model, :w2,
		□(And(consent, Not(consent)))))
end

# ╔═╡ 8a1b1c1d-0029-0029-0029-000000000029
visualize_model(deadend_model)

# ╔═╡ 8a1b1c1d-0012-0012-0012-000000000012
md"""
At w2 (the dead-end world):
- **Box(consent) = true** -- consent is "obligatory" (vacuously)
- **Diamond(consent) = false** -- consent is not *permitted* (no successor satisfies it)
- **Box(consent AND NOT consent) = true** -- even contradictions are "obligatory"

This is absurd for clinical reasoning. If a guideline says consent is obligatory, there must be some achievable scenario where consent is obtained.

### The D Axiom Fixes This

The **D axiom** (Box(A) -> Diamond(A)) says: if A is obligatory, then A is permitted. Its frame condition is **seriality** -- every world has at least one successor. This rules out dead-end worlds:
"""

# ╔═╡ 8a1b1c1d-0013-0013-0013-000000000013
begin
	# With seriality, obligations become achievable
	serial_clinical = KripkeFrame([:w1, :w2, :w3],
		[:w1 => :w2, :w2 => :w3, :w3 => :w1])

	serial_model = KripkeModel(serial_clinical, [:consent => [:w2, :w3]])

	# Now □consent at w1 requires consent in all successors (just w2)
	# And ◇consent is guaranteed whenever □consent holds
	(obligation = satisfies(serial_model, :w1, □(consent)),
	 permission = satisfies(serial_model, :w1, ◇(consent)),
	 d_holds = satisfies(serial_model, :w1, Implies(□(consent), ◇(consent))),
	 frame_is_serial = is_serial(serial_clinical))
end

# ╔═╡ 8a1b1c1d-0030-0030-0030-000000000030
visualize_model(serial_model)

# ╔═╡ 8a1b1c1d-0014-0014-0014-000000000014
md"""
### Why Not T? (Box(A) -> A)

Schema T says "if A is obligatory, then A is already the case." This is appropriate for *knowledge* (if you know it, it's true) but **wrong for obligation**. A clinician may be *obligated* to obtain consent even though consent has not yet been obtained -- that is precisely the situation where the obligation is most relevant.
"""

# ╔═╡ 8a1b1c1d-0015-0015-0015-000000000015
begin
	# In KT: □consent -> consent. But at w1, consent might not yet hold.
	pre_consent_frame = KripkeFrame([:w1, :w2], [:w1 => :w1, :w1 => :w2, :w2 => :w2])
	pre_consent_model = KripkeModel(pre_consent_frame,
		[:consent => [:w2]])  # consent not yet true at w1

	# T axiom fails: □consent is false at w1 (consent not true at w1 itself)
	# So obligation cannot even be stated before it's fulfilled
	(box_consent_w1 = satisfies(pre_consent_model, :w1, □(consent)),
	 consent_w1 = satisfies(pre_consent_model, :w1, consent),
	 t_axiom_at_w1 = satisfies(pre_consent_model, :w1, Implies(□(consent), consent)))
end

# ╔═╡ 8a1b1c1d-0016-0016-0016-000000000016
md"""
In a reflexive frame, Box(consent) at w1 requires consent to be true *at w1 itself*. This means we can never say "consent is obligatory but not yet obtained" -- the obligation would be false. For clinical deontic reasoning, we need obligation without presupposing fulfillment. **KD gives us exactly this.**
"""

# ╔═╡ 8a1b1c1d-0031-0031-0031-000000000031
md"""
**Exercise 2.** A hospital's ethics committee drafts a policy: *"It is obligatory that every patient admitted for elective surgery has completed an advance directive."* They propose formalizing this as □(advance_directive) in a reflexive frame (system KT).

(a) What does the T axiom say about this obligation?
(b) Is system KT appropriate here? What clinical absurdity results if it is used?
(c) Which system and frame condition should be used instead?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"(a) The T axiom says □A → A: if advance_directive is obligatory, it is *already true*. At every world, the obligation entails the fact. (b) KT is inappropriate. If we model the state of a patient just admitted (advance directive not yet completed), T would make □(advance_directive) false at that state — the obligation cannot even be stated about patients who have not yet fulfilled it. This defeats the purpose: a prescriptive obligation only matters when it has not yet been met. (c) System **KD** with a serial frame: □(advance_directive) can be true at a world where the directive is not yet complete, pointing to a reachable successor world where it is. The gap between obligation and current fact is exactly what KD preserves."])))
"""

# ╔═╡ 8a1b1c1d-0017-0017-0017-000000000017
md"""
## Derivation in KD

A **Hilbert-style derivation** is a finite sequence of formulas, each justified as either a tautological instance, an axiom instance of the system, or the result of applying Modus Ponens to two earlier lines (Definition 3.3, B&D). It shows that a formula follows from the axioms. Here we prove that in KD, if consent and cultures are both obligatory, then cultures are permitted:

**Claim**: Box(consent) AND Box(cultures) -> Diamond(cultures) is derivable in KD.
"""

# ╔═╡ 8a1b1c1d-0018-0018-0018-000000000018
begin
	# Proof: □cultures → ◇cultures is a direct D-axiom instance.
	# Then □consent ∧ □cultures → □cultures is a tautological instance.
	# Chain them with modus ponens.

	proof_kd = Derivation([
		# Step 1: (□consent ∧ □cultures) → □cultures  [tautological instance]
		ProofStep(
			Implies(And(□(consent), □(cultures)), □(cultures)),
			Tautology()),
		# Step 2: □cultures → ◇cultures  [D axiom instance]
		ProofStep(
			Implies(□(cultures), ◇(cultures)),
			AxiomInst(SchemaD())),
		# Step 3: (□cultures → ◇cultures) → ((□consent ∧ □cultures) → □cultures) → ((□consent ∧ □cultures) → ◇cultures)
		# Equivalently: chain via (a→b) → ((c→a) → (c→b))
		ProofStep(
			Implies(
				Implies(□(cultures), ◇(cultures)),
				Implies(
					Implies(And(□(consent), □(cultures)), □(cultures)),
					Implies(And(□(consent), □(cultures)), ◇(cultures)))),
			Tautology()),
		# Step 4: MP from 2, 3
		ProofStep(
			Implies(
				Implies(And(□(consent), □(cultures)), □(cultures)),
				Implies(And(□(consent), □(cultures)), ◇(cultures))),
			ModusPonens(2, 3)),
		# Step 5: MP from 1, 4
		ProofStep(
			Implies(And(□(consent), □(cultures)), ◇(cultures)),
			ModusPonens(1, 4)),
	])

	(valid_in_KD = is_valid_derivation(SYSTEM_KD, proof_kd),
	 valid_in_K = is_valid_derivation(SYSTEM_K, proof_kd),
	 conclusion = conclusion(proof_kd))
end

# ╔═╡ 8a1b1c1d-0019-0019-0019-000000000019
md"""
The proof is valid in **KD** but not in **K**, because it uses the D axiom (step 2). In system K, we cannot derive that obligations entail permissions -- dead-end worlds would be counterexamples.

We can also verify this semantically with `is_entailed_by`:
"""

# ╔═╡ 8a1b1c1d-0020-0020-0020-000000000020
begin
	premises = [And(□(consent), □(cultures))]
	goal = ◇(cultures)

	(derivable_in_KD = is_entailed_by(SYSTEM_KD, premises, goal),
	 derivable_in_K = is_entailed_by(SYSTEM_K, premises, goal))
end

# ╔═╡ 8a1b1c1d-0021-0021-0021-000000000021
md"""
## Interactive System Selector

Choose a modal system and see how it handles a set of clinical formulas:
"""

# ╔═╡ 8a1b1c1d-0022-0022-0022-000000000022
@bind selected_system Select([
	"K"  => "K -- minimal modal logic",
	"KD" => "KD -- serial frames (obligations achievable)",
	"KT" => "KT -- reflexive frames (obligations already true)",
	"S4" => "S4 -- reflexive + transitive",
	"S5" => "S5 -- equivalence relations",
])

# ╔═╡ 8a1b1c1d-0023-0023-0023-000000000023
begin
	system_map = Dict(
		"K"  => SYSTEM_K,
		"KD" => SYSTEM_KD,
		"KT" => SYSTEM_KT,
		"S4" => SYSTEM_S4,
		"S5" => SYSTEM_S5,
	)

	sys = system_map[selected_system]

	# Clinical formulas to test
	test_formulas = [
		("Box(p) -> Diamond(p)", "Obligation implies permission (D)",
			Implies(□(p), ◇(p))),
		("Box(p) -> p", "Obligation implies truth (T)",
			Implies(□(p), p)),
		("Box(p) -> Box(Box(p))", "Positive introspection (4)",
			Implies(□(p), □(□(p)))),
		("Diamond(p) -> Box(Diamond(p))", "Negative introspection (5)",
			Implies(◇(p), □(◇(p)))),
		("Box(p AND q) -> Box(p) AND Box(q)", "Distribution over conjunction",
			Implies(□(And(p, q)), And(□(p), □(q)))),
	]

	axiom_str = join(string.(sys.schemas), ", ")

	results = map(test_formulas) do (formula_str, desc, formula)
		deriv = is_entailed_by(sys, Formula[], formula)
		"| $(formula_str) | $(desc) | **$(deriv)** |"
	end

	Markdown.parse("""
	### System: **$(sys.name)** (axioms: $(axiom_str))

	| Formula | Meaning | Derivable? |
	|:--------|:--------|:-----------|
	$(join(results, "\n"))

	*Change the system above and watch the results update.*
	""")
end

# ╔═╡ 8a1b1c1d-0024-0024-0024-000000000024
md"""
## Soundness in Clinical Context

**Soundness** (Theorem 3.31, B&D) says: if a formula is derivable in a modal system, it is valid on the corresponding class of frames.

For KD, this means: **if we can prove a guideline consequence from the KD axioms, that consequence holds in every possible clinical scenario whose obligation structure is serial** (every state has at least one acceptable successor).

This is exactly what we want. Seriality is a minimal sanity condition -- it says obligations are achievable. Any clinical scenario that violates seriality (a state with no acceptable next step) is itself pathological. Soundness guarantees that our formal proofs respect all non-pathological scenarios.
"""

# ╔═╡ 8a1b1c1d-0032-0032-0032-000000000032
md"""
$(Markdown.MD(Markdown.Admonition("note", "Knowledge Representation Lens", [md"Davis, Shrobe & Szolovits (1993) identify five roles a knowledge representation must play. Role 3 is the **theory of reasoning**: the representation sanctions certain inferences and not others. In Gamen.jl, the modal system plays exactly this role — it determines which inferences are formally valid. Choosing KD over K sanctions the inference 'if consent is obligatory, then consent is achievable' (the D axiom). Choosing KT would additionally sanction 'if consent is obligatory, consent is already obtained' — a clinically false inference in any state where the obligation has not yet been fulfilled. Choosing K alone leaves dead-end worlds possible, sanctioning the inference 'everything is obligatory at impossible states' — which is logically consistent but clinically nonsensical. The choice of modal system is not merely technical: it reflects a commitment about which reasoning moves are permissible when formalizing clinical guidelines. Soundness (Theorem 3.31, B&D) gives this commitment teeth: every provable formula in KD is guaranteed true in all serial frames. This means EHR systems built on KD cannot derive false obligations from true premises, as long as the underlying clinical reality is serial (no impossible dead-end states)."])))
"""

# ╔═╡ 8a1b1c1d-0025-0025-0025-000000000025
begin
	# Verify soundness: the KD-derivable formula should be valid on serial frames
	# but may fail on non-serial frames
	kd_theorem = Implies(And(□(consent), □(cultures)), ◇(cultures))

	# Serial frame -- soundness says the theorem must hold
	s_frame = KripkeFrame([:w1, :w2, :w3],
		[:w1 => :w2, :w2 => :w3, :w3 => :w1])

	# Non-serial frame -- no guarantee
	ns_frame = KripkeFrame([:w1, :w2], [:w1 => :w2])

	(valid_on_serial = is_valid_on_frame(s_frame, kd_theorem),
	 valid_on_nonserial = is_valid_on_frame(ns_frame, kd_theorem),
	 serial_check = is_serial(s_frame),
	 nonserial_check = is_serial(ns_frame))
end

# ╔═╡ 8a1b1c1d-0026-0026-0026-000000000026
md"""
The theorem holds on the serial frame (as soundness guarantees) but fails on the non-serial frame. At the dead-end world w2, Box(cultures) is vacuously true but Diamond(cultures) is false -- an obligation exists with no way to fulfill it.
"""

# ╔═╡ 8a1b1c1d-0033-0033-0033-000000000033
md"""
**Exercise 3.** The ACC/AHA cholesterol guideline states: *"High-intensity statin therapy is recommended for patients aged 40–75 with diabetes and LDL ≥ 70 mg/dL."* A colleague translates this as □(statin_therapy) in system K.

(a) Construct a Kripke model in system K where □(statin_therapy) is true at some world w but ◇(statin_therapy) is false at the same world. What does this mean clinically?

(b) Why does moving to system KD eliminate this problem?

(c) Is □(statin_therapy) → statin_therapy appropriate here? Which system would it correspond to, and why is it wrong for this guideline?

$(Markdown.MD(Markdown.Admonition("hint", "Reveal answer", [md"(a) Let the frame have worlds {w, w2} with only w → w2, and let statin_therapy be false everywhere. At w2 (a dead-end), □(statin_therapy) is vacuously true but ◇(statin_therapy) is false — the guideline 'obligates' statin therapy even though no reachable state includes it. Clinically: the CDS alert fires, but no compliant care path exists. (b) KD adds seriality: every world has at least one successor. At any world where □(statin_therapy) is true, there must exist a reachable world where statin_therapy holds. The obligation implies achievability. (c) □(statin_therapy) → statin_therapy is the T axiom, corresponding to system KT (reflexive frames). It is wrong here: a diabetic patient with LDL ≥ 70 may not yet be on a statin. The whole point of the guideline is to direct prescribing for patients who are *not yet* on statins. T would make the obligation false for every patient who hasn't started therapy — defeating its prescriptive purpose."])))
"""

# ╔═╡ 8a1b1c1d-0027-0027-0027-000000000027
md"""
## Summary: Why KD for Clinical Guidelines

| Requirement | System | Verdict |
|:-----------|:-------|:--------|
| Obligations distribute over implication | K | Necessary -- included in all systems |
| Obligations must be achievable | KD | Essential -- the D axiom rules out impossible obligations |
| Obligations must already be fulfilled | KT | Too strong -- collapses "ought" into "is" |
| Obligations iterate (positive introspection) | S4 | Useful for meta-level reasoning, but not required for basic guidelines |
| Full introspection | S5 | Appropriate for knowledge, not obligation |

**KD is the minimal adequate system for clinical guideline reasoning.** It provides the achievability guarantee (no obligation without possibility of compliance) without collapsing deontic modality into truth. When EHR systems implement clinical decision support, the underlying logic should be at least as strong as KD -- otherwise, the system may encode obligations that are literally impossible to fulfill.
"""

# ╔═╡ Cell order:
# ╟─8a1b1c1d-0001-0001-0001-000000000001
# ╟─8a1b1c1d-0002-0002-0002-000000000002
# ╟─8a1b1c1d-0003-0003-0003-000000000003
# ╟─8a1b1c1d-0004-0004-0004-000000000004
# ╟─8a1b1c1d-0005-0005-0005-000000000005
# ╟─8a1b1c1d-0006-0006-0006-000000000006
# ╟─8a1b1c1d-0007-0007-0007-000000000007
# ╟─8a1b1c1d-0028-0028-0028-000000000028
# ╟─8a1b1c1d-0008-0008-0008-000000000008
# ╟─8a1b1c1d-0009-0009-0009-000000000009
# ╟─8a1b1c1d-0010-0010-0010-000000000010
# ╟─8a1b1c1d-0011-0011-0011-000000000011
# ╟─8a1b1c1d-0029-0029-0029-000000000029
# ╟─8a1b1c1d-0012-0012-0012-000000000012
# ╟─8a1b1c1d-0013-0013-0013-000000000013
# ╟─8a1b1c1d-0030-0030-0030-000000000030
# ╟─8a1b1c1d-0014-0014-0014-000000000014
# ╟─8a1b1c1d-0015-0015-0015-000000000015
# ╟─8a1b1c1d-0016-0016-0016-000000000016
# ╟─8a1b1c1d-0031-0031-0031-000000000031
# ╟─8a1b1c1d-0017-0017-0017-000000000017
# ╟─8a1b1c1d-0018-0018-0018-000000000018
# ╟─8a1b1c1d-0019-0019-0019-000000000019
# ╟─8a1b1c1d-0020-0020-0020-000000000020
# ╟─8a1b1c1d-0021-0021-0021-000000000021
# ╟─8a1b1c1d-0022-0022-0022-000000000022
# ╟─8a1b1c1d-0023-0023-0023-000000000023
# ╟─8a1b1c1d-0024-0024-0024-000000000024
# ╟─8a1b1c1d-0032-0032-0032-000000000032
# ╟─8a1b1c1d-0025-0025-0025-000000000025
# ╟─8a1b1c1d-0026-0026-0026-000000000026
# ╟─8a1b1c1d-0033-0033-0033-000000000033
# ╟─8a1b1c1d-0027-0027-0027-000000000027
