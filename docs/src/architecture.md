# [Architecture Overview](@id arch-overview)

```@meta
CurrentModule = DSGE
```

This page describes the internal architecture of DSGE.jl: the type hierarchy,
how models are structured, the estimation-to-forecast pipeline, and the layout of the source code.

## Type Hierarchy

At the top of the hierarchy is `AbstractDSGEModel{T}`, which subtypes
`ModelConstructors.AbstractModel{T}`. The parameter `T` is typically `Float64`
and controls the numeric precision used throughout the model.

```
ModelConstructors.AbstractModel{T}
  └── AbstractDSGEModel{T}
        ├── AbstractRepModel{T}      # Representative agent models
        │     ├── SmetsWouters{T}
        │     ├── Model990{T}
        │     ├── Model1002{T}
        │     ├── AnSchorfheide{T}
        │     └── ...
        ├── AbstractHetModel{T}      # Heterogeneous agent models
        │     └── KrusellSmith{T}, ...
        └── AbstractCTModel{T}       # Continuous-time models
```

Additionally, there are two non-DSGE abstract types for VAR-based models:

- `AbstractVARModel{T}`: for standalone VAR models.
- `AbstractDSGEVARModel{T}`: for DSGE-VAR models that combine a DSGE prior with VAR estimation.

And a `PoolModel` type for aggregating predictive densities from multiple models.

### Key Abstract Type Definitions

These are defined in `src/abstractdsgemodel.jl`:

```julia
abstract type AbstractDSGEModel{T} <: ModelConstructors.AbstractModel{T} end
abstract type AbstractRepModel{T}  <: AbstractDSGEModel{T} end
abstract type AbstractHetModel{T}  <: AbstractDSGEModel{T} end
abstract type AbstractCTModel{T}   <: AbstractDSGEModel{T} end
```

## Model Structure

Every concrete DSGE model (e.g., `SmetsWouters`, `AnSchorfheide`) follows the same
structural pattern with these required components:

### 1. Fields

Each model struct contains:

| Field | Type | Purpose |
|:------|:-----|:--------|
| `parameters` | `ParameterVector{T}` | All time-invariant model parameters with priors, bounds, and transformations |
| `steady_state` | `ParameterVector{T}` | Steady-state values computed from `parameters` |
| `keys` | `OrderedDict{Symbol,Int}` | Maps human-readable names to indices in `parameters` and `steady_state` |
| `endogenous_states` | `OrderedDict{Symbol,Int}` | State variable names to column indices |
| `exogenous_shocks` | `OrderedDict{Symbol,Int}` | Shock names to column indices |
| `expected_shocks` | `OrderedDict{Symbol,Int}` | Expectational shock names to column indices |
| `equilibrium_conditions` | `OrderedDict{Symbol,Int}` | Equation names to row indices |
| `endogenous_states_augmented` | `OrderedDict{Symbol,Int}` | Lagged/augmented state indices (added post-solve) |
| `observables` | `OrderedDict{Symbol,Int}` | Observable names to row indices in measurement equation |
| `pseudo_observables` | `OrderedDict{Symbol,Int}` | Pseudo-observable names to row indices |
| `spec` | `String` | Model specification identifier (e.g., `"smets_wouters"`) |
| `subspec` | `String` | Sub-specification (e.g., `"ss0"`) for parameter variants |
| `settings` | `Dict{Symbol,Setting}` | Computation settings and flags |
| `test_settings` | `Dict{Symbol,Setting}` | Settings used in testing mode |
| `rng` | `MersenneTwister` | Random number generator for reproducibility |
| `testing` | `Bool` | Whether the model is in testing mode |
| `observable_mappings` | `OrderedDict{Symbol,Observable}` | Data source and transformation info for observables |
| `pseudo_observable_mappings` | `OrderedDict{Symbol,PseudoObservable}` | Transformations for pseudo-observables |

### 2. Required Functions

Each model must implement these functions:

