# custom_settings.jl
#
# Demonstrates how to modify model settings such as dates,
# data vintage, forecast horizons, and output paths.
#
# Usage:
#   julia custom_settings.jl
#   # or from the REPL:
#   include("examples/custom_settings.jl")

using DSGE, Dates

println("=" ^ 60)
println("DSGE.jl Custom Settings Example")
println("=" ^ 60)

# ── 1. Create a model with default settings ───────────────────
m = AnSchorfheide()
println("\nModel: ", description(m))

# ── 2. Inspect default settings ───────────────────────────────
println("\n── Default Settings ──")
println("  Data vintage:          ", data_vintage(m))
println("  Save root:             ", saveroot(m))
println("  Data root:             ", dataroot(m))
println("  Forecast horizons:     ", get_setting(m, :forecast_horizons))
println("  Presample start:       ", date_presample_start(m))
println("  Mainsample start:      ", date_mainsample_start(m))
println("  Forecast start:        ", date_forecast_start(m))

# ── 3. Modify date settings ──────────────────────────────────
# Use the `<=` operator to add or update settings
println("\n── Modifying Settings ──")

# Change the data vintage (format: YYMMDD)
m <= Setting(:data_vintage, "241030")
println("  New data vintage:      ", data_vintage(m))

# Change forecast start date
m <= Setting(:date_forecast_start, quartertodate("2024-Q4"))
println("  New forecast start:    ", date_forecast_start(m))

# Change the number of forecast horizons
m <= Setting(:forecast_horizons, 20)
println("  New forecast horizons: ", get_setting(m, :forecast_horizons))

# Change impulse response horizon
m <= Setting(:impulse_response_horizons, 40)
println("  IRF horizons:          ", get_setting(m, :impulse_response_horizons))

# ── 4. Configure estimation settings ─────────────────────────
println("\n── Estimation Settings ──")

# Choose sampling method: :MH (Metropolis-Hastings) or :SMC (Sequential Monte Carlo)
m <= Setting(:sampling_method, :MH)
println("  Sampling method:       ", get_setting(m, :sampling_method))

# Number of MH simulation draws
m <= Setting(:n_mh_simulations, 5000)
println("  MH simulations:        ", get_setting(m, :n_mh_simulations))

# Number of MH blocks
m <= Setting(:n_mh_blocks, 5)
println("  MH blocks:             ", get_setting(m, :n_mh_blocks))

# Whether to reoptimize the posterior mode
m <= Setting(:reoptimize, true)
println("  Reoptimize:            ", get_setting(m, :reoptimize))

# Whether to recalculate the Hessian
m <= Setting(:calculate_hessian, true)
println("  Calculate Hessian:     ", get_setting(m, :calculate_hessian))

# ── 5. Custom settings via constructor ────────────────────────
println("\n── Custom Settings via Constructor ──")

# You can pass settings at model construction time
custom = [
    Setting(:data_vintage, "241030"),
    Setting(:forecast_horizons, 24),
    Setting(:impulse_response_horizons, 40),
]

m2 = AnSchorfheide(; custom_settings = custom)
println("  Data vintage:          ", data_vintage(m2))
println("  Forecast horizons:     ", get_setting(m2, :forecast_horizons))
println("  IRF horizons:          ", get_setting(m2, :impulse_response_horizons))

# ── 6. Subspecifications ──────────────────────────────────────
println("\n── Using Subspecifications ──")

# Subspecifications override default parameter values
m_ss0 = AnSchorfheide("ss0")
m_ss1 = AnSchorfheide("ss1")
println("  Default subspec (ss0): ", m_ss0.subspec)
println("  Alternate subspec (ss1): ", m_ss1.subspec)

# ── 7. Solve with modified settings and compare ──────────────
println("\n── Solving with Modified Settings ──")

m_default = AnSchorfheide()
m_custom  = AnSchorfheide()
m_custom <= Setting(:impulse_response_horizons, 24)

system_default = compute_system(m_default)
system_custom  = compute_system(m_custom)

# IRFs are the same (settings don't change the model solution),
# but the horizon differs
_, obs_default, _ = impulse_responses(m_default, system_default)
_, obs_custom, _  = impulse_responses(m_custom,  system_custom)

println("  Default IRF horizon: ", size(obs_default, 2), " quarters")
println("  Custom IRF horizon:  ", size(obs_custom, 2), " quarters")

println("\nDone!")
