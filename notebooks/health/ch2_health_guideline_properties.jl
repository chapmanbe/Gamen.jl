### A Pluto.jl notebook ###
# v0.20.21

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

# ╔═╡ 7a1b3c4d-0001-0001-0001-000000000001
md"""
# Frame Properties of Clinical Guideline Systems

This notebook parallels [Chapter 2 of Boxes and Diamonds](https://bd.openlogicproject.org) (Frame Definability) but interprets frame properties through the lens of **clinical practice guidelines**.

**Key insight**: Different clinical contexts impose different structural properties on what counts as "acceptable." A guideline system that requires every clinical state to have at least one acceptable next step (seriality) behaves very differently from one where obligations automatically hold in the current state (reflexivity). These structural choices map directly to frame properties in Kripke semantics.
"""

# ╔═╡ 7a1b3c4d-0002-0002-0002-000000000002
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	using Gamen
	using PlutoUI
end

# ╔═╡ 7a1b3c4d-0003-0003-0003-000000000003
begin
	# Propositions used throughout this notebook
	p = Atom(:p)
	statin = Atom(:statin)
	consent = Atom(:consent)
	cultures = Atom(:cultures)
	discharge = Atom(:discharge)
end;

# ╔═╡ 7a1b3c4d-0004-0004-0004-000000000004
md"""
## 1. Seriality and the D Axiom: Obligations Must Be Achievable

**Schema D**: □p → ◇p — "If something is obligatory, it must be achievable."

A guideline system without seriality could contain **dead-end states** — clinical situations with no acceptable next step. At such a world, every obligation is vacuously true (even contradictory ones like □(statin ∧ ¬statin)), but no permission holds. This is pathological: it means the system declares things obligatory while simultaneously declaring them impossible.

**Clinical meaning**: Every clinical state must have at least one acceptable course of action. A protocol that leaves a clinician with zero compliant options is a broken protocol.
"""

# ╔═╡ 7a1b3c4d-0005-0005-0005-000000000005
begin
	# A serial frame: every world has at least one successor
	serial_frame = KripkeFrame(
		[:stable, :acute, :palliative],
		[:stable => :stable, :acute => :stable, :acute => :palliative, :palliative => :palliative]
	)

	# A non-serial frame: :terminal has no acceptable next step
	nonserial_frame = KripkeFrame(
		[:stable, :acute, :terminal],
		[:stable => :stable, :acute => :stable, :acute => :terminal]
	)

	(serial = is_serial(serial_frame), nonserial = is_serial(nonserial_frame))
end

# ╔═╡ 7a1b3c4d-0006-0006-0006-000000000006
begin
	schema_d = Implies(□(p), ◇(p))

	md"""
	The D axiom is **valid** on the serial frame: $(is_valid_on_frame(serial_frame, schema_d))

	The D axiom is **valid** on the non-serial frame: $(is_valid_on_frame(nonserial_frame, schema_d))

	At `:terminal` in the non-serial frame, □(statin) is vacuously true (no successors to check) but ◇(statin) is false (no successor where statin holds). The guideline says "you must prescribe a statin" while simultaneously offering no world where that is possible.
	"""
end

# ╔═╡ 7a1b3c4d-0007-0007-0007-000000000007
begin
	# Demonstrate vacuous obligations at the dead-end world
	nonserial_model = KripkeModel(nonserial_frame, [:statin => Symbol[]])

	md"""
	### Dead-end pathology at `:terminal`

	- □(statin) = $(satisfies(nonserial_model, :terminal, □(statin))) — vacuously true (no successors)
	- ◇(statin) = $(satisfies(nonserial_model, :terminal, ◇(statin))) — false (no successor at all)
	- □(statin ∧ ¬statin) = $(satisfies(nonserial_model, :terminal, □(And(statin, Not(statin))))) — even contradictions are "obligatory"

	This is why seriality matters: it prevents guideline systems from making vacuously impossible demands.
	"""
end