#### `init_parameters!(m)`
Populates the model's `parameters` vector with parameter objects that specify:
- Initial values and bounds
- Prior distributions (e.g., `Normal`, `BetaAlt`, `GammaAlt`)
- Transformations (e.g., `SquareRoot`, `Exponential`) for mapping between model and optimization space
- Whether the parameter is fixed or estimated

#### `steadystate!(m)`
Computes steady-state values as functions of the structural parameters. Called whenever
parameters change (e.g., during estimation). Some simple models (like `AnSchorfheide`)
have no derived steady-state values.

#### `eqcond(m)`
Returns the five matrices ``(\Gamma_0, \Gamma_1, C, \Psi, \Pi)`` of the canonical
rational expectations form:

```math
\Gamma_0 s_t = \Gamma_1 s_{t-1} + C + \Psi \epsilon_t + \Pi \eta_t
```

For regime-switching models, this function accepts a regime index: `eqcond(m, regime)`.

#### `measurement(m, TTT, RRR, CCC)`
Constructs the measurement equation matrices ``(ZZ, DD, QQ, EE)`` that map
model states to observables:

```math
y_t = ZZ \cdot s_t + DD + u_t, \quad u_t \sim N(0, EE)
```

where ``QQ`` is the covariance of the structural shocks ``\epsilon_t``.

### 3. Model Constructor Flow

When you call `AnSchorfheide()` or `SmetsWouters("ss0")`, the constructor executes:

1. **`model_settings!(m)`**: Sets default computation settings (dates, vintages, file paths, estimation options).
2. **`init_observable_mappings!(m)`**: Defines which data series map to each observable.
3. **`init_parameters!(m)`**: Creates all parameter objects with priors and bounds.
4. **`init_model_indices!(m)`**: Assigns integer indices to all states, shocks, and equations.
5. **`init_subspec!(m)`**: Applies sub-specification overrides to parameters.
6. **`steadystate!(m)`**: Computes initial steady-state values.

## The Estimation-to-Forecast Pipeline

The full workflow from raw data to economic projections follows this pipeline:

```
Data Loading ─→ Model Setup ─→ Posterior Optimization ─→ Sampling ─→ Forecasting
```

### 1. Data Loading (`src/data/`)

```julia
df = load_data(m)
```

- Fetches data from FRED or loads from disk (CSV/HDF5).
- Applies observable-specific transformations (log differences, per-capita adjustments).
- Handles conditional data for nowcasting.
- Key files: `load_data.jl`, `fred_data.jl`, `transformations.jl`.

### 2. Model Setup

```julia
m = Model1002("ss10")
m <= Setting(:data_vintage, "241030")
m <= Setting(:date_forecast_start, quartertodate("2024-Q4"))
```

- Instantiate a model with desired sub-specification.
- Configure settings for dates, data vintage, and computation options.
- The `<=` operator (`Setting`) adds or updates a model setting.

### 3. Posterior Optimization (`src/estimate/`)

```julia
estimate(m, df)
```

The `estimate` function:

1. **Finds the posterior mode** using `csminwel` (a quasi-Newton optimizer by Chris Sims) or `Optim.jl` methods.
2. **Computes the Hessian** at the mode for the Metropolis-Hastings proposal distribution.
3. **Samples from the posterior** using either:
   - **Metropolis-Hastings (MH)**: standard MCMC with a multivariate normal proposal.
   - **Sequential Monte Carlo (SMC)**: particle-based sampling that supports parallelism and bridge estimation across data vintages.

Key files: `estimate.jl`, `optimize.jl`, `csminwel.jl`, `metropolis_hastings.jl`, `smc/`.

### 4. Forecasting (`src/forecast/`)

```julia
forecast_one(m, :mode, :none, output_vars)
```

The `forecast_one` function:

1. Loads parameter draws (mode, mean, or full distribution).
2. Solves the model for each draw using `solve(m)`.
3. Runs the Kalman smoother to extract historical states.
4. Produces forward projections by iterating the state-space system.
5. Computes shock decompositions, impulse responses, and other outputs.
6. Saves results to HDF5 files.

