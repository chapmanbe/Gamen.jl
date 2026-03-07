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
end
