"""
Visualization of Kripke models using CairoMakie and GraphMakie.

Provides `visualize_model` for rendering Kripke frames and models as
publication-quality directed graphs, matching the style of Boxes and Diamonds.
"""

using CairoMakie
using GraphMakie
import Graphs: SimpleDiGraph, add_edge!, edges, src, dst, has_edge

"""
    visualize_model(model::KripkeModel; kwargs...)
    visualize_model(frame::KripkeFrame; kwargs...)

Render a Kripke model (or frame) as a directed graph.

Worlds are shown as labeled nodes. Edges represent the accessibility relation.
When a `KripkeModel` is given, each node is annotated with the propositional
variables true (or negated) at that world.

# Keyword Arguments
- `positions::Dict{Symbol,Tuple{Float64,Float64}}`: manual (x,y) positions for worlds.
  If omitted, an automatic spring layout is used.
- `show_valuations::Bool=true`: annotate nodes with which atoms are true/false.
  Only applies to `KripkeModel` (ignored for frames).
- `atom_order::Vector{Symbol}=Symbol[]`: order in which to display atoms in labels.
  If empty, atoms are sorted alphabetically.
- `title::String=""`: optional title displayed above the figure.
- `size::Tuple{Int,Int}=(500,400)`: figure size in pixels.
- `node_size::Real=30`: radius of world nodes.
- `node_color::Any=:white`: fill color for nodes.
- `edge_color::Any=:gray40`: color for edges/arrows.
- `arrow_size::Real=20`: size of arrowheads.
- `curve_distance::Real=0.2`: curvature for bidirectional edges.

# Returns
A `Makie.Figure` object that displays inline in Pluto and Jupyter notebooks.

# Examples
```julia
frame = KripkeFrame([:w1, :w2, :w3], [:w1 => :w2, :w1 => :w3])
model = KripkeModel(frame, [:p => [:w1, :w2], :q => [:w2]])

# Automatic layout
visualize_model(model)

# Manual layout matching Figure 1.1 of Boxes and Diamonds
visualize_model(model,
    positions = Dict(:w1 => (0.0, 0.0), :w2 => (2.0, 1.0), :w3 => (2.0, -1.0)),
    title = "Figure 1.1")
```
"""
function visualize_model(model::KripkeModel;
        positions::Dict{Symbol,Tuple{Float64,Float64}} = Dict{Symbol,Tuple{Float64,Float64}}(),
        show_valuations::Bool = true,
        atom_order::Vector{Symbol} = Symbol[],
        title::String = "",
        size::Tuple{Int,Int} = (500, 400),
        node_size::Real = 30,
        node_color = :white,
        edge_color = :gray40,
        arrow_size::Real = 20,
        curve_distance::Real = 0.2)

    frame = model.frame
    worlds = sort(collect(frame.worlds))
    n = length(worlds)
    world_index = Dict(w => i for (i, w) in enumerate(worlds))

    # Build directed graph
    g = SimpleDiGraph(n)
    for w in worlds
        for v in accessible(frame, w)
            add_edge!(g, world_index[w], world_index[v])
        end
    end

    # Positions
    if isempty(positions)
        layout_func = GraphMakie.Spring()
        pos = layout_func(g)
        xs = Float64[p[1] for p in pos]
        ys = Float64[p[2] for p in pos]
    else
        xs = Float64[positions[w][1] for w in worlds]
        ys = Float64[positions[w][2] for w in worlds]
    end

    # Compute valuation labels
    if show_valuations
        all_atoms = isempty(atom_order) ? sort(collect(keys(model.valuation))) : atom_order
        val_labels = [_format_valuation(model, w, all_atoms) for w in worlds]
    else
        val_labels = fill("", n)
    end

    # Build combined label: world name + valuation
    combined_labels = String[]
    for (i, w) in enumerate(worlds)
        name = _format_world_name(w)
        if show_valuations && !isempty(val_labels[i])
            push!(combined_labels, name * "\n" * val_labels[i])
        else
            push!(combined_labels, name)
        end
    end

    # Edge curving for bidirectional edges and self-loops
    edge_list = collect(edges(g))
    tangents, tfactor = _compute_edge_curves(g, edge_list, xs, ys, curve_distance)

    # Create figure
    fig = Figure(; size=size, backgroundcolor=:white)

    if !isempty(title)
        Label(fig[0, 1], title; fontsize=18, font=:bold, halign=:center)
    end

    ax = Axis(fig[1, 1]; backgroundcolor=:white)
    hidedecorations!(ax)
    hidespines!(ax)

    # Build graphplot kwargs
    gp_kwargs = Dict{Symbol,Any}(
        :layout => _ -> Point2f.(zip(xs, ys)),
        :node_size => node_size,
        :node_color => node_color,
        :node_strokewidth => 2.0,
        :node_strokecolor => :black,
        :nlabels => combined_labels,
        :nlabels_fontsize => 14,
        :nlabels_distance => 10,
        :edge_color => edge_color,
        :arrow_size => arrow_size,
        :arrow_shift => :end,
    )

    if !isempty(tangents)
        gp_kwargs[:tangents] = tangents
        gp_kwargs[:tfactor] = tfactor
    end

    graphplot!(ax, g; gp_kwargs...)

    # Set axis limits with padding so labels aren't clipped
    xmin, xmax = extrema(xs)
    ymin, ymax = extrema(ys)
    xpad = max(0.8, (xmax - xmin) * 0.3)
    ypad = max(0.8, (ymax - ymin) * 0.3)
    xlims!(ax, xmin - xpad, xmax + xpad)
    ylims!(ax, ymin - ypad, ymax + ypad)

    fig
