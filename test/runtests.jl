using Gamen
using Test

@testset "Gamen.jl" begin
    @testset "Formula construction and display" begin
        p = Atom(:p)
        q = Atom(:q)

        @test string(Bottom()) == "⊥"
        @test string(Top()) == "¬⊥"
        @test string(p) == "p"
        @test string(Not(p)) == "¬p"
        @test string(And(p, q)) == "(p ∧ q)"
        @test string(Or(p, q)) == "(p ∨ q)"
        @test string(Implies(p, q)) == "(p → q)"
        @test string(Iff(p, q)) == "(p ↔ q)"
        @test string(Box(p)) == "□p"
        @test string(Diamond(p)) == "◇p"
    end

    @testset "Indexed atoms (Def 1.1)" begin
        p0 = Atom(0)
        p1 = Atom(1)
        @test string(p0) == "p0"
        @test string(p1) == "p1"
    end

    @testset "Modal-free formulas" begin
        p = Atom(:p)
        @test is_modal_free(p) == true
        @test is_modal_free(And(p, Not(p))) == true
        @test is_modal_free(Box(p)) == false
        @test is_modal_free(Implies(p, Diamond(p))) == false
    end

    @testset "Figure 1.1 model (B&D)" begin
        # W = {w1, w2, w3}, R = {⟨w1,w2⟩, ⟨w1,w3⟩}
        # V(p) = {w1, w2}, V(q) = {w2}
        frame = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w1 => :w3])
        model = KripkeModel(frame, [:p => [:w1, :w2], :q => [:w2]])

        p = Atom(:p)
        q = Atom(:q)

        # Problem 1.1 from the book
        @test satisfies(model, :w1, q) == false            # 1. M,w1 ⊩ q? No
        @test satisfies(model, :w3, Not(q)) == true         # 2. M,w3 ⊩ ¬q
        @test satisfies(model, :w1, Or(p, q)) == true       # 3. M,w1 ⊩ p ∨ q
        @test satisfies(model, :w1, Box(Or(p, q))) == false # 4. M,w1 ⊮ □(p ∨ q) — w3 ⊮ p ∨ q
        @test satisfies(model, :w3, Box(q)) == true         # 5. M,w3 ⊩ □q (vacuously)
        @test satisfies(model, :w3, Box(Bottom())) == true   # 6. M,w3 ⊩ □⊥ (vacuously)
        @test satisfies(model, :w1, Diamond(q)) == true     # 7. M,w1 ⊩ ◇q
        @test satisfies(model, :w1, Box(q)) == false        # 8. M,w1 ⊩ □q? No (w3 ⊮ q)
        @test satisfies(model, :w1,                         # 9. M,w1 ⊮ ¬□□¬q — □¬q vacuously
            Not(Box(Box(Not(q))))) == false                #    true at w2,w3 (no successors)
    end

    @testset "Bottom and Top (Def 1.3)" begin
        frame = KripkeFrame([:w], Pair{Symbol,Symbol}[])
        model = KripkeModel(frame, [:p => [:w]])

        @test satisfies(model, :w, Bottom()) == false
        @test satisfies(model, :w, Top()) == true
    end

    @testset "Biconditional (Def 1.3)" begin
        frame = KripkeFrame([:w1, :w2], Pair{Symbol,Symbol}[])
        model = KripkeModel(frame, [:p => [:w1], :q => [:w1]])

        p = Atom(:p)
        q = Atom(:q)

        @test satisfies(model, :w1, Iff(p, q)) == true   # both true
        @test satisfies(model, :w2, Iff(p, q)) == true   # both false
    end

    @testset "Truth in a model (Def 1.9)" begin
        # A formula true at every world
        frame = KripkeFrame([:w1, :w2], Pair{Symbol,Symbol}[])
        model = KripkeModel(frame, [:p => [:w1, :w2]])

        p = Atom(:p)
        q = Atom(:q)

        @test is_true_in(model, p) == true    # p true everywhere
        @test is_true_in(model, q) == false   # q true nowhere
    end

    @testset "Proposition 1.8 (duality)" begin
        # □A ↔ ¬◇¬A and ◇A ↔ ¬□¬A
        # Verify on a specific model
        frame = KripkeFrame([:w1, :w2], [:w1 => :w2])
        model = KripkeModel(frame, [:p => [:w2]])

        p = Atom(:p)

        for w in [:w1, :w2]
            @test satisfies(model, w, Box(p)) ==
                  satisfies(model, w, Not(Diamond(Not(p))))
            @test satisfies(model, w, Diamond(p)) ==
                  satisfies(model, w, Not(Box(Not(p))))
        end
    end

    @testset "Entailment (Def 1.23)" begin
        frame = KripkeFrame([:w1, :w2], [:w1 => :w2])
        model = KripkeModel(frame, [:p => [:w1, :w2], :q => [:w1, :w2]])

        p = Atom(:p)
        q = Atom(:q)

        # p entails p ∨ q
        @test entails(model, p, Or(p, q)) == true
        # p, q entails p ∧ q
        @test entails(model, [p, q], And(p, q)) == true
    end

    @testset "Chapter 2: Frame Definability" begin
        p = Atom(:p)
        q = Atom(:q)

        @testset "atoms (helper)" begin
            @test atoms(Bottom()) == Set{Symbol}()
            @test atoms(p) == Set([:p])
            @test atoms(And(p, Or(q, Not(p)))) == Set([:p, :q])
            @test atoms(Box(Diamond(p))) == Set([:p])
        end

        @testset "Frame property predicates (Def 2.3)" begin
            # Reflexive frame
            reflexive = KripkeFrame([:w1, :w2], [:w1 => :w1, :w1 => :w2, :w2 => :w2])
            @test is_reflexive(reflexive) == true
            @test is_serial(reflexive) == true

            # Non-reflexive frame (w2 does not access itself)
            non_reflexive = KripkeFrame([:w1, :w2], [:w1 => :w1, :w1 => :w2])
            @test is_reflexive(non_reflexive) == false

            # Symmetric frame
            symmetric = KripkeFrame([:w1, :w2], [:w1 => :w2, :w2 => :w1])
            @test is_symmetric(symmetric) == true

            # Non-symmetric frame
            non_symmetric = KripkeFrame([:w1, :w2], [:w1 => :w2])
            @test is_symmetric(non_symmetric) == false

            # Transitive frame
            transitive = KripkeFrame([:w1, :w2, :w3],
                [:w1 => :w2, :w2 => :w3, :w1 => :w3])
            @test is_transitive(transitive) == true

            # Non-transitive frame (w1→w2, w2→w3, but no w1→w3)
            non_transitive = KripkeFrame([:w1, :w2, :w3],
                [:w1 => :w2, :w2 => :w3])
            @test is_transitive(non_transitive) == false

            # Serial frame (every world has a successor)
            serial = KripkeFrame([:w1, :w2], [:w1 => :w2, :w2 => :w1])
            @test is_serial(serial) == true

            # Non-serial frame (w3 has no successors)
            non_serial = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2])
            @test is_serial(non_serial) == false

            # Euclidean frame
            euclidean = KripkeFrame([:w1, :w2, :w3],
                [:w1 => :w2, :w1 => :w3, :w2 => :w2, :w2 => :w3, :w3 => :w2, :w3 => :w3])
            @test is_euclidean(euclidean) == true

            # Non-euclidean (w1→w2, w1→w3, but w2 does not access w3)
            non_euclidean = KripkeFrame([:w1, :w2, :w3],
                [:w1 => :w2, :w1 => :w3])
            @test is_euclidean(non_euclidean) == false
        end

        @testset "Frame validity (Def 2.1)" begin
            # □⊤ is valid on any frame (tautology under box)
            any_frame = KripkeFrame([:w1, :w2], [:w1 => :w2])
            @test is_valid_on_frame(any_frame, Box(Top())) == true

            # ⊥ is not valid on any frame
            @test is_valid_on_frame(any_frame, Bottom()) == false
        end

        @testset "Schema T: □p → p corresponds to reflexivity (Prop 2.5)" begin
            schema_t = Implies(Box(p), p)

            # Valid on reflexive frames
            reflexive = KripkeFrame([:w1, :w2],
                [:w1 => :w1, :w1 => :w2, :w2 => :w2])
            @test is_valid_on_frame(reflexive, schema_t) == true

            # Not valid on non-reflexive frames
            non_reflexive = KripkeFrame([:w1, :w2], [:w1 => :w2])
            @test is_valid_on_frame(non_reflexive, schema_t) == false
        end

        @testset "Schema D: □p → ◇p corresponds to seriality (Prop 2.7)" begin
            schema_d = Implies(Box(p), Diamond(p))

            # Valid on serial frames
            serial = KripkeFrame([:w1, :w2], [:w1 => :w2, :w2 => :w1])
            @test is_valid_on_frame(serial, schema_d) == true

            # Not valid on non-serial frames
            non_serial = KripkeFrame([:w1, :w2], [:w1 => :w2])
            @test is_valid_on_frame(non_serial, schema_d) == false
        end

        @testset "Schema B: p → □◇p corresponds to symmetry (Prop 2.9)" begin
            schema_b = Implies(p, Box(Diamond(p)))

            # Valid on symmetric frames
            symmetric = KripkeFrame([:w1, :w2],
                [:w1 => :w2, :w2 => :w1, :w1 => :w1, :w2 => :w2])
            @test is_valid_on_frame(symmetric, schema_b) == true

            # Not valid on non-symmetric frames
            non_symmetric = KripkeFrame([:w1, :w2], [:w1 => :w2, :w2 => :w2])
            @test is_valid_on_frame(non_symmetric, schema_b) == false
        end

        @testset "Schema 4: □p → □□p corresponds to transitivity (Prop 2.11)" begin
            schema_4 = Implies(Box(p), Box(Box(p)))

            # Valid on transitive frames
            transitive = KripkeFrame([:w1, :w2, :w3],
                [:w1 => :w2, :w2 => :w3, :w1 => :w3])
            @test is_valid_on_frame(transitive, schema_4) == true

            # Not valid on non-transitive frames
            non_transitive = KripkeFrame([:w1, :w2, :w3],
                [:w1 => :w2, :w2 => :w3])
            @test is_valid_on_frame(non_transitive, schema_4) == false
        end

        @testset "Schema 5: ◇p → □◇p corresponds to euclideanness (Prop 2.13)" begin
            schema_5 = Implies(Diamond(p), Box(Diamond(p)))

            # Valid on euclidean frames
            euclidean = KripkeFrame([:w1, :w2, :w3],
                [:w1 => :w2, :w1 => :w3, :w2 => :w2, :w2 => :w3, :w3 => :w2, :w3 => :w3])
            @test is_valid_on_frame(euclidean, schema_5) == true

            # Not valid on non-euclidean frames
            non_euclidean = KripkeFrame([:w1, :w2, :w3],
                [:w1 => :w2, :w1 => :w3])
            @test is_valid_on_frame(non_euclidean, schema_5) == false
        end

        @testset "Schema K: □(p→q) → (□p→□q) valid on all frames (Prop 1.19)" begin
            schema_k = Implies(□(Implies(p, q)), Implies(□(p), □(q)))

            frame1 = KripkeFrame([:w1, :w2], [:w1 => :w2])
            frame2 = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w2 => :w3])
            frame3 = KripkeFrame([:w1], [:w1 => :w1])

            @test is_valid_on_frame(frame1, schema_k) == true
            @test is_valid_on_frame(frame2, schema_k) == true
            @test is_valid_on_frame(frame3, schema_k) == true
        end

        @testset "Additional frame properties (Table frd.2)" begin
            # Partially functional: each world has at most one successor
            pf = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w2 => :w3])
            @test is_partially_functional(pf) == true

            not_pf = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w1 => :w3])
            @test is_partially_functional(not_pf) == false

            # Functional: each world has exactly one successor
            func = KripkeFrame([:w1, :w2], [:w1 => :w2, :w2 => :w1])
            @test is_functional(func) == true

            not_func_missing = KripkeFrame([:w1, :w2], [:w1 => :w2])
            @test is_functional(not_func_missing) == false  # w2 has no successor

            not_func_many = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w1 => :w3, :w2 => :w3, :w3 => :w1])
            @test is_functional(not_func_many) == false  # w1 has two successors

            # Weakly dense: every step decomposes into two steps
            wd = KripkeFrame([:w1, :w2], [:w1 => :w1, :w1 => :w2, :w2 => :w2])
            @test is_weakly_dense(wd) == true  # w1→w1→w2 decomposes w1→w2

            not_wd = KripkeFrame([:w1, :w2], [:w1 => :w2])
            @test is_weakly_dense(not_wd) == false  # w1→w2 can't decompose (w2 has no successors reaching w2)

            # Weakly connected: successors are comparable
            wc = KripkeFrame([:w1, :w2, :w3],
                [:w1 => :w2, :w1 => :w3, :w2 => :w3])
            @test is_weakly_connected(wc) == true

            not_wc = KripkeFrame([:w1, :w2, :w3],
                [:w1 => :w2, :w1 => :w3])  # w2 and w3 unrelated
            @test is_weakly_connected(not_wc) == false

            # Weakly directed (confluence): successors have a common successor
            wdir = KripkeFrame([:w1, :w2, :w3, :w4],
                [:w1 => :w2, :w1 => :w3, :w2 => :w4, :w3 => :w4, :w4 => :w4])
            @test is_weakly_directed(wdir) == true

            not_wdir = KripkeFrame([:w1, :w2, :w3],
                [:w1 => :w2, :w1 => :w3])  # w2 and w3 have no successors
            @test is_weakly_directed(not_wdir) == false
        end

        @testset "Equivalence relation and universal (Def frd.11)" begin
            equiv = KripkeFrame([:w1, :w2],
                [:w1 => :w1, :w2 => :w2, :w1 => :w2, :w2 => :w1])
            @test is_equivalence_relation(equiv) == true

            not_equiv = KripkeFrame([:w1, :w2], [:w1 => :w2, :w2 => :w1])
            @test is_equivalence_relation(not_equiv) == false  # not reflexive

            univ = KripkeFrame([:w1, :w2],
                [:w1 => :w1, :w1 => :w2, :w2 => :w1, :w2 => :w2])
            @test is_universal(univ) == true

            not_univ = KripkeFrame([:w1, :w2],
                [:w1 => :w1, :w1 => :w2, :w2 => :w2])
            @test is_universal(not_univ) == false  # w2 can't see w1
        end

        @testset "Table frd.2 correspondence results" begin
            # ◇p → □p corresponds to partially functional
            schema_pf = Implies(◇(p), □(p))

            pf_frame = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w2 => :w3])
            @test is_valid_on_frame(pf_frame, schema_pf) == true

            not_pf_frame = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w1 => :w3])
            @test is_valid_on_frame(not_pf_frame, schema_pf) == false

            # ◇p ↔ □p corresponds to functional
            schema_func = Iff(◇(p), □(p))

            func_frame = KripkeFrame([:w1, :w2], [:w1 => :w2, :w2 => :w1])
            @test is_valid_on_frame(func_frame, schema_func) == true

            not_func_frame = KripkeFrame([:w1, :w2], [:w1 => :w2])
            @test is_valid_on_frame(not_func_frame, schema_func) == false

            # □□p → □p corresponds to weakly dense
            schema_wd = Implies(□(□(p)), □(p))

            wd_frame = KripkeFrame([:w1, :w2],
                [:w1 => :w1, :w1 => :w2, :w2 => :w2])
            @test is_valid_on_frame(wd_frame, schema_wd) == true

            not_wd_frame = KripkeFrame([:w1, :w2], [:w1 => :w2])
            @test is_valid_on_frame(not_wd_frame, schema_wd) == false

            # Schema L: □((p ∧ □p) → q) ∨ □((q ∧ □q) → p)
            # corresponds to weakly connected
            schema_l = Or(
                □(Implies(And(p, □(p)), q)),
                □(Implies(And(q, □(q)), p))
            )

            wc_frame = KripkeFrame([:w1, :w2, :w3],
                [:w1 => :w2, :w1 => :w3, :w2 => :w3])
            @test is_valid_on_frame(wc_frame, schema_l) == true

            not_wc_frame = KripkeFrame([:w1, :w2, :w3],
                [:w1 => :w2, :w1 => :w3])
            @test is_valid_on_frame(not_wc_frame, schema_l) == false

            # Schema G: ◇□p → □◇p corresponds to weakly directed
            schema_g = Implies(◇(□(p)), □(◇(p)))

            wdir_frame = KripkeFrame([:w1, :w2, :w3, :w4],
                [:w1 => :w2, :w1 => :w3, :w2 => :w4, :w3 => :w4, :w4 => :w4])
            @test is_valid_on_frame(wdir_frame, schema_g) == true

            not_wdir_frame = KripkeFrame([:w1, :w2, :w3],
                [:w1 => :w2, :w1 => :w3])
            @test is_valid_on_frame(not_wdir_frame, schema_g) == false
        end

        @testset "Proposition frd.9: relationships between properties" begin
            # 1. Reflexive → serial
            reflexive = KripkeFrame([:w1, :w2],
                [:w1 => :w1, :w2 => :w2])
            @test is_reflexive(reflexive)
            @test is_serial(reflexive)

            # 2. Symmetric + transitive ↔ euclidean (when symmetric)
            sym_trans = KripkeFrame([:w1, :w2],
                [:w1 => :w2, :w2 => :w1, :w1 => :w1, :w2 => :w2])
            @test is_symmetric(sym_trans) && is_transitive(sym_trans)
            @test is_euclidean(sym_trans)

            # Euclidean + symmetric → transitive
            @test is_euclidean(sym_trans) && is_symmetric(sym_trans)
            @test is_transitive(sym_trans)

            # 3. Symmetric or euclidean → weakly directed
            sym_only = KripkeFrame([:w1, :w2], [:w1 => :w2, :w2 => :w1])
            @test is_symmetric(sym_only)
            @test is_weakly_directed(sym_only)

            euc = KripkeFrame([:w1, :w2, :w3],
                [:w1 => :w2, :w1 => :w3, :w2 => :w2, :w2 => :w3, :w3 => :w2, :w3 => :w3])
            @test is_euclidean(euc)
            @test is_weakly_directed(euc)

            # 4. Euclidean → weakly connected
            @test is_euclidean(euc)
            @test is_weakly_connected(euc)

            # 5. Functional → serial
            func = KripkeFrame([:w1, :w2], [:w1 => :w2, :w2 => :w1])
            @test is_functional(func)
            @test is_serial(func)
        end

        @testset "Proposition frd.12: equivalence relation characterizations" begin
            # Build a 3-world equivalence relation
            equiv3 = KripkeFrame([:w1, :w2, :w3],
                [:w1 => :w1, :w1 => :w2, :w1 => :w3,
                 :w2 => :w1, :w2 => :w2, :w2 => :w3,
                 :w3 => :w1, :w3 => :w2, :w3 => :w3])

            # Condition 1: equivalence relation (reflexive + symmetric + transitive)
            @test is_equivalence_relation(equiv3) == true

            # Condition 2: reflexive + euclidean
            @test is_reflexive(equiv3) && is_euclidean(equiv3)

            # Condition 3: serial + symmetric + euclidean
            @test is_serial(equiv3) && is_symmetric(equiv3) && is_euclidean(equiv3)

            # Condition 4: serial + symmetric + transitive
            @test is_serial(equiv3) && is_symmetric(equiv3) && is_transitive(equiv3)

            # Also verify: this is a universal frame (since all worlds see all worlds)
            @test is_universal(equiv3) == true

            # A non-universal equivalence relation: two equivalence classes
            equiv_two_classes = KripkeFrame([:w1, :w2, :w3],
                [:w1 => :w1, :w2 => :w2, :w2 => :w3, :w3 => :w2, :w3 => :w3])
            @test is_equivalence_relation(equiv_two_classes) == true
            @test is_universal(equiv_two_classes) == false
        end

        @testset "S5 on equivalence and universal frames (Prop frd.14)" begin
            # All of T, B, 4, 5 should be valid on equivalence frames
            schema_t = Implies(□(p), p)
            schema_b = Implies(p, □(◇(p)))
            schema_4 = Implies(□(p), □(□(p)))
            schema_5 = Implies(◇(p), □(◇(p)))

            equiv = KripkeFrame([:w1, :w2, :w3],
                [:w1 => :w1, :w1 => :w2, :w1 => :w3,
                 :w2 => :w1, :w2 => :w2, :w2 => :w3,
                 :w3 => :w1, :w3 => :w2, :w3 => :w3])

            @test is_valid_on_frame(equiv, schema_t) == true
            @test is_valid_on_frame(equiv, schema_b) == true
            @test is_valid_on_frame(equiv, schema_4) == true
            @test is_valid_on_frame(equiv, schema_5) == true

            # Also valid on a non-universal equivalence relation
            equiv2 = KripkeFrame([:w1, :w2, :w3],
                [:w1 => :w1, :w2 => :w2, :w2 => :w3, :w3 => :w2, :w3 => :w3])
            @test is_equivalence_relation(equiv2)
            @test is_valid_on_frame(equiv2, schema_t) == true
            @test is_valid_on_frame(equiv2, schema_b) == true
            @test is_valid_on_frame(equiv2, schema_4) == true
            @test is_valid_on_frame(equiv2, schema_5) == true
        end
    end

    @testset "Standard Translation (Definition frd.15)" begin
        p = Atom(:p)
        q = Atom(:q)
        x = FOVar(:x)

        @testset "Atomic formulas" begin
            # ST_x(⊥) = ⊥
            @test standard_translation(Bottom()) isa FOBottom

            # ST_x(⊤) = ⊤ (Top() = Not(Bottom()))
            @test standard_translation(Top()) isa FOTop

            # ST_x(p) = P_p(x)
            st_p = standard_translation(p)
            @test st_p isa FOPredicate
            @test st_p.name == :P_p
            @test length(st_p.args) == 1
            @test st_p.args[1].name == :x
        end

        @testset "Propositional connectives" begin
            # ST_x(¬p) = ¬P_p(x)
            st = standard_translation(Not(p))
            @test st isa FONot
            @test st.operand isa FOPredicate

            # ST_x(p ∧ q) = P_p(x) ∧ P_q(x)
            st = standard_translation(And(p, q))
            @test st isa FOAnd
            @test st.left isa FOPredicate
            @test st.right isa FOPredicate

            # ST_x(p ∨ q) = P_p(x) ∨ P_q(x)
            st = standard_translation(Or(p, q))
            @test st isa FOOr

            # ST_x(p → q) = P_p(x) → P_q(x)
            st = standard_translation(Implies(p, q))
            @test st isa FOImplies

            # ST_x(p ↔ q) = P_p(x) ↔ P_q(x)
            st = standard_translation(Iff(p, q))
            @test st isa FOIff
        end

        @testset "Modal operators" begin
            # ST_x(□p) = ∀y₁ (Q(x, y₁) → P_p(y₁))
            st = standard_translation(□(p))
            @test st isa FOForall
            y = st.var
            @test st.body isa FOImplies
            @test st.body.antecedent isa FOPredicate
            @test st.body.antecedent.name == :Q
            @test st.body.antecedent.args == [x, y]
            @test st.body.consequent isa FOPredicate
            @test st.body.consequent.name == :P_p
            @test st.body.consequent.args == [y]

            # ST_x(◇p) = ∃y₁ (Q(x, y₁) ∧ P_p(y₁))
            st = standard_translation(◇(p))
            @test st isa FOExists
            y = st.var
            @test st.body isa FOAnd
            @test st.body.left isa FOPredicate
            @test st.body.left.name == :Q
            @test st.body.right isa FOPredicate
            @test st.body.right.name == :P_p
            @test st.body.right.args == [y]
        end

        @testset "Nested modalities use fresh variables" begin
            # ST_x(□□p) = ∀y₁ (Q(x,y₁) → ∀y₂ (Q(y₁,y₂) → P_p(y₂)))
            st = standard_translation(□(□(p)))
            @test st isa FOForall
            y1 = st.var
            inner = st.body.consequent
            @test inner isa FOForall
            y2 = inner.var
            @test y1.name != y2.name  # distinct variables

            # The inner Q uses y₁ and y₂
            @test inner.body.antecedent.args == [y1, y2]
            # The innermost P uses y₂
            @test inner.body.consequent.args == [y2]
        end

        @testset "Pretty printing matches expected forms" begin
            # ST_x(□p → p) — Schema T
            st = standard_translation(Implies(□(p), p))
            expected = "(∀y₁ (Q(x, y₁) → P_p(y₁)) → P_p(x))"
            @test string(st) == expected

            # ST_x(◇p)
            st = standard_translation(◇(p))
            @test string(st) == "∃y₁ (Q(x, y₁) ∧ P_p(y₁))"
        end

        @testset "Custom starting variable" begin
            w = FOVar(:w)
            st = standard_translation(p, w)
            @test st isa FOPredicate
            @test st.args == [w]
        end
    end
end