# ╔═╡ 7a1b3c4d-0008-0008-0008-000000000008
md"""
## 2. Reflexivity and the T Axiom: Current State Satisfies All Obligations

**Schema T**: □p → p — "If p is obligatory, then p is already the case."

In clinical terms, reflexivity means the current clinical state is always among the "acceptable" states. If prescribing a statin is obligatory (□statin), then the patient is *already* on a statin.

**This is too strong for most guideline systems.** The whole point of a clinical obligation is to direct action toward a state not yet achieved. "Must prescribe statin" presupposes the patient is *not* already on one. Reflexivity collapses the gap between obligation and fulfillment.
"""

# ╔═╡ 7a1b3c4d-0009-0009-0009-000000000009
begin
	# A reflexive frame — each world sees itself
	reflexive_frame = KripkeFrame(
		[:no_statin, :on_statin],
		[:no_statin => :no_statin, :no_statin => :on_statin,
		 :on_statin => :on_statin]
	)

	# A serial (but non-reflexive) frame — obligations point forward
	deontic_frame = KripkeFrame(
		[:no_statin, :on_statin],
		[:no_statin => :on_statin, :on_statin => :on_statin]
	)

	schema_t = Implies(□(p), p)

	md"""
	T axiom valid on reflexive frame: $(is_valid_on_frame(reflexive_frame, schema_t))

	T axiom valid on deontic (non-reflexive) frame: $(is_valid_on_frame(deontic_frame, schema_t))

	On the deontic frame, □(statin) can be true at `:no_statin` — the obligation holds even though the patient is not yet on a statin. This is the correct behavior for clinical guidelines.
	"""
end

# ╔═╡ 7a1b3c4d-0010-0010-0010-000000000010
begin
	deontic_model = KripkeModel(deontic_frame, [:statin => [:on_statin]])

	md"""
	### At `:no_statin` on the deontic frame:
	- □(statin) = $(satisfies(deontic_model, :no_statin, □(statin))) — statin is obligatory
	- statin = $(satisfies(deontic_model, :no_statin, statin)) — but the patient is not on a statin yet

	This is exactly what we want: the obligation motivates a change from the current state.
	"""
end

# ╔═╡ 7a1b3c4d-0011-0011-0011-000000000011
md"""
## 3. Transitivity and the 4 Axiom: Persistent Obligations

**Schema 4**: □p → □□p — "If p is obligatory, then it is obligatory that p remains obligatory."

In clinical terms, transitivity means obligations propagate through chains of acceptable states. If prescribing a statin is obligatory now, and you move to any acceptable state, it is still obligatory there.

**Clinical relevance**: Ongoing therapy requirements. A guideline stating "patients with ASCVD must remain on statin therapy" imposes an obligation that persists across follow-up visits. Each acceptable future state inherits the same obligation.
"""

# ╔═╡ 7a1b3c4d-0012-0012-0012-000000000012
begin
	# Transitive: obligations chain through follow-up visits
	transitive_frame = KripkeFrame(
		[:visit1, :visit2, :visit3],
		[:visit1 => :visit2, :visit2 => :visit3, :visit1 => :visit3]
	)

	# Non-transitive: obligation might not persist
	nontransitive_frame = KripkeFrame(
		[:visit1, :visit2, :visit3],
		[:visit1 => :visit2, :visit2 => :visit3]
	)

	schema_4 = Implies(□(p), □(□(p)))

	md"""
	Schema 4 valid on transitive frame: $(is_valid_on_frame(transitive_frame, schema_4))

	Schema 4 valid on non-transitive frame: $(is_valid_on_frame(nontransitive_frame, schema_4))

	Without transitivity, a statin obligation at visit 1 might hold through visit 2, but by visit 3 the obligation has "leaked" — it is no longer enforced. Transitivity prevents this.
	"""
end

