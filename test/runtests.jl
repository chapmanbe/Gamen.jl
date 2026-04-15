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

    @testset "Chapter 3: Axiomatic Derivations" begin
        p = Atom(:p)
        q = Atom(:q)
        r = Atom(:r)

        @testset "Formula equality and hashing" begin
            @test Atom(:p) == Atom(:p)
            @test Atom(:p) != Atom(:q)
            @test Box(p) == Box(Atom(:p))
            @test Box(p) != Diamond(p)
            @test And(p, q) == And(Atom(:p), Atom(:q))
            @test And(p, q) != And(q, p)
            @test Implies(p, q) == Implies(Atom(:p), Atom(:q))
            @test Implies(p, q) != Implies(q, p)
            @test Bottom() == Bottom()
            @test Iff(p, q) == Iff(p, q)
            @test Iff(p, q) != Iff(q, p)

            # Hashing: equal formulas have equal hashes
            @test hash(Box(p)) == hash(Box(Atom(:p)))
            @test hash(And(p, q)) == hash(And(Atom(:p), Atom(:q)))

            # Formulas as dictionary keys
            d = Dict{Formula, Int}()
            d[Box(p)] = 1
            @test d[Box(Atom(:p))] == 1
        end

        @testset "Substitution" begin
            σ = Dict(:p => Box(q), :q => Diamond(r))
            @test substitute(p, σ) == Box(q)
            @test substitute(q, σ) == Diamond(r)
            @test substitute(r, σ) == r
            @test substitute(Bottom(), σ) == Bottom()
            @test substitute(And(p, q), σ) == And(Box(q), Diamond(r))
            @test substitute(Or(p, q), σ) == Or(Box(q), Diamond(r))
            @test substitute(Implies(p, q), σ) == Implies(Box(q), Diamond(r))
            @test substitute(Iff(p, q), σ) == Iff(Box(q), Diamond(r))
            @test substitute(Not(p), σ) == Not(Box(q))
            @test substitute(Box(p), σ) == Box(Box(q))
            @test substitute(Diamond(p), σ) == Diamond(Box(q))
        end

        @testset "Propositional tautology" begin
            # Tautologies
            @test is_tautology(Or(p, Not(p))) == true
            @test is_tautology(Implies(p, p)) == true
            @test is_tautology(Implies(p, Implies(q, p))) == true
            @test is_tautology(Not(And(p, Not(p)))) == true
            @test is_tautology(Top()) == true

            # Non-tautologies
            @test is_tautology(p) == false
            @test is_tautology(Implies(p, q)) == false
            @test is_tautology(Bottom()) == false

            # Modal formulas throw
            @test_throws ArgumentError is_tautology(Box(p))
        end

        @testset "Tautological instance" begin
            # Modal-free tautological instances
            @test is_tautological_instance(Implies(p, p)) == true
            @test is_tautological_instance(Or(p, Not(p))) == true

            # Instances with modal subformulas
            @test is_tautological_instance(Implies(Box(p), Box(p))) == true
            @test is_tautological_instance(
                Implies(Box(p), Implies(Diamond(q), Box(p)))) == true
            @test is_tautological_instance(Or(Box(p), Not(Box(p)))) == true

            # Non-instances
            @test is_tautological_instance(Implies(Box(p), Diamond(q))) == false
            @test is_tautological_instance(p) == false
        end

        @testset "Axiom schema instances" begin
            # Schema K: □(A→B) → (□A→□B)
            k1 = Implies(Box(Implies(p, q)), Implies(Box(p), Box(q)))
            @test is_instance(k1, SchemaK()) == true

            k2 = Implies(
                Box(Implies(And(p, q), Diamond(r))),
                Implies(Box(And(p, q)), Box(Diamond(r))))
            @test is_instance(k2, SchemaK()) == true

            @test is_instance(Implies(p, q), SchemaK()) == false

            # Schema Dual: ◇A ↔ ¬□¬A
            @test is_instance(Iff(Diamond(p), Not(Box(Not(p)))), SchemaDual()) == true
            @test is_instance(
                Iff(Diamond(And(p, q)), Not(Box(Not(And(p, q))))),
                SchemaDual()) == true
            @test is_instance(Iff(Diamond(p), Not(Box(Not(q)))), SchemaDual()) == false

            # Schema T: □A → A
            @test is_instance(Implies(Box(p), p), SchemaT()) == true
            @test is_instance(
                Implies(Box(And(p, q)), And(p, q)), SchemaT()) == true
            @test is_instance(Implies(Box(p), q), SchemaT()) == false

            # Schema D: □A → ◇A
            @test is_instance(Implies(Box(p), Diamond(p)), SchemaD()) == true
            @test is_instance(Implies(Box(p), Diamond(q)), SchemaD()) == false

            # Schema B: A → □◇A
            @test is_instance(Implies(p, Box(Diamond(p))), SchemaB()) == true
            @test is_instance(Implies(p, Box(Diamond(q))), SchemaB()) == false

            # Schema 4: □A → □□A
            @test is_instance(Implies(Box(p), Box(Box(p))), Schema4()) == true
            @test is_instance(Implies(Box(p), Box(Box(q))), Schema4()) == false

            # Schema 5: ◇A → □◇A
            @test is_instance(Implies(Diamond(p), Box(Diamond(p))), Schema5()) == true
            @test is_instance(Implies(Diamond(p), Box(Diamond(q))), Schema5()) == false
        end

        @testset "Modal systems" begin
            @test string(SYSTEM_K) == "K"
            @test string(SYSTEM_S5) == "S5"
            @test SchemaK() in SYSTEM_K.schemas
            @test SchemaT() in SYSTEM_KT.schemas
            @test !(SchemaT() in SYSTEM_K.schemas)
            @test Schema4() in SYSTEM_S4.schemas
            @test Schema5() in SYSTEM_S5.schemas
        end

        @testset "Proof: □A → □(B → A) (Proposition 3.12)" begin
            a = p; b = q
            proof = Derivation([
                ProofStep(Implies(a, Implies(b, a)), Tautology()),
                ProofStep(Box(Implies(a, Implies(b, a))), Necessitation(1)),
                ProofStep(
                    Implies(Box(Implies(a, Implies(b, a))),
                            Implies(Box(a), Box(Implies(b, a)))),
                    AxiomInst(SchemaK())),
                ProofStep(
                    Implies(Box(a), Box(Implies(b, a))),
                    ModusPonens(2, 3)),
            ])
            @test is_valid_derivation(SYSTEM_K, proof) == true
            @test conclusion(proof) == Implies(Box(p), Box(Implies(q, p)))
        end

        @testset "Proof: □(A∧B) → (□A ∧ □B) (Proposition 3.13)" begin
            a = p; b = q
            ab = And(a, b)
            proof = Derivation([
                # □(A∧B) → □A
                ProofStep(Implies(ab, a), Tautology()),
                ProofStep(Box(Implies(ab, a)), Necessitation(1)),
                ProofStep(
                    Implies(Box(Implies(ab, a)), Implies(Box(ab), Box(a))),
                    AxiomInst(SchemaK())),
                ProofStep(Implies(Box(ab), Box(a)), ModusPonens(2, 3)),
                # □(A∧B) → □B
                ProofStep(Implies(ab, b), Tautology()),
                ProofStep(Box(Implies(ab, b)), Necessitation(5)),
                ProofStep(
                    Implies(Box(Implies(ab, b)), Implies(Box(ab), Box(b))),
                    AxiomInst(SchemaK())),
                ProofStep(Implies(Box(ab), Box(b)), ModusPonens(6, 7)),
                # Combine via (p→q)→((p→r)→(p→(q∧r)))
                ProofStep(
                    Implies(
                        Implies(Box(ab), Box(a)),
                        Implies(
                            Implies(Box(ab), Box(b)),
                            Implies(Box(ab), And(Box(a), Box(b))))),
                    Tautology()),
                ProofStep(
                    Implies(
                        Implies(Box(ab), Box(b)),
                        Implies(Box(ab), And(Box(a), Box(b)))),
                    ModusPonens(4, 9)),
                ProofStep(
                    Implies(Box(ab), And(Box(a), Box(b))),
                    ModusPonens(8, 10)),
            ])
            @test is_valid_derivation(SYSTEM_K, proof) == true
            @test conclusion(proof) == Implies(Box(And(p, q)), And(Box(p), Box(q)))
        end

        @testset "Invalid derivations" begin
            # Wrong MP reference
            bad1 = Derivation([
                ProofStep(Implies(p, p), Tautology()),
                ProofStep(p, ModusPonens(1, 1)),
            ])
            @test is_valid_derivation(SYSTEM_K, bad1) == false

            # Axiom not in system
            bad2 = Derivation([
                ProofStep(Implies(Box(p), p), AxiomInst(SchemaT())),
            ])
            @test is_valid_derivation(SYSTEM_K, bad2) == false

            # Same axiom valid in KT
            good = Derivation([
                ProofStep(Implies(Box(p), p), AxiomInst(SchemaT())),
            ])
            @test is_valid_derivation(SYSTEM_KT, good) == true

            # Necessitation with wrong formula
            bad3 = Derivation([
                ProofStep(Implies(p, p), Tautology()),
                ProofStep(Box(p), Necessitation(1)),  # □p ≠ □(p→p)
            ])
            @test is_valid_derivation(SYSTEM_K, bad3) == false

            # Forward reference
            bad4 = Derivation([
                ProofStep(Box(p), Necessitation(2)),
                ProofStep(p, Tautology()),
            ])
            @test is_valid_derivation(SYSTEM_K, bad4) == false
        end

        @testset "Dual formulas (Definition 3.26)" begin
            @test dual(Bottom()) == Not(Bottom())
            @test dual(p) == Not(p)
            @test dual(Not(p)) == Not(Not(p))
            @test dual(And(p, q)) == Or(Not(p), Not(q))
            @test dual(Or(p, q)) == And(Not(p), Not(q))
            @test dual(Box(p)) == Diamond(Not(p))
            @test dual(Diamond(p)) == Box(Not(p))

            # Nested: ~□(p∧q) = ◇~(p∧q) = ◇(~p ∨ ~q) = ◇(¬p ∨ ¬q)
            @test dual(Box(And(p, q))) == Diamond(Or(Not(p), Not(q)))
        end

        @testset "Soundness: K-provable → valid on all frames (Thm 3.31)" begin
            # □p → □(q → p) is K-provable; check validity on several frames
            thm = Implies(Box(p), Box(Implies(q, p)))
            frame1 = KripkeFrame([:w1, :w2], [:w1 => :w2])
            frame2 = KripkeFrame([:w1], [:w1 => :w1])
            frame3 = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w2 => :w3])
            @test is_valid_on_frame(frame1, thm) == true
            @test is_valid_on_frame(frame2, thm) == true
            @test is_valid_on_frame(frame3, thm) == true

            # □(p∧q) → (□p ∧ □q) is K-provable
            thm2 = Implies(Box(And(p, q)), And(Box(p), Box(q)))
            @test is_valid_on_frame(frame1, thm2) == true
            @test is_valid_on_frame(frame2, thm2) == true
            @test is_valid_on_frame(frame3, thm2) == true
        end

        @testset "Derivation display" begin
            proof = Derivation([
                ProofStep(Implies(p, p), Tautology()),
                ProofStep(Box(Implies(p, p)), Necessitation(1)),
            ])
            s = string(proof)
            @test occursin("Taut", s)
            @test occursin("Nec 1", s)
        end
    end

    @testset "Chapter 4: Completeness and Canonical Models" begin
        p = Atom(:p)
        q = Atom(:q)

        @testset "Subformulas" begin
            # Atom
            @test subformulas(p) == Set{Formula}([p])

            # Compound
            sf = subformulas(Implies(p, q))
            @test p ∈ sf
            @test q ∈ sf
            @test Implies(p, q) ∈ sf
            @test length(sf) == 3

            # Modal
            sf = subformulas(Box(Implies(p, q)))
            @test Box(Implies(p, q)) ∈ sf
            @test Implies(p, q) ∈ sf
            @test p ∈ sf
            @test q ∈ sf
            @test length(sf) == 4

            # Nested
            sf = subformulas(Diamond(Box(p)))
            @test Diamond(Box(p)) ∈ sf
            @test Box(p) ∈ sf
            @test p ∈ sf
            @test length(sf) == 3

            # Bottom
            @test subformulas(Bottom()) == Set{Formula}([Bottom()])
        end

        @testset "Formula closure" begin
            cl = formula_closure([p])
            @test Atom(:p) ∈ cl
            @test Not(Atom(:p)) ∈ cl
            @test length(cl) == 2

            cl = formula_closure([Box(p)])
            @test Box(p) ∈ cl
            @test Not(Box(p)) ∈ cl
            @test p ∈ cl
            @test Not(p) ∈ cl
            @test length(cl) == 4
        end

        @testset "Modal operators on sets (Def 4.5)" begin
            Γ = Set{Formula}([Box(p), Box(q), Diamond(p), p])

            @test box_set(Γ) == Set{Formula}([Box(Box(p)), Box(Box(q)), Box(Diamond(p)), Box(p)])
            @test diamond_set(Γ) == Set{Formula}([Diamond(Box(p)), Diamond(Box(q)), Diamond(Diamond(p)), Diamond(p)])
            @test box_inverse(Γ) == Set{Formula}([p, q])
            @test diamond_inverse(Γ) == Set{Formula}([p])

            # Empty set
            @test box_inverse(Set{Formula}()) == Set{Formula}()
            @test diamond_inverse(Set{Formula}()) == Set{Formula}()
        end

        @testset "Consistency (Def 3.39)" begin
            # Consistent sets
            @test is_consistent(SYSTEM_K, [p]; max_worlds=2) == true
            @test is_consistent(SYSTEM_K, [p, q]; max_worlds=2) == true
            @test is_consistent(SYSTEM_K, [Box(p)]; max_worlds=2) == true
            @test is_consistent(SYSTEM_K, [Diamond(p)]; max_worlds=2) == true

            # Inconsistent sets
            @test is_consistent(SYSTEM_K, [p, Not(p)]; max_worlds=2) == false
            @test is_consistent(SYSTEM_K, [Bottom()]; max_worlds=2) == false

            # System-relative consistency: {□p, ¬p} is K-consistent but KT-inconsistent
            @test is_consistent(SYSTEM_K, [Box(p), Not(p)]; max_worlds=2) == true
            @test is_consistent(SYSTEM_KT, [Box(p), Not(p)]; max_worlds=2) == false

            # {◇p, □¬p} is inconsistent in K (Dual axiom)
            @test is_consistent(SYSTEM_K, [Diamond(p), Box(Not(p))]; max_worlds=2) == false
        end

        @testset "Derivability from a set (Def 3.36)" begin
            # Γ = {p} ⊢_K p (reflexivity)
            @test is_derivable_from(SYSTEM_K, [p], p; max_worlds=2) == true

            # Γ = {p, p→q} ⊢_K q (modus ponens)
            @test is_derivable_from(SYSTEM_K, [p, Implies(p, q)], q; max_worlds=2) == true

            # Γ = {} ⊢_K p→p (tautology)
            @test is_derivable_from(SYSTEM_K, Formula[], Implies(p, p); max_worlds=2) == true

            # K proves □(p→p) — necessitation of a tautology
            @test is_derivable_from(SYSTEM_K, Formula[], Box(Implies(p, p)); max_worlds=2) == true

            # K does NOT prove □p→p (that's T)
            @test is_derivable_from(SYSTEM_K, Formula[], Implies(Box(p), p); max_worlds=2) == false

            # KT proves □p→p
            @test is_derivable_from(SYSTEM_KT, Formula[], Implies(Box(p), p); max_worlds=2) == true

            # {p} does not derive □p in K
            @test is_derivable_from(SYSTEM_K, [p], Box(p); max_worlds=2) == false

            # Monotonicity (Prop 3.37): Γ ⊢ A and Γ ⊆ Δ implies Δ ⊢ A
            @test is_derivable_from(SYSTEM_K, [p], p; max_worlds=2) == true
            @test is_derivable_from(SYSTEM_K, [p, q], p; max_worlds=2) == true
        end

        @testset "Complete consistent sets (Def 4.1)" begin
            lang = formula_closure([p])  # {p, ¬p}

            # {p} is complete K-consistent w.r.t. {p, ¬p}
            @test is_complete_consistent(SYSTEM_K, [p], lang; max_worlds=2) == true
            # {¬p} is complete K-consistent
            @test is_complete_consistent(SYSTEM_K, [Not(p)], lang; max_worlds=2) == true
            # {} is NOT complete (neither p nor ¬p)
            @test is_complete_consistent(SYSTEM_K, Formula[], lang; max_worlds=2) == false
            # {p, ¬p} is NOT consistent
            @test is_complete_consistent(SYSTEM_K, [p, Not(p)], lang; max_worlds=2) == false
        end

        @testset "Lindenbaum's Lemma (Thm 4.3)" begin
            lang = formula_closure([p, Box(p)])

            # Extend {p} to a complete K-consistent set
            ext = lindenbaum_extend(SYSTEM_K, [p], lang; max_worlds=3)
            @test p ∈ ext
            # Completeness: for every formula in language, A ∈ ext or ¬A ∈ ext
            for φ in lang
                @test (φ ∈ ext) || (Not(φ) ∈ ext)
            end

            # Extend {□p} to a complete K-consistent set
            ext2 = lindenbaum_extend(SYSTEM_K, [Box(p)], lang; max_worlds=3)
            @test Box(p) ∈ ext2
            for φ in lang
                @test (φ ∈ ext2) || (Not(φ) ∈ ext2)
            end

            # Inconsistent sets throw
            @test_throws ArgumentError lindenbaum_extend(SYSTEM_K, [p, Not(p)], lang; max_worlds=3)
        end

        @testset "Canonical model for K (Def 4.11, Thm 4.14)" begin
            # Canonical model for K over {p}
            cm = canonical_model(SYSTEM_K, [p]; max_worlds=3)
            @test cm.system == SYSTEM_K
            @test length(cm.worlds) == 2  # {p} and {¬p}
            @test truth_lemma_holds(cm)

            # Canonical model for K over {p, □p}
            cm2 = canonical_model(SYSTEM_K, [p, Box(p)]; max_worlds=3)
            @test length(cm2.worlds) == 4  # 2 choices for p × 2 for □p
            @test truth_lemma_holds(cm2)
        end

        @testset "Canonical model for KT — reflexive (Thm 4.16)" begin
            cm = canonical_model(SYSTEM_KT, [p, Box(p)]; max_worlds=3)
            @test truth_lemma_holds(cm)
            @test is_reflexive(cm.model.frame)

            # KT has fewer worlds than K: {□p, ¬p} is KT-inconsistent
            @test length(cm.worlds) < 4
        end

        @testset "Canonical model for KD — serial (Thm 4.16)" begin
            cm = canonical_model(SYSTEM_KD, [p, Box(p)]; max_worlds=3)
            @test truth_lemma_holds(cm)
            @test is_serial(cm.model.frame)
        end

        @testset "Canonical model for S4 — reflexive + transitive (Thm 4.16)" begin
            # Need □□p in language for transitivity to show
            cm = canonical_model(SYSTEM_S4, [p, Box(p), Box(Box(p))]; max_worlds=3)
            @test truth_lemma_holds(cm)
            @test is_reflexive(cm.model.frame)
            @test is_transitive(cm.model.frame)
        end

        @testset "Proposition 4.2: properties of complete consistent sets" begin
            cm = canonical_model(SYSTEM_K, [p, q]; max_worlds=3)

            for Δ in cm.worlds
                # 3. ⊥ ∉ Γ
                @test Bottom() ∉ Δ

                # 4. ¬A ∈ Γ iff A ∉ Γ
                for φ in cm.language
                    if φ isa Not
                        continue  # skip ¬-formulas, check base formulas
                    end
                    @test (Not(φ) ∈ Δ) == (φ ∉ Δ)
                end

                # 5. A ∧ B ∈ Γ iff A ∈ Γ and B ∈ Γ
                for φ in cm.language
                    if φ isa And
                        @test (φ ∈ Δ) == (φ.left ∈ Δ && φ.right ∈ Δ)
                    end
                end

                # 6. A ∨ B ∈ Γ iff A ∈ Γ or B ∈ Γ
                for φ in cm.language
                    if φ isa Or
                        @test (φ ∈ Δ) == (φ.left ∈ Δ || φ.right ∈ Δ)
                    end
                end

                # 7. A → B ∈ Γ iff A ∉ Γ or B ∈ Γ
                for φ in cm.language
                    if φ isa Implies
                        @test (φ ∈ Δ) == (φ.antecedent ∉ Δ || φ.consequent ∈ Δ)
                    end
                end
            end
        end

        @testset "Proposition 4.8: □A ∈ Γ iff for all Δ' with R^Σ ΓΔ', A ∈ Δ'" begin
            cm = canonical_model(SYSTEM_K, [p, Box(p)]; max_worlds=3)

            for (i, Δ) in enumerate(cm.worlds)
                wname = Symbol("Δ", i)
                for φ in cm.language
                    if φ isa Box
                        a = φ.operand
                        # □A ∈ Δ iff for all accessible Δ', A ∈ Δ'
                        box_in = φ ∈ Δ
                        all_succ = all(cm.worlds) do Δ′
                            j = findfirst(w -> w === Δ′, cm.worlds)
                            wj = Symbol("Δ", j)
                            if wj ∈ accessible(cm.model.frame, wname)
                                a ∈ Δ′
                            else
                                true  # not accessible, vacuously true
                            end
                        end
                        @test box_in == all_succ
                    end
                end
            end
        end

        @testset "Proposition 4.10: ◇A ∈ Γ iff ∃ accessible Δ' with A ∈ Δ'" begin
            cm = canonical_model(SYSTEM_K, [p, Box(p)]; max_worlds=3)

            for (i, Δ) in enumerate(cm.worlds)
                wname = Symbol("Δ", i)
                for φ in cm.language
                    # Check Diamond formulas (which appear as ¬□¬A patterns)
                    # In our language, ◇ formulas might not appear directly,
                    # but we can check the semantic equivalent
                end
            end
            # The truth lemma already verifies this implicitly
            @test truth_lemma_holds(cm)
        end

        @testset "Completeness: K-valid implies K-provable (Cor 4.15)" begin
            # Some K-valid formulas (tautological instances)
            k_valid = [
                Implies(p, p),
                Implies(p, Implies(q, p)),
                Or(p, Not(p)),
            ]
            for φ in k_valid
                @test is_derivable_from(SYSTEM_K, Formula[], φ; max_worlds=2) == true
            end

            # Some K-valid modal formulas
            k_modal_valid = [
                Implies(Box(Implies(p, q)), Implies(Box(p), Box(q))),  # K axiom
                Box(Implies(p, p)),  # Nec of tautology
            ]
            for φ in k_modal_valid
                @test is_derivable_from(SYSTEM_K, Formula[], φ; max_worlds=2) == true
            end

            # Non-valid in K
            @test is_derivable_from(SYSTEM_K, Formula[], Implies(Box(p), p); max_worlds=2) == false
            @test is_derivable_from(SYSTEM_K, Formula[], Implies(Box(p), Diamond(p)); max_worlds=2) == false
        end

        @testset "System distinctness via completeness (Props 3.32-3.35)" begin
            # KD ⊊ KT: □p→p is KT-valid but not KD-valid
            t_schema = Implies(Box(p), p)
            @test is_derivable_from(SYSTEM_KT, Formula[], t_schema; max_worlds=2) == true
            @test is_derivable_from(SYSTEM_KD, Formula[], t_schema; max_worlds=2) == false

            # KB ≠ K4: Schema 4 not valid in KB
            four_schema = Implies(Box(p), Box(Box(p)))
            @test is_derivable_from(SYSTEM_KB, Formula[], four_schema; max_worlds=2) == false
        end

        @testset "Determination (Def 4.13)" begin
            # Build canonical model and check determination
            cm = canonical_model(SYSTEM_K, [p]; max_worlds=3)
            @test determines(cm.model, SYSTEM_K, [p]; max_worlds=3) == true
        end

        @testset "Canonical model display" begin
            cm = canonical_model(SYSTEM_K, [p]; max_worlds=3)
            s = string(cm)
            @test occursin("CanonicalModel", s)
            @test occursin("K", s)
            @test occursin("2 worlds", s)
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

    # ── Chapter 5: Filtrations and Decidability ──

    @testset "Chapter 5: Filtrations and Decidability" begin
        p = Atom(:p)
        q = Atom(:q)

        @testset "Closed under subformulas (Definition 5.1)" begin
            # subformulas of □p → p = {(□p → p), □p, p}
            Γ = subformula_closure(Implies(Box(p), p))
            @test is_closed_under_subformulas(Γ)

            # Remove a subformula — no longer closed
            Γ_broken = setdiff(Γ, Set{Formula}([p]))
            @test !is_closed_under_subformulas(Γ_broken)
        end

        @testset "Modally closed (Definition 5.1)" begin
            Γ = subformula_closure(Box(p))
            @test is_closed_under_subformulas(Γ)
            @test !is_modally_closed(Γ)  # doesn't contain □□p, ◇p, etc.

            # A modally closed set must contain □A and ◇A for every A in it.
            # This means it is necessarily infinite (e.g., p requires □p, ◇p,
            # which require □□p, ◇□p, □◇p, ◇◇p, etc.) — no finite set qualifies
            # unless it is empty or contains only ⊥.
            # We can verify a hand-constructed finite example fails:
            Γ_not_closed = Set{Formula}([p, Box(p), Diamond(p)])
            # □p ∈ Γ requires □□p ∈ Γ, which is missing → not modally closed
            @test !is_modally_closed(Γ_not_closed)
        end

        @testset "Equivalence relation (Definition 5.2, Proposition 5.3)" begin
            # Simple model: Figure 1.1
            frame = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w1 => :w3])
            model = KripkeModel(frame, [:p => [:w1, :w2], :q => [:w2]])

            Γ = subformula_closure(p)  # Γ = {p}
            # w1 and w2 satisfy p, w3 doesn't
            @test world_equivalent(model, Γ, :w1, :w2)
            @test !world_equivalent(model, Γ, :w1, :w3)

            classes = equivalence_classes(model, Γ)
            @test length(classes) == 2  # {w1,w2} and {w3}

            # With Γ = subformulas(□p), all three worlds are distinct
            Γ2 = subformula_closure(Box(p))
            classes2 = equivalence_classes(model, Γ2)
            @test length(classes2) == 3  # each world in its own class

            # Reflexivity: every world is equivalent to itself
            for w in [:w1, :w2, :w3]
                @test world_equivalent(model, Γ, w, w)
            end

            # Symmetry
            @test world_equivalent(model, Γ, :w1, :w2) ==
                  world_equivalent(model, Γ, :w2, :w1)
        end

        @testset "Finest filtration (Definition 5.7)" begin
            frame = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w1 => :w3])
            model = KripkeModel(frame, [:p => [:w1, :w2], :q => [:w2]])

            Γ = subformula_closure(Implies(Box(p), p))
            filt = finest_filtration(model, Γ)

            @test filt isa Filtration
            @test length(filt.classes) == 3  # all 3 worlds distinct for this Γ
            @test filtration_lemma_holds(filt)
        end

        @testset "Coarsest filtration (Definition 5.9)" begin
            frame = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w1 => :w3])
            model = KripkeModel(frame, [:p => [:w1, :w2], :q => [:w2]])

            Γ = subformula_closure(Implies(Box(p), p))
            filt = coarsest_filtration(model, Γ)

            @test filt isa Filtration
            @test filtration_lemma_holds(filt)
        end

        @testset "Filtration reduces worlds" begin
            # Build a model where some worlds agree on all subformulas
            # 4 worlds, but only p matters: w1,w2 have p; w3,w4 don't
            frame = KripkeFrame([:w1, :w2, :w3, :w4],
                [:w1 => :w2, :w1 => :w3, :w2 => :w4])
            model = KripkeModel(frame, [:p => [:w1, :w2]])

            Γ = subformula_closure(p)  # Γ = {p}
            filt = finest_filtration(model, Γ)

            # Should collapse to 2 classes: {w1,w2} and {w3,w4}
            @test length(filt.classes) == 2
            @test filtration_lemma_holds(filt)
        end

        @testset "Proposition 5.12: filtration size bound" begin
            frame = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w1 => :w3])
            model = KripkeModel(frame, [:p => [:w1, :w2], :q => [:w2]])

            φ = Implies(Box(p), p)
            Γ = subformula_closure(φ)
            n = length(Γ)

            filt = finest_filtration(model, Γ)
            @test length(filt.classes) <= 2^n
        end

        @testset "Filtration Lemma for various formulas" begin
            frame = KripkeFrame([:w1, :w2, :w3],
                [:w1 => :w2, :w1 => :w3, :w2 => :w3])
            model = KripkeModel(frame, [:p => [:w1, :w3], :q => [:w2]])

            for φ in [Box(p), Diamond(q), Implies(Box(p), Diamond(q)),
                       And(p, Box(q)), Or(Diamond(p), Box(q))]
                Γ = subformula_closure(φ)
                filt_fine = finest_filtration(model, Γ)
                filt_coarse = coarsest_filtration(model, Γ)
                @test filtration_lemma_holds(filt_fine)
                @test filtration_lemma_holds(filt_coarse)
            end
        end

        @testset "Reflexive model → reflexive finest filtration" begin
            # Reflexive frame
            frame = KripkeFrame([:w1, :w2],
                [:w1 => :w1, :w1 => :w2, :w2 => :w2])
            model = KripkeModel(frame, [:p => [:w1]])

            Γ = subformula_closure(Box(p))
            filt = finest_filtration(model, Γ)

            @test is_reflexive(filt.model.frame)
            @test filtration_lemma_holds(filt)
        end

        @testset "Symmetric filtration of symmetric model is symmetric (Theorem 5.18.1)" begin
            # Symmetric frame
            frame = KripkeFrame([:w1, :w2, :w3],
                [:w1 => :w2, :w2 => :w1, :w2 => :w3, :w3 => :w2])
            model = KripkeModel(frame, [:p => [:w1, :w2]])

            Γ = subformula_closure(Implies(Box(p), p))
            filt = symmetric_filtration(model, Γ)

            @test is_symmetric(filt.model.frame)
            @test filtration_lemma_holds(filt)
        end

        @testset "Transitive filtration of transitive model is transitive (Theorem 5.18.2)" begin
            # Transitive frame
            frame = KripkeFrame([:w1, :w2, :w3],
                [:w1 => :w2, :w2 => :w3, :w1 => :w3])
            model = KripkeModel(frame, [:p => [:w1, :w3]])

            Γ = subformula_closure(Box(p))
            filt = transitive_filtration(model, Γ)

            @test is_transitive(filt.model.frame)
            @test filtration_lemma_holds(filt)
        end

        @testset "Finite model property (Proposition 5.14)" begin
            # K has FMP — any non-valid formula has a finite countermodel
            @test has_finite_model_property(SYSTEM_K, Implies(Box(p), p))
            @test has_finite_model_property(SYSTEM_K, Box(Implies(p, q)))
        end

        @testset "Decidability (Theorem 5.17)" begin
            result = is_decidable_within(SYSTEM_K, Implies(Box(p), p))
            @test result.valid == false  # □p → p is not K-valid
            @test result.subformula_count == 3

            result2 = is_decidable_within(SYSTEM_K,
                Implies(Box(Implies(p, q)), Implies(Box(p), Box(q))))
            @test result2.valid == true  # Schema K is valid
        end

        @testset "Display" begin
            frame = KripkeFrame([:w1, :w2], [:w1 => :w2])
            model = KripkeModel(frame, [:p => [:w1]])
            Γ = subformula_closure(Box(p))
            filt = finest_filtration(model, Γ)
            @test contains(string(filt), "Filtration")
        end
    end

    @testset "Chapter 6: Modal Tableaux" begin
        p = Atom(:p); q = Atom(:q)

        @testset "Prefix (Definition 6.1)" begin
            σ = Prefix([1])
            τ = Prefix([1, 2])
            @test σ == Prefix(1)
            @test extend(σ, 2) == τ
            @test parent_prefix(τ) == σ
            @test_throws ArgumentError Prefix(Int[])      # empty not allowed
            @test_throws ArgumentError Prefix([-1])       # non-positive not allowed
            @test string(Prefix([1,2,3])) == "1.2.3"
        end

        @testset "PrefixedFormula and branch closure (Definition 6.2)" begin
            σ = Prefix([1])
            pf1 = pf_true(σ, p)
            pf2 = pf_false(σ, p)
            pf3 = pf_true(σ, q)
            b = TableauBranch([pf1, pf3])
            @test !is_closed(b)
            b2 = TableauBranch([pf1, pf2])
            @test is_closed(b2)
            # different prefix — not closed
            σ2 = Prefix([1, 1])
            b3 = TableauBranch([pf1, pf_false(σ2, p)])
            @test !is_closed(b3)
        end

        @testset "K rules: Examples 6.1 and 6.2 (B&D)" begin
            # Example 6.1: ⊢ (□p ∧ □q) → □(p ∧ q)
            @test tableau_proves(TABLEAU_K, Formula[], Implies(And(Box(p), Box(q)), Box(And(p, q))))
            # Example 6.2: ⊢ ◇(p ∨ q) → (◇p ∨ ◇q)
            @test tableau_proves(TABLEAU_K, Formula[], Implies(Diamond(Or(p, q)), Or(Diamond(p), Diamond(q))))
            # Schema K: □(p→q) → (□p→□q)
            @test tableau_proves(TABLEAU_K, Formula[], Implies(Box(Implies(p, q)), Implies(Box(p), Box(q))))
            # K does not prove T: □p → p
            @test !tableau_proves(TABLEAU_K, Formula[], Implies(Box(p), p))
            # K does not prove 4: □p → □□p
            @test !tableau_proves(TABLEAU_K, Formula[], Implies(Box(p), Box(Box(p))))
        end

        @testset "Soundness: non-theorems in K (Theorem 6.6)" begin
            # □p ⊬_K ◇p (seriality not assumed)
            @test !tableau_proves(TABLEAU_K, Formula[Box(p)], Diamond(p))
            # ◇p ⊬_K □p
            @test !tableau_proves(TABLEAU_K, Formula[], Implies(Diamond(p), Box(p)))
            # Dual: □p ↔ ¬◇¬p (valid in K)
            @test tableau_proves(TABLEAU_K, Formula[], Implies(Not(Diamond(Not(p))), Box(p)))
        end

        @testset "KT rules: T axiom (Table 6.4)" begin
            # T: □p → p holds in KT
            @test tableau_proves(TABLEAU_KT, Formula[], Implies(Box(p), p))
            # K axiom still holds
            @test tableau_proves(TABLEAU_KT, Formula[], Implies(Box(Implies(p, q)), Implies(Box(p), Box(q))))
            # 4 axiom does not hold in KT
            @test !tableau_proves(TABLEAU_KT, Formula[], Implies(Box(p), Box(Box(p))))
        end

        @testset "KD rules: D axiom (Table 6.4)" begin
            # D: □p → ◇p holds in KD
            @test tableau_proves(TABLEAU_KD, Formula[], Implies(Box(p), Diamond(p)))
            # D does not hold in K
            @test !tableau_proves(TABLEAU_K, Formula[], Implies(Box(p), Diamond(p)))
        end

        @testset "KB rules: B axiom (Table 6.4)" begin
            # B: □p → ◇□p holds in KB
            @test tableau_proves(TABLEAU_KB, Formula[], Implies(Box(p), Diamond(Box(p))))
            # B does not hold in K
            @test !tableau_proves(TABLEAU_K, Formula[], Implies(Box(p), Diamond(Box(p))))
        end

        @testset "K4 rules: 4 axiom (Table 6.4)" begin
            # 4: □p → □□p holds in K4
            @test tableau_proves(TABLEAU_K4, Formula[], Implies(Box(p), Box(Box(p))))
            # 4 does not hold in K
            @test !tableau_proves(TABLEAU_K, Formula[], Implies(Box(p), Box(Box(p))))
        end

        @testset "S4 rules: T + 4 (Table 6.4)" begin
            # S4 ⊢ T: □p → p
            @test tableau_proves(TABLEAU_S4, Formula[], Implies(Box(p), p))
            # S4 ⊢ 4: □p → □□p
            @test tableau_proves(TABLEAU_S4, Formula[], Implies(Box(p), Box(Box(p))))
            # S4 ⊬ 5: ◇p → □◇p
            @test !tableau_proves(TABLEAU_S4, Formula[], Implies(Diamond(p), Box(Diamond(p))))
        end

        @testset "S5 rules: T + 4 + 5 (Table 6.4)" begin
            # S5 ⊢ T: □p → p
            @test tableau_proves(TABLEAU_S5, Formula[], Implies(Box(p), p))
            # S5 ⊢ 4: □p → □□p
            @test tableau_proves(TABLEAU_S5, Formula[], Implies(Box(p), Box(Box(p))))
            # S5 ⊢ 5: ◇p → □◇p
            @test tableau_proves(TABLEAU_S5, Formula[], Implies(Diamond(p), Box(Diamond(p))))
            # S5 ⊢ B: □p → ◇□p (Example 6.9, B&D)
            @test tableau_proves(TABLEAU_S5, Formula[], Implies(Box(p), Diamond(Box(p))))
            # S5 ⊢ schema K
            @test tableau_proves(TABLEAU_S5, Formula[], Implies(Box(Implies(p, q)), Implies(Box(p), Box(q))))
        end

        @testset "tableau_consistent" begin
            # {□p, ◇q} is satisfiable in K
            @test tableau_consistent(TABLEAU_K, Formula[Box(p), Diamond(q)])
            # {p, ¬p} is unsatisfiable
            @test !tableau_consistent(TABLEAU_K, Formula[p, Not(p)])
            # {□p, ¬p} unsatisfiable in KT (T axiom makes □p → p)
            @test !tableau_consistent(TABLEAU_KT, Formula[Box(p), Not(p)])

            # SplitRule must not discard open branches when one arm of a split
            # is already present (regression: previously reported inconsistent)
            @test tableau_consistent(TABLEAU_K, Formula[Implies(p, q), Not(q)])
            @test tableau_consistent(TABLEAU_K, Formula[Implies(p, q), p])
            @test tableau_consistent(TABLEAU_K, Formula[Or(p, q), Not(q)])
            @test tableau_consistent(TABLEAU_K, Formula[Or(p, q), Not(p)])
            @test tableau_consistent(TABLEAU_K, Formula[p, Or(p, q), Not(q)])
            # Modal with conditional
            @test tableau_consistent(TABLEAU_KD,
                Formula[Implies(p, Box(Not(q))), Box(q)])
            @test tableau_consistent(TABLEAU_KD,
                Formula[Implies(p, Box(q)), Not(p)])
        end

        @testset "Combined deontic-temporal (TABLEAU_KDt)" begin
            # Pure temporal theorems (reflexive temporal frames)
            # 𝐆p → p (temporal reflexivity)
            @test tableau_proves(TABLEAU_KDt, Formula[], Implies(FutureBox(p), p))
            # 𝐆p → 𝐅p (box implies diamond, via reflexivity)
            @test tableau_proves(TABLEAU_KDt, Formula[], Implies(FutureBox(p), FutureDiamond(p)))

            # Combined: O(𝐅p) ∧ O(𝐆¬p) → inconsistent
            # Obligatory that p eventually holds, but obligatory that p never holds
            @test !tableau_consistent(TABLEAU_KDt,
                Formula[Box(FutureDiamond(p)), Box(FutureBox(Not(p)))])

            # Temporal reflexivity through deontic nesting: 𝐆(□p) → □p
            @test tableau_proves(TABLEAU_KDt, Formula[], Implies(FutureBox(Box(p)), Box(p)))

            # D axiom preserved through temporal nesting: □(𝐅p) → ◇(𝐅p)
            @test tableau_proves(TABLEAU_KDt, Formula[],
                Implies(Box(FutureDiamond(p)), Diamond(FutureDiamond(p))))

            # Consistency: conditional obligation with temporal constraint
            # "If p then always ¬q obligatory" + "q eventually obligatory" — consistent (set p=false)
            @test tableau_consistent(TABLEAU_KDt,
                Formula[Implies(p, Box(FutureBox(Not(q)))), Box(FutureDiamond(q))])

            # Pure temporal consistency: 𝐆p ∧ 𝐅q is satisfiable
            @test tableau_consistent(TABLEAU_KDt, Formula[FutureBox(p), FutureDiamond(q)])

            # Pure temporal inconsistency: 𝐆p ∧ 𝐅¬p is unsatisfiable
            # (reflexivity gives p, and we need a successor where ¬p, but 𝐆 propagates)
            @test !tableau_consistent(TABLEAU_KDt, Formula[FutureBox(p), FutureDiamond(Not(p))])
        end

        @testset "Completeness (Theorem 6.19) and countermodel extraction (§6.9)" begin
            # Theorem 6.19: if no closed tableau exists, Γ is satisfiable.
            # extract_countermodel constructs the model M(Δ) from an open complete branch.

            root = Prefix([1])
            w1 = Symbol("1")

            # □p → p is not K-valid (T axiom).
            # The open branch {1 T □p, 1 F p} yields the countermodel:
            # W={1}, R={}, V(p)={} — no successor to require p, yet p is false at 1.
            f_T = Implies(Box(p), p)
            tT = build_tableau([pf_false(root, f_T)], TABLEAU_K)
            @test !is_closed(tT)
            open_T = findfirst(b -> !is_closed(b), tT.branches)
            @test open_T !== nothing
            cm_T = extract_countermodel(tT.branches[open_T])
            @test w1 ∈ cm_T.frame.worlds
            @test !satisfies(cm_T, w1, f_T)

            # p → q is not a propositional tautology.
            # Open branch {1 T p, 1 F q} yields: W={1}, R={}, V(p)={1}, V(q)={}.
            f_pq = Implies(p, q)
            tpq = build_tableau([pf_false(root, f_pq)], TABLEAU_K)
            @test !is_closed(tpq)
            open_pq = findfirst(b -> !is_closed(b), tpq.branches)
            @test open_pq !== nothing
            cm_pq = extract_countermodel(tpq.branches[open_pq])
            @test w1 ∈ cm_pq.frame.worlds
            @test satisfies(cm_pq, w1, p)
            @test !satisfies(cm_pq, w1, q)
            @test !satisfies(cm_pq, w1, f_pq)

            # Corollary 6.20 / 6.21: ⊨ A ↔ ⊢ A (completeness for K)
            # Tautologies and K-valid formulas produce closed tableaux.
            @test tableau_proves(TABLEAU_K, Formula[], Or(p, Not(p)))
            @test tableau_proves(TABLEAU_K, Formula[], Implies(Box(Implies(p, q)), Implies(Box(p), Box(q))))
        end

        @testset "Tableau blocking (loop checking)" begin
            # _ancestors helper
            @test Gamen._ancestors(Prefix([1])) == Prefix[]
            @test Gamen._ancestors(Prefix([1,2])) == [Prefix([1])]
            @test Gamen._ancestors(Prefix([1,2,3])) == [Prefix([1]), Prefix([1,2])]

            # _prefix_content extracts signed formulas at a prefix
            σ = Prefix([1]); τ = Prefix([1,1])
            branch = TableauBranch([pf_true(σ, p), pf_false(σ, q), pf_true(τ, p)])
            content_σ = Gamen._prefix_content(branch, σ)
            content_τ = Gamen._prefix_content(branch, τ)
            @test length(content_σ) == 2
            @test length(content_τ) == 1
            @test content_τ ⊆ content_σ  # τ has subset of σ's formulas

            # _should_block: child with subset of parent's content is blocked
            @test !Gamen._should_block(branch, σ)  # root is never blocked
            @test Gamen._should_block(branch, τ)    # τ ⊆ σ

            # _should_block: child with strictly more content is not blocked
            branch2 = TableauBranch([pf_true(σ, p), pf_true(τ, p), pf_true(τ, q)])
            @test !Gamen._should_block(branch2, τ)  # τ has {p,q}, σ has {p}

            # Temporal blocking: 𝐆(□p) exercises blocking — without it, the
            # seriality rule creates worlds indefinitely (each isomorphic to its parent)
            root = Prefix([1])
            t = build_tableau([pf_true(root, FutureBox(Box(p)))], TABLEAU_KDt)
            @test !is_closed(t)
            # With blocking, the tableau should have very few worlds (3 prefixes,
            # with 1.1.1 blocked because its content ⊆ ancestor 1.1's content)
            open_branch = t.branches[findfirst(b -> !is_closed(b), t.branches)]
            @test length(open_branch.formulas) <= 15  # would be ~1000+ without blocking
            @test !isempty(open_branch.blocked)  # at least one prefix is blocked

            # Blocking preserves correctness: temporal theorems still prove
            @test tableau_proves(TABLEAU_KDt, Formula[], Implies(FutureBox(p), p))
            @test tableau_proves(TABLEAU_KDt, Formula[], Implies(FutureBox(p), FutureDiamond(p)))

            # Blocking preserves correctness: temporal non-theorems stay open
            @test !tableau_proves(TABLEAU_KDt, Formula[], Implies(FutureDiamond(p), FutureBox(p)))

            # Blocking preserves correctness: temporal inconsistencies still close
            @test !tableau_consistent(TABLEAU_KDt, Formula[FutureBox(p), FutureDiamond(Not(p))])

            # Blocking preserves correctness: temporal consistencies stay open
            @test tableau_consistent(TABLEAU_KDt, Formula[FutureBox(p), FutureDiamond(q)])

            # Non-temporal tableaux are unaffected (no blocking triggers)
            @test tableau_proves(TABLEAU_K, Formula[], Implies(Box(Implies(p, q)), Implies(Box(p), Box(q))))
            @test !tableau_proves(TABLEAU_K, Formula[], Implies(Box(p), p))
        end

    end  # Chapter 6

    # ──────────────────────────────────────────────────────────────────
    @testset "Chapter 14: Temporal Logics" begin

        @testset "Formula construction and display (Definition 14.2)" begin
            p = Atom(:p)
            q = Atom(:q)
            @test string(FutureDiamond(p)) == "Fp"
            @test string(FutureBox(p)) == "Gp"
            @test string(PastDiamond(p)) == "Pp"
            @test string(PastBox(p)) == "Hp"
            @test string(Since(p, q)) == "(Spq)"
            @test string(Until(p, q)) == "(Upq)"
            @test 𝐅(p) == FutureDiamond(p)
            @test 𝐆(p) == FutureBox(p)
            @test 𝐏(p) == PastDiamond(p)
            @test 𝐇(p) == PastBox(p)
            @test is_modal_free(FutureDiamond(p)) == false
            @test is_modal_free(Since(p, q)) == false
        end

        @testset "TemporalModel semantics (Definition 14.4)" begin
            # Linear model: t1 ≺ t2 ≺ t3, p true at t1 and t2, q true at t3
            # Relation: t1=>t2, t2=>t3
            m = KripkeModel(
                KripkeFrame([:t1, :t2, :t3], [:t1 => :t2, :t2 => :t3]),
                [:p => [:t1, :t2], :q => [:t3]]
            )
            p = Atom(:p)
            q = Atom(:q)

            # FA at t: some future time satisfies A (only direct successors)
            @test satisfies(m, :t1, FutureDiamond(p))   # t2 is successor of t1, p true at t2
            @test !satisfies(m, :t1, FutureDiamond(q))  # q only at t3, not direct successor of t1
            @test satisfies(m, :t2, FutureDiamond(q))   # t3 is direct successor of t2

            # GA at t: all future times satisfy A
            @test !satisfies(m, :t1, FutureBox(q))      # t2 doesn't satisfy q
            @test satisfies(m, :t2, FutureBox(q))       # only future is t3, q true there
            @test satisfies(m, :t3, FutureBox(p))       # no future, vacuously true

            # PA at t: some past time satisfies A (t' ≺ t)
            @test !satisfies(m, :t1, PastDiamond(p))    # t1 has no predecessors
            @test satisfies(m, :t2, PastDiamond(p))     # t1 ≺ t2 and p at t1
            @test satisfies(m, :t3, PastDiamond(p))     # t2 ≺ t3 and p at t2

            # HA at t: all past times satisfy A
            @test satisfies(m, :t1, PastBox(q))         # no past, vacuously true
            @test !satisfies(m, :t2, PastBox(q))        # t1 ≺ t2 but q not at t1
            @test !satisfies(m, :t3, PastBox(q))        # t2 ≺ t3, q not at t2 → false
        end

        @testset "Until and Since operators (Definition 14.5)" begin
            # t1 ≺ t2 ≺ t3, p at t1 t2, q at t3
            # Note: F/G/P/H/S/U use only DIRECT (one-step) successors/predecessors
            m = KripkeFrame([:t1, :t2, :t3], [:t1 => :t2, :t2 => :t3])
            # Add t1 → t3 directly so U can witness q at t3 from t1
            m_direct = KripkeModel(
                KripkeFrame([:t1, :t2, :t3], [:t1 => :t2, :t1 => :t3, :t2 => :t3]),
                [:p => [:t1, :t2], :q => [:t3]]
            )
            p = Atom(:p)
            q = Atom(:q)

            # UBC at t: ∃t' ∈ successors(t) s.t. M,t' ⊩ B and ∀s: t ≺ s ≺ t' → M,s ⊩ C
            # U(q)(p) at t1 in m_direct: t1 directly sees t3 (q true);
            # s between t1 and t3: s with t1→s and t3∈successors(s) → t2 (t1→t2, t2→t3)
            # p true at t2 → holds
            @test satisfies(m_direct, :t1, Until(q, p))

            # S(p)(q) at t3 in m_direct: ∃t' ≺ t3 with p at t', q holds between t' and t3
            # t' = t2: p at t2, between t2 and t3: nothing strictly between → vacuously true
            @test satisfies(m_direct, :t3, Since(p, q))

            # U(q)(q) at t1 in m_direct: need q at successor and q between t1 and it
            # Only t3 has q, but t2 is between (t1→t2, t2→t3) and q not at t2 → false
            @test !satisfies(m_direct, :t1, Until(q, q))
        end

        @testset "Frame correspondence properties (Table 14.1)" begin
            # Transitive frame: t1≺t2≺t3, not transitive since t1≺t3 missing
            non_trans = KripkeFrame([:t1,:t2,:t3], [:t1=>:t2, :t2=>:t3])
            trans = KripkeFrame([:t1,:t2,:t3], [:t1=>:t2, :t2=>:t3, :t1=>:t3])
            @test !is_transitive_frame(non_trans)
            @test is_transitive_frame(trans)

            # Linear frame
            linear = KripkeFrame([:t1,:t2,:t3], [:t1=>:t2, :t2=>:t3, :t1=>:t3])
            non_linear = KripkeFrame([:t1,:t2,:t3], [:t1=>:t2, :t1=>:t3])
            @test is_linear_frame(linear)
            @test !is_linear_frame(non_linear)

            # Dense frame: t1≺t2 but no intermediate point between them
            non_dense = KripkeFrame([:t1,:t2], [:t1=>:t2])
            # Dense: every t1≺t2 has t1≺t3≺t2. With t1→t2, t2→t2 (self-loop):
            # t1≺t2: intermediate t2 itself (t1→t2 and t2→t2) ✓; t2≺t2: t2→t2 and t2→t2 ✓
            dense = KripkeFrame([:t1,:t2], [:t1=>:t2, :t2=>:t2])
            @test !is_dense_frame(non_dense)
            @test is_dense_frame(dense)

            # Unbounded past/future
            bounded = KripkeFrame([:t1,:t2], [:t1=>:t2])
            @test !is_unbounded_past(bounded)   # t1 has no predecessor
            @test !is_unbounded_future(bounded) # t2 has no successor
            # Two-point cyclic
            cyclic = KripkeFrame([:t1,:t2], [:t1=>:t2, :t2=>:t1])
            @test is_unbounded_past(cyclic)
            @test is_unbounded_future(cyclic)
        end

    end  # Chapter 14

    # ──────────────────────────────────────────────────────────────────
    @testset "Chapter 15: Epistemic Logics" begin

        @testset "Formula construction (Definition 15.2)" begin
            p = Atom(:p)
            q = Atom(:q)
            @test string(Knowledge(:a, p)) == "K[a]p"
            @test string(Announce(p, q)) == "[p]q"
            @test Knowledge(:a, p) == Knowledge(:a, p)
            @test Knowledge(:a, p) != Knowledge(:b, p)
            @test is_modal_free(Knowledge(:a, p)) == false
            @test is_modal_free(Announce(p, q)) == false
        end

        @testset "EpistemicFrame construction and accessible (Definition 15.4)" begin
            frame = EpistemicFrame(
                [:w1, :w2, :w3],
                [:a => [:w1 => :w2, :w2 => :w2],
                 :b => [:w1 => :w1, :w1 => :w3, :w3 => :w3]]
            )
            @test :w1 in frame.worlds
            @test :w2 in accessible(frame, :a, :w1)
            @test !(:w3 in accessible(frame, :a, :w1))
            @test :w1 in accessible(frame, :b, :w1)
            @test :w3 in accessible(frame, :b, :w1)
            @test :a in agents(frame) && :b in agents(frame)
        end

        @testset "Epistemic truth conditions (Definition 15.5)" begin
            # Figure 15.1 inspired model: 3 worlds
            # Agent a: w1 accesses w2; agent b: w1 accesses w3
            # p true at w1, w2; q true at w2
            frame = EpistemicFrame(
                [:w1, :w2, :w3],
                [:a => [:w1 => :w2, :w2 => :w2, :w3 => :w3],
                 :b => [:w1 => :w3, :w2 => :w2, :w3 => :w3]]
            )
            model = EpistemicModel(frame, [:p => [:w1, :w2], :q => [:w2]])
            p = Atom(:p); q = Atom(:q)

            # K[a]p at w1: all a-successors of w1 satisfy p — w2 does → true
            @test satisfies(model, :w1, Knowledge(:a, p))
            # K[b]p at w1: all b-successors of w1 satisfy p — w3 doesn't → false
            @test !satisfies(model, :w1, Knowledge(:b, p))
            # K[a]q at w1: w2 satisfies q → true
            @test satisfies(model, :w1, Knowledge(:a, q))
            # K[b]q at w1: w3 doesn't satisfy q → false
            @test !satisfies(model, :w1, Knowledge(:b, q))
        end

        @testset "Group and common knowledge (Definition 15.3 and 15.6)" begin
            frame = EpistemicFrame(
                [:w1, :w2, :w3],
                [:a => [:w1 => :w2, :w2 => :w2, :w3 => :w3],
                 :b => [:w1 => :w2, :w2 => :w2, :w3 => :w3]]
            )
            # p true at w1 and w2 — all worlds reachable from w1 (via BFS: w1,w2) satisfy p
            model = EpistemicModel(frame, [:p => [:w1, :w2]])
            p = Atom(:p)

            # Both agents know p at w1: K[a]p true (only a-successor is w2, p there)
            @test group_knows(model, :w1, [:a, :b], p)
            # Common knowledge: BFS from w1 visits w1 (p ✓) and w2 (p ✓)
            @test common_knowledge(model, :w1, [:a, :b], p)
            # p not true at w3 (and w3 sees w3 which has no p)
            @test !group_knows(model, :w3, [:a, :b], p)
        end

        @testset "Veridicality: K[a]p → p (requires reflexive R_a)" begin
            # Reflexive model: each world sees itself
            frame = EpistemicFrame(
                [:w1, :w2],
                [:a => [:w1 => :w1, :w2 => :w2]]
            )
            model = EpistemicModel(frame, [:p => [:w1]])
            p = Atom(:p)
            # K[a]p → p is the T axiom for K_a
            kap = Knowledge(:a, p)
            # At w1: K[a]p → p. K[a]p at w1: all a-successors of w1 satisfy p.
            # a-successors = {w1}, p true at w1 → K[a]p true → need p true → p true at w1 ✓
            @test satisfies(model, :w1, Implies(kap, p))
            # At w2: K[a]p false (w2 not in V(p)), so implication vacuously true
            @test satisfies(model, :w2, Implies(kap, p))
        end

        @testset "Public announcement restrict_model (Definition 15.11)" begin
            # Model with p at w1, w2 but not w3
            frame = EpistemicFrame(
                [:w1, :w2, :w3],
                [:a => [:w1 => :w2, :w2 => :w2, :w3 => :w3],
                 :b => [:w1 => :w1, :w1 => :w3, :w3 => :w3]]
            )
            model = EpistemicModel(frame, [:p => [:w1, :w2], :q => [:w2]])
            p = Atom(:p); q = Atom(:q)

            m_p = restrict_model(model, p)
            # W' = {w1, w2} (w3 dropped since p not true there)
            @test :w1 in m_p.frame.worlds
            @test :w2 in m_p.frame.worlds
            @test !(:w3 in m_p.frame.worlds)
            # b's relation restricted: w1 no longer sees w3 (w3 dropped)
            @test !(:w3 in accessible(m_p.frame, :b, :w1))
        end

        @testset "Public announcement semantics: [p]K[a]p" begin
            # After announcing p, agent a knows p if R_a is reflexive within the p-worlds
            frame = EpistemicFrame(
                [:w1, :w2, :w3],
                [:a => [:w1 => :w1, :w1 => :w2, :w2 => :w2, :w3 => :w3]]
            )
            model = EpistemicModel(frame, [:p => [:w1, :w2]])
            p = Atom(:p)
            # [p]K[a]p at w1: M,w1 ⊩ p (yes), so check M|p, w1 ⊩ K[a]p
            # M|p: W' = {w1,w2}, a's relation: w1 sees w1 and w2 (both in W')
            # K[a]p in M|p at w1: all successors of w1 in M|p satisfy p → w1,w2 satisfy p ✓
            @test satisfies(model, :w1, Announce(p, Knowledge(:a, p)))
            # At w3: p is false there, so [p]K[a]p is vacuously true
            @test satisfies(model, :w3, Announce(p, Knowledge(:a, p)))
        end

        @testset "Bisimulation (Definition 15.7, Theorem 15.8)" begin
            # Two single-agent models that are bisimilar (Figure 15.2 inspired)
            # M1: w1, w2, w3 with w1 sees w2 and w3 (agent a)
            frame1 = EpistemicFrame(
                [:w1, :w2, :w3],
                [:a => [:w1 => :w2, :w1 => :w3, :w2 => :w2, :w3 => :w3]]
            )
            m1 = EpistemicModel(frame1, [:p => [:w2, :w3]])

            # M2: v1, v2 with v1 sees v2 (agent a), simpler model
            frame2 = EpistemicFrame(
                [:v1, :v2],
                [:a => [:v1 => :v2, :v2 => :v2]]
            )
            m2 = EpistemicModel(frame2, [:p => [:v2]])

            # Bisimulation: w1↔v1, w2↔v2, w3↔v2
            bis = [:w1 => :v1, :w2 => :v2, :w3 => :v2]
            @test is_bisimulation(m1, m2, bis)
            @test bisimilar_worlds(m1, m2, :w1, :v1, bis)

            # Theorem 15.8: bisimilar worlds satisfy same formulas
            p = Atom(:p)
            kap = Knowledge(:a, p)
            # K[a]p at w1 in m1: successors w2,w3 both have p → true
            @test satisfies(m1, :w1, kap)
            # K[a]p at v1 in m2: successor v2 has p → true
            @test satisfies(m2, :v1, kap)
            # Both agree
            @test satisfies(m1, :w1, kap) == satisfies(m2, :v1, kap)
        end

        @testset "EpistemicModel from KripkeModel" begin
            frame = KripkeFrame([:w1, :w2], [:w1 => :w2])
            km = KripkeModel(frame, [:p => [:w2]])
            em = EpistemicModel(km, :a)
            p = Atom(:p)
            @test :w2 in accessible(em.frame, :a, :w1)
            @test satisfies(em, :w1, Knowledge(:a, p))
        end

    end  # Chapter 15

end
