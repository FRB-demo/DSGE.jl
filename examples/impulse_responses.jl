# impulse_responses.jl
#
# Demonstrates how to compute and display impulse response functions
# for the SmetsWouters model.
#
# Usage:
#   julia impulse_responses.jl
#   # or from the REPL:
#   include("examples/impulse_responses.jl")

using DSGE

println("=" ^ 60)
println("DSGE.jl Impulse Response Example: SmetsWouters")
println("=" ^ 60)

# ── 1. Instantiate and solve ─────────────────────────────────
m = SmetsWouters()
println("\nModel: ", description(m))

println("Solving model...")
system = compute_system(m)
println("  Done.")

# ── 2. Compute impulse responses ──────────────────────────────
println("\nComputing impulse response functions...")
states, obs, pseudo = impulse_responses(m, system)

horizon = size(obs, 2)
nshocks = size(obs, 3)

println("  IRF dimensions:")
println("    States: ", size(states))
println("    Observables: ", size(obs))
println("    Pseudo-observables: ", size(pseudo))
println("    Horizon: $horizon quarters")
println("    Shocks: $nshocks")

# ── 3. Display IRFs for each shock ────────────────────────────
shock_names = collect(keys(m.exogenous_shocks))
obs_names   = collect(keys(m.observables))

for (shock_name, shock_idx) in m.exogenous_shocks
    println("\n── IRF to shock: $shock_name ──")
    println("  Quarter:  ", join(lpad.(1:min(12, horizon), 8), ""))
    for (obs_name, obs_idx) in m.observables
        vals = round.(obs[obs_idx, 1:min(12, horizon), shock_idx], digits=4)
        println("  ", rpad(obs_name, 25), join(lpad.(vals, 8), ""))
    end
end

# ── 4. Demonstrate IRFs with flipped (positive) shocks ────────
println("\n\n── IRFs with positive shocks (flip_shocks=true) ──")
states_pos, obs_pos, pseudo_pos = impulse_responses(m, system; flip_shocks=true)

# Show the monetary policy shock as an example
mp_shock_idx = m.exogenous_shocks[:rm_sh]
println("\nPositive monetary policy shock:")
println("  Quarter:  ", join(lpad.(1:min(12, horizon), 8), ""))
for (obs_name, obs_idx) in m.observables
    vals = round.(obs_pos[obs_idx, 1:min(12, horizon), mp_shock_idx], digits=4)
    println("  ", rpad(obs_name, 25), join(lpad.(vals, 8), ""))
end

println("\nDone!")