# ╔═╡ 7a1b3c4d-0013-0013-0013-000000000013
md"""
## 4. Symmetry and the B Axiom: Reversible Decisions

**Schema B**: p → □◇p — "If p is the case, then in every accessible world, p is possible."

In clinical terms, symmetry means every clinical transition is reversible. If you can move from state A to state B, you can always move back.

**When this applies**: Medication changes that can be reversed (start a statin, then stop it if side effects occur). **When it does not**: Irreversible interventions — surgery, certain drug exposures, disease progression. A guideline system modeling surgical decisions should *not* assume symmetry.
"""

# ╔═╡ 7a1b3c4d-0014-0014-0014-000000000014
begin
	# Symmetric: medication adjustments are reversible
	symmetric_frame = KripkeFrame(
		[:low_dose, :high_dose],
		[:low_dose => :high_dose, :high_dose => :low_dose,
		 :low_dose => :low_dose, :high_dose => :high_dose]
	)

	# Non-symmetric: surgery is irreversible
	surgery_frame = KripkeFrame(
		[:pre_op, :post_op],
		[:pre_op => :post_op, :pre_op => :pre_op, :post_op => :post_op]
	)

	schema_b = Implies(p, □(◇(p)))

	md"""
	B axiom valid on symmetric (medication) frame: $(is_valid_on_frame(symmetric_frame, schema_b))

	B axiom valid on non-symmetric (surgery) frame: $(is_valid_on_frame(surgery_frame, schema_b))

	The surgery frame fails symmetry because `:pre_op` can reach `:post_op` but not vice versa. Once surgery is performed, the pre-operative state is no longer accessible — a fact that the frame structure correctly captures.
	"""
end

# ╔═╡ 7a1b3c4d-0015-0015-0015-000000000015
md"""
## 5. Interactive Frame Explorer

Toggle frame properties below and see which axiom schemas are valid on the resulting frame, and how clinical guideline formulas behave.
"""

# ╔═╡ 7a1b3c4d-0016-0016-0016-000000000016
begin
	md"""
	**Frame properties:**

	Reflexive: $(@bind prop_refl CheckBox(default=false)) Serial: $(@bind prop_serial CheckBox(default=true)) Transitive: $(@bind prop_trans CheckBox(default=false)) Symmetric: $(@bind prop_sym CheckBox(default=false))
	"""
end

# ╔═╡ 7a1b3c4d-0017-0017-0017-000000000017
begin
	# Build a 3-world frame with selected properties
	worlds = [:w1, :w2, :w3]
	edges = Pair{Symbol,Symbol}[]

	# Start with base edges
	push!(edges, :w1 => :w2)
	push!(edges, :w2 => :w3)

	# Add seriality: every world needs at least one successor
	if prop_serial
		push!(edges, :w3 => :w3)
	end

	# Add reflexivity
	if prop_refl
		push!(edges, :w1 => :w1)
		push!(edges, :w2 => :w2)
		if !prop_serial  # w3 => w3 may already be added
			push!(edges, :w3 => :w3)
		end
	end

	# Add symmetry
	if prop_sym
		push!(edges, :w2 => :w1)
		push!(edges, :w3 => :w2)
	end

	# Add transitivity
	if prop_trans
		push!(edges, :w1 => :w3)
		if prop_sym
			push!(edges, :w3 => :w1)
			push!(edges, :w2 => :w1)
		end
	end

	explorer_frame = KripkeFrame(worlds, unique(edges))

	# Check axiom schemas
	t_valid = is_valid_on_frame(explorer_frame, schema_t)
	d_valid = is_valid_on_frame(explorer_frame, schema_d)
	b_valid = is_valid_on_frame(explorer_frame, schema_b)
	four_valid = is_valid_on_frame(explorer_frame, schema_4)

	# Check clinical formulas on a sample model
	explorer_model = KripkeModel(explorer_frame, [
		:consent  => [:w1, :w2],
		:statin   => [:w2, :w3],
		:cultures => [:w2],
	])

	md"""
	### Frame properties (actual):
	- Reflexive: **$(is_reflexive(explorer_frame))** | Symmetric: **$(is_symmetric(explorer_frame))** | Transitive: **$(is_transitive(explorer_frame))** | Serial: **$(is_serial(explorer_frame))**

	### Axiom schemas valid on this frame:
	| Schema | Name | Valid? |
	|:-------|:-----|:-------|
	| T: □p → p | Reflexivity | **$(t_valid)** |
	| D: □p → ◇p | Seriality | **$(d_valid)** |
	| B: p → □◇p | Symmetry | **$(b_valid)** |
	| 4: □p → □□p | Transitivity | **$(four_valid)** |

	### Clinical formulas at w1:
	| Guideline | Formula | Satisfied? |
	|:----------|:--------|:-----------|
	| Must obtain consent | □(consent) | **$(satisfies(explorer_model, :w1, □(consent)))** |
	| Must prescribe statin | □(statin) | **$(satisfies(explorer_model, :w1, □(statin)))** |
	| May draw cultures | ◇(cultures) | **$(satisfies(explorer_model, :w1, ◇(cultures)))** |
	"""
