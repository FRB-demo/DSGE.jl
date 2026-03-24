# basic_model.jl
#
# Demonstrates how to load the AnSchorfheide model, solve it,
# and inspect the resulting state-space system matrices.
#
# Usage:
#   julia basic_model.jl
#   # or from the REPL:
#   include("examples/basic_model.jl")

using DSGE

println("=" ^ 60)
println("DSGE.jl Basic Model Example: AnSchorfheide")
println("=" ^ 60)

# ── 1. Instantiate the model ─────────────────────────────────
m = AnSchorfheide()
println("\nModel: ", description(m))
println("Specification: ", m.spec)
println("Sub-specification: ", m.subspec)

# ── 2. Inspect model dimensions ──────────────────────────────
println("\n── Model Dimensions ──")
println("  States:              ", n_states_augmented(m))
println("  Shocks:              ", n_shocks_exogenous(m))
println("  Observables:         ", n_observables(m))
println("  Parameters:          ", n_parameters(m))
println("  Free parameters:     ", n_parameters_free(m))

# ── 3. List states and shocks ────────────────────────────────
println("\n── Endogenous States ──")
for (name, idx) in m.endogenous_states
    println("  [$idx] $name")
end

println("\n── Exogenous Shocks ──")
for (name, idx) in m.exogenous_shocks
    println("  [$idx] $name")
end

println("\n── Observables ──")
for (name, idx) in m.observables
    println("  [$idx] $name")
end

# ── 4. Solve the model ───────────────────────────────────────
println("\n── Solving the model ──")
TTT, RRR, CCC = solve(m)

println("\nTransition matrix TTT ($(size(TTT))):")
display(round.(TTT, digits=4))

println("\n\nShock-loading matrix RRR ($(size(RRR))):")
display(round.(RRR, digits=4))

println("\n\nConstant vector CCC ($(length(CCC))):")
display(round.(CCC, digits=4))

# ── 5. Compute the full state-space system ────────────────────
println("\n\n── Full State-Space System ──")
system = compute_system(m)

println("\nMeasurement matrix ZZ ($(size(system[:ZZ]))):")
display(round.(system[:ZZ], digits=4))

println("\n\nMeasurement constant DD ($(length(system[:DD]))):")
display(round.(system[:DD], digits=4))

println("\n\nShock covariance QQ ($(size(system[:QQ]))):")
display(round.(system[:QQ], digits=4))

# ── 6. Check stability ───────────────────────────────────────
using LinearAlgebra
eigenvalues = eigvals(TTT)
max_eig = maximum(abs.(eigenvalues))
println("\n\n── Stability Check ──")
println("  Max |eigenvalue| of TTT: ", round(max_eig, digits=6))
println("  Stable (all inside unit circle): ", max_eig < 1.0)

println("\nDone!")