end

function visualize_model(frame::KripkeFrame; kwargs...)
    model = KripkeModel(frame, Dict{Symbol,Set{Symbol}}())
    visualize_model(model; show_valuations=false, kwargs...)
end

"""
    _format_world_name(w::Symbol)

Format a world name for display. Converts :w1 to "w₁", :w2 to "w₂", etc.
"""
function _format_world_name(w::Symbol)
    s = string(w)
    m = match(r"^w(\d+)$", s)
    if m !== nothing
        subscripts = Dict('0'=>'₀','1'=>'₁','2'=>'₂','3'=>'₃','4'=>'₄',
                         '5'=>'₅','6'=>'₆','7'=>'₇','8'=>'₈','9'=>'₉')
        return "w" * join(get(subscripts, c, c) for c in m.captures[1])
    end
    s
end

"""
    _format_valuation(model::KripkeModel, world::Symbol, atoms::Vector{Symbol})

Format the valuation at a world as a string like "p, ¬q".
"""
function _format_valuation(model::KripkeModel, world::Symbol, atoms::Vector{Symbol})
    parts = String[]
    for a in atoms
        worlds_true = get(model.valuation, a, Set{Symbol}())
        if world in worlds_true
            push!(parts, string(a))
        else
            push!(parts, "¬" * string(a))
        end
    end
    join(parts, ", ")
end

"""
    _compute_edge_curves(g, edge_list, xs, ys, curve_distance)

Compute tangent vectors and tfactors for edge rendering.
Returns empty vectors if no special curving is needed.
"""
function _compute_edge_curves(g, edge_list, xs, ys, curve_distance)
    needs_curving = any(edge_list) do e
        s, d = src(e), dst(e)
        s == d || has_edge(g, d, s)
    end
    if !needs_curving
        return Tuple{Point2f, Point2f}[], Float32[]
    end

    n_edges = length(edge_list)
    tangents = Vector{Tuple{Point2f, Point2f}}(undef, n_edges)
    tfactor = fill(1.0f0, n_edges)

    for (idx, e) in enumerate(edge_list)
        s, d = src(e), dst(e)
        if s == d
            # Self-loop: curve upward from node
            cx = sum(xs) / length(xs)
            cy = sum(ys) / length(ys)
            dx = xs[s] - cx
            dy = ys[s] - cy
            len = sqrt(dx^2 + dy^2)
            angle = len < 1e-6 ? π/2 : atan(dy, dx)
            spread = 0.8
            t1 = Point2f(cos(angle + spread), sin(angle + spread))
            t2 = Point2f(cos(angle - spread), sin(angle - spread))
            tangents[idx] = (t1, t2)
            tfactor[idx] = 0.5f0
        elseif has_edge(g, d, s)
            # Bidirectional: offset perpendicular to edge direction
            ddx = xs[d] - xs[s]
            ddy = ys[d] - ys[s]
            len = sqrt(ddx^2 + ddy^2)
            px = -ddy / len * curve_distance
            py = ddx / len * curve_distance
            tangents[idx] = (Point2f(ddx + px, ddy + py), Point2f(-ddx + px, -ddy + py))
            tfactor[idx] = 0.5f0
        else
            # Straight edge
            ddx = xs[d] - xs[s]
            ddy = ys[d] - ys[s]
            tangents[idx] = (Point2f(ddx, ddy), Point2f(-ddx, -ddy))
            tfactor[idx] = 1.0f0
        end
    end

    tangents, tfactor
end