end

# ╔═╡ 7a1b3c4d-0018-0018-0018-000000000018
md"""
## 6. Why KD for Clinical Guidelines

Three candidate logics for formalizing clinical obligations:

**K alone** (no extra axioms): Allows dead-end worlds where every obligation is vacuously true and every permission is false. A guideline system in K could require "prescribe statin" at a state with no acceptable options — logically consistent but clinically meaningless.

**KT** (K + reflexivity): The current state always satisfies all obligations. "Must prescribe statin" entails the patient is already on a statin. This eliminates the motivating force of guidelines.

**KD** (K + seriality): Every state has at least one acceptable next step, so obligations are always achievable. But the current state need not satisfy its own obligations — an obligation genuinely directs action. This is the sweet spot for deontic logic.
"""

# ╔═╡ 7a1b3c4d-0019-0019-0019-000000000019
begin
	# KD frame: serial but not reflexive
	kd_frame = KripkeFrame(
		[:current, :compliant, :alternative],
		[:current => :compliant, :current => :alternative,
		 :compliant => :compliant, :alternative => :alternative]
	)

	kd_model = KripkeModel(kd_frame, [
		:statin   => [:compliant],
		:consent  => [:compliant, :alternative],
		:cultures => [:alternative],
	])

	md"""
	### KD frame check:
	- Serial: $(is_serial(kd_frame)) (D axiom holds)
	- Reflexive: $(is_reflexive(kd_frame)) (T axiom does not hold)

	### At `:current`:
	- □(consent) = $(satisfies(kd_model, :current, □(consent))) — consent is obligatory (holds in all acceptable worlds)
	- □(statin) = $(satisfies(kd_model, :current, □(statin))) — statin is not obligatory (only in `:compliant`, not `:alternative`)
	- ◇(statin) = $(satisfies(kd_model, :current, ◇(statin))) — statin is permitted (achievable in at least one world)
	- ◇(cultures) = $(satisfies(kd_model, :current, ◇(cultures))) — cultures are permitted

	The D axiom guarantees: if □(consent) holds, then ◇(consent) must also hold. Obligations are never empty promises.
	"""
end

# ╔═╡ 7a1b3c4d-0020-0020-0020-000000000020
md"""
## 7. Validity on Different Frame Classes

Some formulas are valid on *all* serial frames, others only on reflexive frames, and some on all frames. Let's compare using hand-built examples.
"""