Post-processing with `compute_meansbands` aggregates draws into means and
confidence bands, and applies reverse transformations to convert from model units
(log deviations from steady state) to human-readable units (e.g., annualized percent change).

Key files: `drivers.jl`, `forecast.jl`, `smooth.jl`, `shock_decompositions.jl`, `impulse_responses.jl`.

### 5. Analysis and Decomposition (`src/analysis/`, `src/decomp/`)

- **`compute_meansbands`**: Converts raw forecast draws into statistical summaries.
- **Forecast decomposition**: Attributes changes in forecasts to news (new data),
  data revisions, or parameter re-estimation.

## Source Directory Layout

| Directory | Contents |
|:----------|:---------|
| `src/models/` | Concrete model implementations |
| `src/models/representative/` | Representative agent models (`m990/`, `m1002/`, `smets_wouters/`, `an_schorfheide/`, etc.) |
| `src/models/heterogeneous/` | Heterogeneous agent models |
| `src/models/poolmodel/` | Predictive density pooling |
| `src/models/var/` | VAR and DSGE-VAR models |
| `src/solve/` | `solve.jl` (driver), `gensys.jl` (Sims algorithm), `klein.jl` (Klein method) |
| `src/estimate/` | `estimate.jl`, `optimize.jl`, `csminwel.jl`, `metropolis_hastings.jl`, `smc/` |
| `src/forecast/` | `drivers.jl`, `forecast.jl`, `smooth.jl`, `impulse_responses.jl`, `shock_decompositions.jl` |
| `src/data/` | Data loading, FRED interface, transformations |
| `src/analysis/` | `meansbands.jl`, `compute_meansbands.jl` for post-processing |
| `src/decomp/` | Forecast decomposition (news, data revisions, parameter changes) |
| `src/altpolicy/` | Alternative monetary policy rules |
| `src/scenarios/` | Alternative scenario analysis |
| `src/plot/` | Plotting recipes for fan charts, shock decompositions, prior/posterior |
| `src/statespace/` | State-space types (`System`, `Transition`, `Measurement`) |
| `src/packet/` | Automated report/packet generation |

### Per-Model Directory Structure

Each model directory (e.g., `src/models/representative/an_schorfheide/`) contains:

| File | Purpose |
|:-----|:--------|
| `an_schorfheide.jl` | Model struct definition, constructor, `init_parameters!`, `steadystate!` |
| `eqcond.jl` | Equilibrium condition matrices ``(\Gamma_0, \Gamma_1, C, \Psi, \Pi)`` |
| `measurement.jl` | Measurement equation matrices ``(ZZ, DD, QQ, EE)`` |
| `pseudo_measurement.jl` | Pseudo-measurement equation (for pseudo-observables) |
| `augment_states.jl` | Adds lagged states after `gensys` solves the model |
| `observables.jl` | Observable-to-data mappings |
| `subspecs.jl` | Parameter overrides for sub-specifications |

## Settings System

Model settings control computation without changing the economic structure. They are stored
as `Setting` objects in the model's `settings` dictionary and accessed via `get_setting(m, :key)`.

Common settings include:

| Setting | Purpose |
|:--------|:--------|
| `:data_vintage` | Date string identifying the data snapshot (e.g., `"241030"`) |
| `:date_forecast_start` | First quarter of the forecast horizon |
| `:date_mainsample_start` | Start of the estimation sample |
| `:n_mh_simulations` | Number of Metropolis-Hastings draws per block |
| `:sampling_method` | `:MH` or `:SMC` |
| `:forecast_horizons` | Number of quarters to forecast |
| `:impulse_response_horizons` | Number of periods for IRF computation |
| `:use_parallel_workers` | Enable parallel computation |

Settings are added or modified using the `<=` operator:

```julia
m <= Setting(:data_vintage, "241030")
m <= Setting(:n_mh_simulations, 5000)
```

See `src/defaults.jl` for the full list of default settings.
