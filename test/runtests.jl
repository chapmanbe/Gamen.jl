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
            schema_k = Implies(Box(Implies(p, q)), Implies(Box(p), Box(q)))

            frame1 = KripkeFrame([:w1, :w2], [:w1 => :w2])
            frame2 = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w2 => :w3])
            frame3 = KripkeFrame([:w1], [:w1 => :w1])

            @test is_valid_on_frame(frame1, schema_k) == true
            @test is_valid_on_frame(frame2, schema_k) == true
            @test is_valid_on_frame(frame3, schema_k) == true
        end
    end
end