# ╔═╡ 7a1b3c4d-0021-0021-0021-000000000021
begin
	# Schema K: □(p → q) → (□p → □q) — valid on ALL frames
	q = Atom(:q)
	schema_k = Implies(□(Implies(p, q)), Implies(□(p), □(q)))

	# Three frames with different properties
	f_bare = KripkeFrame([:a, :b], [:a => :b])               # not serial (b has no successor)
	f_serial = KripkeFrame([:a, :b], [:a => :b, :b => :a])   # serial, not reflexive
	f_refl = KripkeFrame([:a, :b], [:a => :a, :a => :b, :b => :b])  # reflexive (hence serial)

	md"""
	| Formula | All frames (f\_bare) | Serial frames (f\_serial) | Reflexive frames (f\_refl) |
	|:--------|:---------------------|:--------------------------|:---------------------------|
	| K: □(p→q)→(□p→□q) | $(is_valid_on_frame(f_bare, schema_k)) | $(is_valid_on_frame(f_serial, schema_k)) | $(is_valid_on_frame(f_refl, schema_k)) |
	| D: □p→◇p | $(is_valid_on_frame(f_bare, schema_d)) | $(is_valid_on_frame(f_serial, schema_d)) | $(is_valid_on_frame(f_refl, schema_d)) |
	| T: □p→p | $(is_valid_on_frame(f_bare, schema_t)) | $(is_valid_on_frame(f_serial, schema_t)) | $(is_valid_on_frame(f_refl, schema_t)) |

	- **K** is valid everywhere — it's a property of the □ operator itself, not the frame.
	- **D** fails on bare frames (dead ends) but holds on all serial and reflexive frames.
	- **T** fails unless the frame is reflexive. Reflexivity is strictly stronger than seriality.
	"""
end

# ╔═╡ 7a1b3c4d-0022-0022-0022-000000000022
md"""
## 8. Summary: Frame Properties as Clinical Requirements

| Frame Property | Axiom | Clinical Meaning | Appropriate for Guidelines? |
|:---------------|:------|:-----------------|:---------------------------|
| **Seriality** | D: □p → ◇p | Every state has at least one acceptable next step | Yes — the core deontic property |
| **Reflexivity** | T: □p → p | Current state satisfies all its obligations | No — collapses obligation and fulfillment |
| **Transitivity** | 4: □p → □□p | Obligations persist through chains of acceptable states | Sometimes — for ongoing therapy requirements |
| **Symmetry** | B: p → □◇p | All clinical transitions are reversible | Rarely — not for surgery or disease progression |
| **Euclideanness** | 5: ◇p → □◇p | All acceptable states agree on what is possible | Rarely — overly constraining for clinical variation |

**The takeaway**: KD (K + seriality) is the minimal logic that prevents pathological guideline behavior. It ensures obligations are always achievable without making the overly strong assumption that obligations are already fulfilled. More properties can be added when the clinical context warrants them — transitivity for chronic disease management, symmetry for reversible medication decisions — but seriality is the non-negotiable foundation.
"""

# ╔═╡ Cell order:
# ╟─7a1b3c4d-0001-0001-0001-000000000001
# ╠═7a1b3c4d-0002-0002-0002-000000000002
# ╠═7a1b3c4d-0003-0003-0003-000000000003
# ╟─7a1b3c4d-0004-0004-0004-000000000004
# ╠═7a1b3c4d-0005-0005-0005-000000000005
# ╠═7a1b3c4d-0006-0006-0006-000000000006
# ╠═7a1b3c4d-0007-0007-0007-000000000007
# ╟─7a1b3c4d-0008-0008-0008-000000000008
# ╠═7a1b3c4d-0009-0009-0009-000000000009
# ╠═7a1b3c4d-0010-0010-0010-000000000010
# ╟─7a1b3c4d-0011-0011-0011-000000000011
# ╠═7a1b3c4d-0012-0012-0012-000000000012
# ╟─7a1b3c4d-0013-0013-0013-000000000013
# ╠═7a1b3c4d-0014-0014-0014-000000000014
# ╟─7a1b3c4d-0015-0015-0015-000000000015
# ╠═7a1b3c4d-0016-0016-0016-000000000016
# ╠═7a1b3c4d-0017-0017-0017-000000000017
# ╟─7a1b3c4d-0018-0018-0018-000000000018
# ╠═7a1b3c4d-0019-0019-0019-000000000019
# ╟─7a1b3c4d-0020-0020-0020-000000000020
# ╠═7a1b3c4d-0021-0021-0021-000000000021
# ╟─7a1b3c4d-0022-0022-0022-000000000022
