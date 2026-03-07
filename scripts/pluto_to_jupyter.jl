#!/usr/bin/env julia
#
# Convert a Pluto.jl notebook to a Jupyter .ipynb notebook.
# No external dependencies required.
#
# Usage:
#   julia scripts/pluto_to_jupyter.jl notebooks/pluto/ch4_completeness.jl
#   julia scripts/pluto_to_jupyter.jl notebooks/pluto/ch4_completeness.jl output.ipynb
#
# If no output path is given, writes to notebooks/jupyter/<stem>.ipynb

# ── JSON generation (no dependencies) ──

function json_escape(s::AbstractString)
    s = replace(s, "\\" => "\\\\")
    s = replace(s, "\"" => "\\\"")
    s = replace(s, "\n" => "\\n")
    s = replace(s, "\t" => "\\t")
    s = replace(s, "\r" => "\\r")
    s
end

function json_string(s::AbstractString)
    "\"$(json_escape(s))\""
end

function json_array(items::Vector{String}; indent=0, compact=false)
    if isempty(items)
        return "[]"
    end
    if compact
        return "[" * join(items, ", ") * "]"
    end
    pad = " " ^ indent
    inner_pad = " " ^ (indent + 1)
    lines = ["["]
    for (i, item) in enumerate(items)
        trailing = i < length(items) ? "," : ""
        push!(lines, inner_pad * item * trailing)
    end
    push!(lines, pad * "]")
    join(lines, "\n")
end

# ── Pluto parsing ──

function parse_pluto(path::String)
    lines = readlines(path)

    # Parse cell order from the bottom of the file
    order_ids = String[]
    in_order = false
    for line in lines
        if startswith(line, "# ╔═╡ Cell order:")
            in_order = true
            continue
        end
        if in_order
            m = match(r"^# (╟─|╠═)(.+)$", line)
            if m !== nothing
                push!(order_ids, strip(m.captures[2]))
            end
        end
    end

    # Parse cell bodies
    cell_bodies = Dict{String,String}()
    current_id = nothing
    current_lines = String[]

    for line in lines
        m = match(r"^# ╔═╡ (.+)$", line)
        if m !== nothing
            id = strip(m.captures[1])
            if id == "Cell order:"
                if current_id !== nothing
                    cell_bodies[current_id] = join(current_lines, "\n")
                end
                break
            end
            if current_id !== nothing
                cell_bodies[current_id] = join(current_lines, "\n")
            end
            current_id = id
            current_lines = String[]
            continue
        end
        if current_id !== nothing
            push!(current_lines, line)
        end
    end
    if current_id !== nothing && !haskey(cell_bodies, current_id)
        cell_bodies[current_id] = join(current_lines, "\n")
    end

    return order_ids, cell_bodies
end

# ── Cell transformation ──

function process_cell(body::String)
    stripped = strip(body)

    # Skip Pluto boilerplate
    if occursin("using Markdown", stripped) && occursin("using InteractiveUtils", stripped)
        return nothing
    end

    # Detect markdown cells
    if startswith(stripped, "md\"\"\"")
        md = strip(replace(replace(stripped, r"^md\"\"\"" => ""), r"\"\"\"$" => ""))
        return (:markdown, md)
    end

    # Transform code cells
    code = stripped

    # Unwrap begin...end blocks
    if startswith(code, "begin") && endswith(code, "end")
        inner = strip(code[nextind(code, 0, 6):prevind(code, lastindex(code), 3)])
        lines = split(inner, "\n")
        unindented = [startswith(l, "\t") ? l[nextind(l, 0, 2):end] : l for l in lines]
        code = join(unindented, "\n")
    end

    # Remove trailing semicolons (Pluto output suppression)
    if endswith(code, ";")
        code = strip(code[1:prevind(code, lastindex(code))])
    end

    return (:code, code)
end

# ── Jupyter notebook generation ──

function source_lines_json(content::String)
    lines = split(content, "\n")
    json_items = String[]
    for (i, line) in enumerate(lines)
        if i < length(lines)
            push!(json_items, json_string(line * "\n"))
        else
            push!(json_items, json_string(line))
        end
    end
    json_array(json_items; indent=3, compact=false)
end

function generate_notebook(cells::Vector{Tuple{Symbol,String}})
    cell_jsons = String[]

    for (cell_type, content) in cells
        src = source_lines_json(content)
        if cell_type == :markdown
            push!(cell_jsons, """  {
   "cell_type": "markdown",
   "metadata": {},
   "source": $src
  }""")
        else
            push!(cell_jsons, """  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": $src
  }""")
        end
    end

    cells_json = join(cell_jsons, ",\n")

    return """{
 "cells": [
$cells_json
 ],
 "metadata": {
  "kernelspec": {
   "display_name": "Julia 1.11",
   "language": "julia",
   "name": "julia-1.11"
  },
  "language_info": {
   "file_extension": ".jl",
   "mimetype": "application/julia",
   "name": "julia",
   "version": "1.11.0"
  }
 },
 "nbformat": 4,
 "nbformat_minor": 5
}
"""
end

# ── Main ──

function main()
    if length(ARGS) < 1
        println(stderr, "Usage: julia scripts/pluto_to_jupyter.jl <input.jl> [output.ipynb]")
        println(stderr, "Convert a Pluto notebook to Jupyter format.")
        exit(1)
    end

    input_path = ARGS[1]
    if length(ARGS) >= 2
        output_path = ARGS[2]
    else
        stem = splitext(basename(input_path))[1]
        output_dir = joinpath(dirname(dirname(input_path)), "jupyter")
        mkpath(output_dir)
        output_path = joinpath(output_dir, stem * ".ipynb")
    end

    println("Converting: $input_path → $output_path")

    order_ids, cell_bodies = parse_pluto(input_path)
    cells = Tuple{Symbol,String}[]

    for id in order_ids
        body = get(cell_bodies, id, "")
        result = process_cell(body)
        result === nothing && continue
        push!(cells, result)
    end

    notebook_json = generate_notebook(cells)

    open(output_path, "w") do io
        write(io, notebook_json)
    end

    n_md = count(c -> c[1] == :markdown, cells)
    n_code = count(c -> c[1] == :code, cells)
    println("Done: $(length(cells)) cells ($n_md markdown, $n_code code)")
end

main()
