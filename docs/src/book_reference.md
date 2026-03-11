# Book Reference

This page maps definitions and propositions from
[Boxes and Diamonds](https://bd.openlogicproject.org) (B&D) by Richard Zach
to their implementations in Gamen.jl.

## Chapter 1: Syntax and Semantics

| B&D Reference | Description | Gamen.jl |
|:---|:---|:---|
| Definition 1.1 | Language of modal logic | [`Bottom`](@ref), [`Atom`](@ref), [`Box`](@ref), [`Diamond`](@ref) |
| Definition 1.2 | Formulas (inductive) | [`Formula`](@ref) type hierarchy |
| Definition 1.3 | Abbreviations (⊤, ↔) | [`Top`](@ref), [`Iff`](@ref) |
| Definition 1.6 | Model M = ⟨W, R, V⟩ | [`KripkeFrame`](@ref), [`KripkeModel`](@ref) |
| Definition 1.7 | Truth at a world | [`satisfies`](@ref) |
| Definition 1.9 | Truth in a model | [`is_true_in`](@ref) |
| Definition 1.11 | Validity in a class | [`is_valid`](@ref) |
| Definition 1.23 | Entailment | [`entails`](@ref) |
| Proposition 1.8 | □A ↔ ¬◇¬A duality | Verified in tests |

## Chapter 2: Frame Definability

| B&D Reference | Description | Gamen.jl |
|:---|:---|:---|
| Definition frd.3 | Frame F = ⟨W, R⟩ | [`KripkeFrame`](@ref) |
| Definition frd.4 | Validity on a frame | [`is_valid_on_frame`](@ref) |
| Definition frd.5 | Frame definability | Verified in tests (Corollary frd.8) |
| Table frd.1 | 5 core frame properties | [`is_serial`](@ref), [`is_reflexive`](@ref), [`is_symmetric`](@ref), [`is_transitive`](@ref), [`is_euclidean`](@ref) |
| Table frd.2 | 5 additional frame properties | [`is_partially_functional`](@ref), [`is_functional`](@ref), [`is_weakly_dense`](@ref), [`is_weakly_connected`](@ref), [`is_weakly_directed`](@ref) |
| Theorem frd.1 | Property → schema valid (soundness) | Verified in tests |
| Theorem frd.6 | Schema valid → property (definability) | Verified in tests |
| Corollary frd.8 | Full correspondence for D, T, B, 4, 5 | Verified in tests |
| Proposition frd.9 | Relationships between properties | Verified in tests |
| Definition frd.11 | Equivalence relation, universal | [`is_equivalence_relation`](@ref), [`is_universal`](@ref) |
| Proposition frd.12 | Equivalent characterizations of equivalence relations | Verified in tests |
| Proposition frd.14 | S5 = logic of equivalence/universal frames | Verified in tests |
| Definition frd.15 | Standard translation STₓ(φ) | [`standard_translation`](@ref) |
| Proposition frd.16 | Agreement of satisfaction and ST | Verified in tests |

## Chapter 3: Axiomatic Derivations

| B&D Reference | Description | Gamen.jl |
|:---|:---|:---|
| Definition 3.1 | Modus ponens | [`ModusPonens`](@ref) |
| Definition 3.2 | Necessitation | [`Necessitation`](@ref) |
| Definition 3.3 | Derivation | [`Derivation`](@ref), [`is_valid_derivation`](@ref) |
| Definition 3.5 | Normal modal logic (K, Dual) | [`SchemaK`](@ref), [`SchemaDual`](@ref) |
| Definition 3.9 | Modal system KA₁...Aₙ | [`ModalSystem`](@ref), [`SYSTEM_K`](@ref) |
| Definition 3.10 | Derivability in a system | [`is_valid_derivation`](@ref) |
| Proposition 3.12 | □A → □(B → A) K-provable | Verified in tests |
| Proposition 3.13 | □(A ∧ B) → (□A ∧ □B) K-provable | Verified in tests |
| Table 3.1 | Axiom schemas T, D, B, 4, 5 | [`SchemaT`](@ref), [`SchemaD`](@ref), [`SchemaB`](@ref), [`Schema4`](@ref), [`Schema5`](@ref) |
| Section 3.8 | Named systems (S4, S5, etc.) | [`SYSTEM_S4`](@ref), [`SYSTEM_S5`](@ref) |
| Definition 3.26 | Dual formulas | [`dual`](@ref) |
| Theorem 3.31 | Soundness | Verified in tests |

## Chapter 4: Completeness and Canonical Models

| B&D Reference | Description | Gamen.jl |
|:---|:---|:---|
| Definition 3.36 | Derivability from a set Γ ⊢_Σ A | [`is_derivable_from`](@ref) |
| Definition 3.39 | Σ-consistency | [`is_consistent`](@ref) |
| Definition 4.1 | Complete Σ-consistent sets | [`is_complete_consistent`](@ref) |
| Proposition 4.2 | Properties of complete consistent sets | Verified in tests |
| Theorem 4.3 | Lindenbaum's Lemma | [`lindenbaum_extend`](@ref) |
| Definition 4.5 | □Γ, ◇Γ, □⁻¹Γ, ◇⁻¹Γ | [`box_set`](@ref), [`diamond_set`](@ref), [`box_inverse`](@ref), [`diamond_inverse`](@ref) |
| Definition 4.11 | Canonical model M^Σ | [`CanonicalModel`](@ref), [`canonical_model`](@ref) |
| Proposition 4.12 | Truth Lemma | [`truth_lemma_holds`](@ref) |
| Definition 4.13 | Determination | [`determines`](@ref) |
| Theorem 4.14 | Determination theorem | Verified in tests |
| Corollary 4.15 | Completeness of K | Verified in tests |
| Theorem 4.16 | Frame completeness (D, T, B, 4, 5) | Verified in tests |
| Theorem 4.17 | General completeness theorem | Verified in tests |
| Proposition 4.18 | Additional frame properties of canonical models | Verified in tests |

## Chapter 5: Filtrations and Decidability

| B&D Reference | Description | Gamen.jl |
|:---|:---|:---|
| Definition 5.1 | Closed under subformulas, modally closed | [`is_closed_under_subformulas`](@ref), [`is_modally_closed`](@ref) |
| Definition 5.1 | Subformula closure, modal closure | [`subformula_closure`](@ref), [`modal_closure`](@ref) |
| Definition 5.2 | Γ-equivalence of worlds (u ≡_Γ v) | [`world_equivalent`](@ref) |
| Proposition 5.3 | Equivalence classes [w]_Γ | [`equivalence_classes`](@ref), [`equivalence_class`](@ref) |
| Definition 5.4 | Filtration M* = ⟨W*, R*, V*⟩ | [`Filtration`](@ref) |
| Theorem 5.5 | Filtration Lemma | [`filtration_lemma_holds`](@ref) |
| Definition 5.7 | Finest filtration | [`finest_filtration`](@ref) |
| Definition 5.9 | Coarsest filtration | [`coarsest_filtration`](@ref) |
| Proposition 5.12 | |W*| ≤ 2^|Γ| | Verified in tests |
| Proposition 5.14 | Finite model property (K) | [`has_finite_model_property`](@ref) |
| Theorem 5.17 | Decidability (K, S5) | [`is_decidable_within`](@ref) |
| Theorem 5.18 | Filtrations preserving symmetry/transitivity | [`symmetric_filtration`](@ref), [`transitive_filtration`](@ref) |

## Chapter 6: Modal Tableaux

| B&D Reference | Description | Gamen.jl |
|:---|:---|:---|
| Definition 6.1 | Prefixes σ ∈ (ℤ⁺)* \ {λ} | [`Prefix`](@ref), [`extend`](@ref), [`parent_prefix`](@ref) |
| Definition 6.1 | Prefixed signed formulas σ S A | [`PrefixedFormula`](@ref), [`pf_true`](@ref), [`pf_false`](@ref) |
| Definition 6.2 | Closed branch (σ T A and σ F A) | [`TableauBranch`](@ref), [`is_closed`](@ref) |
| Table 6.1 | Propositional rules (with prefixes) | Internal: `apply_propositional_rule` |
| Table 6.2 | Modal rules for K (□T, □F, ◇T, ◇F) | Internal: `apply_box_true_rule`, `apply_box_false_rule`, `apply_diamond_true_rule`, `apply_diamond_false_rule` |
| Theorem 6.6 | Soundness of tableau method | Verified in tests |
| Corollary 6.7 | Γ ⊢ A implies Γ ⊨ A | [`tableau_proves`](@ref) |
| Table 6.3 | Additional rules (T□, T◇, D□, D◇, B□, B◇, 4□, 4◇, 4T□, 4T◇) | Internal: `apply_T_box_rule`, `apply_D_box_rule`, `apply_B_box_rule`, `apply_4_box_rule`, `apply_4T_box_rule` |
| Table 6.4 | Tableau systems (K, KT, KD, KB, K4, S4, S5) | [`TABLEAU_K`](@ref), [`TABLEAU_KT`](@ref), [`TABLEAU_KD`](@ref), [`TABLEAU_KB`](@ref), [`TABLEAU_K4`](@ref), [`TABLEAU_S4`](@ref), [`TABLEAU_S5`](@ref) |
| Corollary 6.15 | Soundness for extended systems | Verified in tests |
| Definition 6.17 | Complete branch | Verified via [`build_tableau`](@ref) |
| Proposition 6.18 | Every finite Γ has complete tableau | [`build_tableau`](@ref) |
| Theorem 6.19 | Completeness: no closed tableau → satisfiable | Verified in tests |
| Corollary 6.20 | Γ ⊨ A → Γ ⊢ A | Verified in tests |
| Corollary 6.21 | ⊨ A → ⊢ A | Verified in tests |
| §6.9 | Countermodel extraction from open complete branch | [`extract_countermodel`](@ref) |

## Part IV: Applied Modal Logic

### Chapter 14: Temporal Logics

| B&D Reference | Description | Gamen.jl |
|:---|:---|:---|
| Definition 14.2 | Temporal formula grammar (P, H, F, G) | [`PastDiamond`](@ref), [`PastBox`](@ref), [`FutureDiamond`](@ref), [`FutureBox`](@ref) |
| Definition 14.2 | Since and Until binary operators | [`Since`](@ref), [`Until`](@ref) |
| Definition 14.3 | Temporal model M = ⟨T, ≺, V⟩ | [`TemporalModel`](@ref) (alias for `KripkeModel`) |
| Definition 14.4 | Truth for P, H, F, G operators | [`satisfies`](@ref) (methods for temporal types) |
| Definition 14.5 | Truth for S (since) and U (until) | [`satisfies`](@ref) (methods for `Since`, `Until`) |
| Table 14.1 | Frame correspondence properties | [`is_transitive_frame`](@ref), [`is_linear_frame`](@ref), [`is_dense_frame`](@ref), [`is_unbounded_past`](@ref), [`is_unbounded_future`](@ref) |

### Chapter 15: Epistemic Logics

| B&D Reference | Description | Gamen.jl |
|:---|:---|:---|
| Definition 15.1 | Agent-indexed knowledge operator K_a | [`Knowledge`](@ref) |
| Definition 15.2 | Epistemic formula grammar | [`Knowledge`](@ref) formula type |
| Definition 15.3 | Group knowledge E_{G'} A = ⋀_{b∈G'} K_b A | [`group_knows`](@ref) |
| Definition 15.3 | Common knowledge C_G A | [`common_knowledge`](@ref) |
| Definition 15.4 | Multi-agent model M = ⟨W, R, V⟩, R = {R_a} | [`EpistemicFrame`](@ref), [`EpistemicModel`](@ref) |
| Definition 15.5 | Truth: M,w ⊩ K_a B | [`satisfies`](@ref) (method for `Knowledge`) |
| Definition 15.6 | Common knowledge via transitive closure R_{G'} | [`common_knowledge`](@ref) |
| Table 15.1 | Four epistemic principles (Closure, Veridicality, Positive/Negative Introspection) | [`EPISTEMIC_K`](@ref), [`EPISTEMIC_KT`](@ref), [`EPISTEMIC_S4`](@ref), [`EPISTEMIC_S5`](@ref) |
| Definition 15.7 | Bisimulation between multi-agent models | [`is_bisimulation`](@ref) |
| Theorem 15.8 | Bisimilar worlds satisfy same formulas | [`bisimilar_worlds`](@ref) |
| Definition 15.9 | Public announcement language [B]C | [`Announce`](@ref) |
| Definition 15.10 | Extended epistemic formula grammar | [`Announce`](@ref) formula type |
| Definition 15.11 | Truth for [B]C; restricted model M\|B | [`satisfies`](@ref) (method for `Announce`), [`restrict_model`](@ref) |
