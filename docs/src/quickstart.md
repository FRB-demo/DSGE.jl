# Quickstart Guide

```@meta
CurrentModule = DSGE
```

This guide walks you through installing DSGE.jl, solving a model, and computing impulse response functions.

## Installation

DSGE.jl requires **Julia 1.x** (1.0 or later). Install the package from the Julia REPL:

```julia
using Pkg
Pkg.add("DSGE")
```

If you want the latest development version:

```julia
Pkg.add(url="https://github.com/FRBNY-DSGE/DSGE.jl.git")
```

## Minimal Working Example

The simplest model in DSGE.jl is `AnSchorfheide`, a three-equation New Keynesian model from
*Bayesian Estimation of DSGE Models* by Sungbae An and Frank Schorfheide. It has only
3 structural shocks and 8 states, making it ideal for learning the package.

### Step 1: Instantiate and Solve

```julia
using DSGE

# Create the model with default parameters
m = AnSchorfheide()

# Solve the model: computes the state-space transition matrices
TTT, RRR, CCC = solve(m)
```

`solve(m)` returns three matrices that define the **state transition equation**:

```math
s_t = TTT \cdot s_{t-1} + RRR \cdot \epsilon_t + CCC
```

where:
- `TTT` (transition matrix): governs how states evolve over time. Eigenvalues inside the unit circle indicate a stable, mean-reverting system.
- `RRR` (shock-loading matrix): maps exogenous shocks ``\epsilon_t`` into state variables.
- `CCC` (constant vector): captures the steady-state constants in the transition.

### Step 2: Compute the Full State-Space System

To get both the transition and measurement equations, use `compute_system`:

```julia
system = compute_system(m)

# Access individual matrices
TTT = system[:TTT]   # transition matrix
RRR = system[:RRR]   # shock-loading matrix
ZZ  = system[:ZZ]    # measurement matrix (maps states to observables)
DD  = system[:DD]    # measurement constant
QQ  = system[:QQ]    # shock covariance matrix
```

The **measurement equation** is:

```math
y_t = ZZ \cdot s_t + DD + u_t
```

where ``y_t`` are the observables (e.g., GDP growth, inflation, interest rate) and ``u_t`` is measurement error.

### Step 3: Compute Impulse Response Functions

Impulse response functions (IRFs) show how the economy responds to a one-standard-deviation structural shock:

```julia
# Compute IRFs from the state-space system
states, obs, pseudo = impulse_responses(m, system)
```

The returned arrays have dimensions:
- `states`: `n_states x horizon x n_shocks`
- `obs`: `n_observables x horizon x n_shocks`
- `pseudo`: `n_pseudo_observables x horizon x n_shocks`

For `AnSchorfheide`, the three shocks are:
1. **Technology shock** (`z_sh`): a positive shock raises output and lowers inflation.
2. **Government spending shock** (`g_sh`): a positive shock raises output and inflation through demand effects.
3. **Monetary policy shock** (`rm_sh`): a contractionary shock raises the interest rate, lowering output and inflation.

```julia
# Display IRF of observables to the monetary policy shock
shock_index = m.exogenous_shocks[:rm_sh]
println("Observable IRFs to monetary policy shock (first 8 quarters):")
for (name, idx) in m.observables
    println("  $name: ", round.(obs[idx, 1:8, shock_index], digits=4))
end
```

## Using Larger Models

DSGE.jl includes several more detailed models:

```julia
# Smets-Wouters (2007): medium-scale model with 7 shocks
m_sw = SmetsWouters()
TTT, RRR, CCC = solve(m_sw)

# Model 990: the NY Fed's DSGE model
m990 = Model990()

# Model 1002: the extended NY Fed model with financial frictions
m1002 = Model1002("ss10")
```

These larger models follow the same workflow: instantiate, solve, compute IRFs.

## Common Pitfalls

### Data Vintage Settings

Models store a `data_vintage` setting that determines which data files are loaded.
If you encounter file-not-found errors during estimation or forecasting, check your vintage:

```julia
# Check current data vintage
println(data_vintage(m))

# Set the vintage to match your available data
m <= Setting(:data_vintage, "241030")
```

### Save Root / Path Configuration

By default, DSGE.jl writes output (estimation draws, forecasts) to a directory tree
rooted at `saveroot(m)`. Make sure this directory exists or configure it:

```julia
# Check where output will be saved
println(saveroot(m))

# Override the save root
m <= Setting(:saveroot, "/path/to/your/output/")
```

### Data Directory

Model data is expected at `dataroot(m)`. For estimation and forecasting,
you need to ensure the data files are in the right location:

```julia
println(dataroot(m))
m <= Setting(:dataroot, "/path/to/your/data/")
```

### Forecast Dates

Before forecasting, make sure the forecast start date is set correctly:

```julia
using Dates
m <= Setting(:date_forecast_start, quartertodate("2024-Q4"))
```

## Next Steps

- [Model Design](@ref): understand how DSGE models are structured in the package.
- [Architecture Overview](@ref arch-overview): learn about the type hierarchy and source code layout.
- [Solving the Model](@ref solving-dsge-doc): details on the `gensys` algorithm and state-space systems.
- [Estimation](@ref estimation-doc): estimate model parameters via Metropolis-Hastings or SMC.
- [Forecasting](@ref forecast-doc): produce forecasts and shock decompositions.
- [Impulse Response Functions](@ref irf-doc): more on computing and interpreting IRFs.
