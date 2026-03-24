"""
Custom exception types for DSGE.jl validation errors.
"""

"""
    DSGEParameterError <: Exception

Thrown when model parameters are invalid (e.g., out of bounds).

### Fields
- `msg::String`: Descriptive error message
"""
struct DSGEParameterError <: Exception
    msg::String
end
Base.showerror(io::IO, ex::DSGEParameterError) = print(io, "DSGEParameterError: ", ex.msg)

"""
    DSGEDataError <: Exception

Thrown when observational data is invalid or inconsistent with model expectations.

### Fields
- `msg::String`: Descriptive error message
"""
struct DSGEDataError <: Exception
    msg::String
end
Base.showerror(io::IO, ex::DSGEDataError) = print(io, "DSGEDataError: ", ex.msg)

"""
    DSGEEstimationError <: Exception

Thrown when estimation settings are invalid or inconsistent.

### Fields
- `msg::String`: Descriptive error message
"""
struct DSGEEstimationError <: Exception
    msg::String
end
Base.showerror(io::IO, ex::DSGEEstimationError) = print(io, "DSGEEstimationError: ", ex.msg)

"""
    validate_parameters(m::AbstractDSGEModel)

Check that all model parameters are within their specified bounds.
Raises a `DSGEParameterError` if any non-fixed parameter is out of range.

Parameters that are marked as `fixed` are skipped, consistent with
the bounds-checking convention used during estimation (see `likelihood` in
`src/estimate/posterior.jl`).
"""
function validate_parameters(m::AbstractDSGEModel)
    errors = String[]
    for θ in m.parameters
        if !θ.fixed
            (left, right) = θ.valuebounds
            val = θ.value
            if !(left <= val <= right)
                desc = hasfield(typeof(θ), :description) ? θ.description : string(θ.key)
                push!(errors, "Parameter $(θ.key)=$(val) is out of valid range [$(left), $(right)]. ($desc)")
            end
        end
    end
    if !isempty(errors)
        msg = "Parameter validation failed with $(length(errors)) error(s):\n" *
              join(["  - " * e for e in errors], "\n")
        throw(DSGEParameterError(msg))
    end
    return nothing
end

"""
    validate_data(m::AbstractDSGEModel, data::DataFrame)

Validate that observational data matches model expectations.
Raises a `DSGEDataError` if:
- The data has fewer observable columns than the model expects
- Any observable column is entirely NaN or missing

Warnings are issued for:
- Columns containing some NaN or missing values
- Non-quarterly date frequency (if a `:date` column is present)
"""
function validate_data(m::AbstractDSGEModel, data::DataFrame)
    n_obs = n_observables(m)
    # Only check columns that correspond to model observables
    obs_keys = collect(keys(m.observables))
    data_col_names = propertynames(data)

    # Check that all required observable columns are present
    missing_obs = Symbol[]
    for obs in obs_keys
        if !(obs in data_col_names)
            push!(missing_obs, obs)
        end
    end

    if !isempty(missing_obs)
        throw(DSGEDataError(
            "Data is missing $(length(missing_obs)) required observable column(s): " *
            join(string.(missing_obs), ", ") * ". " *
            "The model expects $(n_obs) observable(s). Ensure the data contains all required observables."
        ))
    end

    # Check observable columns for entirely NaN/missing values
    all_nan_cols = String[]
    partial_nan_cols = String[]
    for col in obs_keys
        col_data = data[!, col]
        n_total = length(col_data)
        n_missing = count(ismissing, col_data)
        non_missing = collect(skipmissing(col_data))
        n_nan = count(isnan, non_missing)
        n_invalid = n_missing + n_nan

        if n_invalid == n_total
            push!(all_nan_cols, string(col))
        elseif n_invalid > 0
            push!(partial_nan_cols, string(col))
        end
    end

    if !isempty(all_nan_cols)
        throw(DSGEDataError(
            "The following observable column(s) are entirely NaN or missing: " *
            join(all_nan_cols, ", ") * ". " *
            "Check that data is loaded correctly for these series."
        ))
    end

    if !isempty(partial_nan_cols)
        @warn "The following columns contain some NaN or missing values: $(join(partial_nan_cols, ", ")). " *
              "These will be handled according to the model's filtering settings."
    end

    # Validate date frequency if :date column exists
    if :date in propertynames(data) && nrow(data) >= 2
        dates = data[!, :date]
        diffs = [Dates.value(dates[i+1] - dates[i]) for i in 1:(length(dates)-1)]
        # Quarterly data should have roughly 90-92 day gaps
        non_quarterly = count(d -> d < 80 || d > 100, diffs)
        if non_quarterly > 0
            @warn "Detected $(non_quarterly) non-quarterly date gap(s) in the data. " *
                  "DSGE models typically expect quarterly data."
        end
    end

    return nothing
end

"""
    validate_estimation_settings(m::AbstractDSGEModel)

Validate MCMC/SMC sampler settings before starting estimation.
Raises a `DSGEEstimationError` if critical settings are invalid.

Checks performed:
- `n_mh_simulations` must be > 0
- `n_mh_burn` must be < `n_mh_simulations`
- `date_presample_start` must be before `date_mainsample_start`
- `sampling_method` must be `:MH` or `:SMC`

Warnings are issued for settings that may cause numerical issues.
"""
function validate_estimation_settings(m::AbstractDSGEModel)
    errors = String[]

    # Validate sampling method
    sampling_method = get_setting(m, :sampling_method)
    if !(sampling_method in [:MH, :SMC])
        push!(errors, "Setting :sampling_method=$(sampling_method) is invalid. Must be :MH or :SMC.")
    end

    # Validate MH-specific settings
    if sampling_method == :MH
        n_sim = get_setting(m, :n_mh_simulations)
        n_burn = get_setting(m, :n_mh_burn)

        if n_sim <= 0
            push!(errors, "Setting :n_mh_simulations=$(n_sim) must be > 0.")
        end
        if n_burn >= n_sim
            push!(errors, "Setting :n_mh_burn=$(n_burn) must be less than :n_mh_simulations=$(n_sim).")
        end
        if n_burn < 0
            push!(errors, "Setting :n_mh_burn=$(n_burn) must be >= 0.")
        end
    end

    # Validate date settings
    presample_start = date_presample_start(m)
    mainsample_start = date_mainsample_start(m)
    if presample_start >= mainsample_start
        push!(errors, "date_presample_start ($(presample_start)) must be before date_mainsample_start ($(mainsample_start)).")
    end

    # Check forecast horizon
    if haskey(get_settings(m), :forecast_horizons)
        fh = get_setting(m, :forecast_horizons)
        if fh <= 0
            @warn "Setting :forecast_horizons=$(fh) is non-positive. This may cause issues in forecasting."
        end
    end

    # Check for potential numerical issues with optimization settings
    if haskey(get_settings(m), :optimization_iterations)
        n_iter = get_setting(m, :optimization_iterations)
        if n_iter <= 0
            @warn "Setting :optimization_iterations=$(n_iter) is non-positive. Optimization will not run."
        end
    end

    if !isempty(errors)
        msg = "Estimation settings validation failed with $(length(errors)) error(s):\n" *
              join(["  - " * e for e in errors], "\n")
        throw(DSGEEstimationError(msg))
    end

    return nothing
end
