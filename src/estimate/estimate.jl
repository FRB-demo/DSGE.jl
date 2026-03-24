"""
```
estimate(m, data; verbose=:low, proposal_covariance=Matrix()) -> nothing
```

Estimate the DSGE model's parameter posterior distribution using Bayesian methods.

This function performs the full estimation pipeline:
1. **Posterior mode finding**: Optimizes the posterior using `csminwel` (a quasi-Newton method).
2. **Hessian computation**: Computes the numerical Hessian at the mode for the proposal distribution.
3. **Posterior sampling**: Draws from the posterior via Metropolis-Hastings (MH) or
   Sequential Monte Carlo (SMC), as specified by the `:sampling_method` setting.
4. **Parameter covariance**: Computes and saves the parameter covariance from the draws.

### Arguments

- `m::Union{AbstractDSGEModel, AbstractVARModel}`: model object with parameters, priors, and settings.

### Optional Arguments

- `data`: well-formed data as `Matrix` or `DataFrame`. If not provided, `load_data` is called automatically.

### Keyword Arguments

- `verbose::Symbol = :low`: progress message frequency (`:none`, `:low`, or `:high`).
- `proposal_covariance::Matrix = []`: precomputed proposal covariance matrix (bypasses Hessian computation).
- `mle::Bool = false`: if `true`, estimate by maximum likelihood and return after optimization.
- `sampling::Bool = true`: if `false`, skip posterior sampling (only find the mode).
- `old_data::Matrix{Float64} = []`: previous data for bridge/time-tempered SMC estimation.
- `old_cloud::Union{ParticleCloud, Cloud, SMC.Cloud}`: previous particle cloud for bridge estimation.
- `old_model::Union{AbstractDSGEModel, AbstractVARModel} = m`: model for the old likelihood in bridge estimation.
- `filestring_addl::Vector{String} = []`: additional strings appended to output filenames.
- `continue_intermediate::Bool = false`: resume SMC from a previously saved intermediate stage.
- `intermediate_stage_start::Int = 0`: stage number to resume from.
- `save_intermediate::Bool = true`: save intermediate SMC stages to disk.
- `intermediate_stage_increment::Int = 10`: number of stages between saves.
- `run_csminwel::Bool = true`: run csminwel after SMC to find the true posterior mode.
- `toggle::Bool = true`: toggle regime-switching parameters to regime 1 during likelihood evaluation.
- `log_prob_old_data::Float64 = 0.0`: log marginal data density of old data for bridge estimation.

### Returns

`nothing`. Estimation output (parameter draws, mode, Hessian) is saved to files
in the `workpath(m, "estimate")` directory.

### Estimation Settings

Key settings (configured via `m <= Setting(:key, value)`):

- `:sampling_method`: `:MH` or `:SMC`
- `:n_mh_simulations`: number of MH draws per block
- `:n_mh_blocks`: number of MH blocks
- `:reoptimize`: whether to re-find the posterior mode
- `:calculate_hessian`: whether to recompute the Hessian

See `src/defaults.jl` and the 'Advanced Usage' documentation for the full list.

### Example

```julia
using DSGE
m = AnSchorfheide()
m <= Setting(:sampling_method, :MH)
m <= Setting(:n_mh_simulations, 1000)
df = load_data(m; check_empty_columns=false)
estimate(m, df)
```
"""
function estimate(m::Union{AbstractDSGEModel,AbstractVARModel}, df::DataFrame;
                  verbose::Symbol = :low,
                  proposal_covariance::Matrix = Matrix(undef, 0, 0),
                  mle::Bool = false,
                  sampling::Bool = true,
                  filestring_addl::Vector{String} = Vector{String}(),
                  old_data::Matrix{Float64} = Matrix{Float64}(undef, size(data, 1), 0),
                  old_cloud::Union{DSGE.ParticleCloud, DSGE.Cloud,
                                   SMC.Cloud} = DSGE.ParticleCloud(m, 0),
                  old_model::Union{AbstractDSGEModel, AbstractVARModel} = m,
                  continue_intermediate::Bool = false,
                  intermediate_stage_start::Int = 0,
                  intermediate_stage_increment::Int = 10,
                  save_intermediate::Bool = false,
                  run_csminwel::Bool = true,
                  toggle::Bool = true,
                  log_prob_old_data::Float64 = 0.0,
                  add_zlb_duration::Tuple{Bool, Int} = (false, 1))
    data = df_to_matrix(m, df)
    estimate(m, data; verbose = verbose, proposal_covariance = proposal_covariance,
             mle = mle, sampling = sampling,
             old_data = old_data, old_cloud = old_cloud,
             old_model = old_model,
             continue_intermediate = continue_intermediate,
             intermediate_stage_increment = intermediate_stage_increment,
             save_intermediate = save_intermediate,
             run_csminwel = run_csminwel, toggle = toggle, log_prob_old_data = log_prob_old_data,
             add_zlb_duration = add_zlb_duration)
end

function estimate(m::Union{AbstractDSGEModel,AbstractVARModel};
                  verbose::Symbol = :low,
                  proposal_covariance::Matrix = Matrix(undef, 0, 0),
                  mle::Bool = false,
                  sampling::Bool = true,
                  filestring_addl::Vector{String} = Vector{String}(),
                  old_data::Matrix{Float64} = Matrix{Float64}(undef, size(data, 1), 0),
                  old_cloud::Union{DSGE.ParticleCloud, DSGE.Cloud,
                                   SMC.Cloud} = DSGE.ParticleCloud(m, 0),
                  old_model::Union{AbstractDSGEModel, AbstractVARModel} = m,
                  continue_intermediate::Bool = false,
                  intermediate_stage_start::Int = 0,
                  intermediate_stage_increment::Int = 10,
		          save_intermediate::Bool = false,
                  run_csminwel::Bool = true,
                  toggle::Bool = true, log_prob_old_data::Float64 = 0.0,
                  add_zlb_duration::Tuple{Bool, Int} = (false, 1))
    # Load data
    df = load_data(m; verbose = verbose)
    estimate(m, df; verbose = verbose, proposal_covariance = proposal_covariance,
             mle = mle, sampling = sampling,
             old_data = old_data, old_cloud = old_cloud,
             old_model = old_model,
             continue_intermediate = continue_intermediate,
             intermediate_stage_increment = intermediate_stage_increment,
	         save_intermediate = save_intermediate,
             run_csminwel = run_csminwel, toggle = toggle, log_prob_old_data = log_prob_old_data,
             add_zlb_duration = add_zlb_duration)
end

function estimate(m::Union{AbstractDSGEModel,AbstractVARModel}, data::AbstractArray;
                  verbose::Symbol = :low,
                  proposal_covariance::Matrix = Matrix(undef, 0,0),
                  mle::Bool = false,
                  sampling::Bool = true,
                  filestring_addl::Vector{String} = Vector{String}(),
                  old_data::Matrix{Float64} = Matrix{Float64}(undef, size(data, 1), 0),
                  old_cloud::Union{DSGE.ParticleCloud, DSGE.Cloud,
                                   SMC.Cloud} = DSGE.ParticleCloud(m, 0),
                  old_model::Union{AbstractDSGEModel, AbstractVARModel} = m,
                  continue_intermediate::Bool = false,
                  intermediate_stage_start::Int = 0,
                  intermediate_stage_increment::Int = 10,
		          save_intermediate::Bool = false,
                  run_csminwel::Bool = true,
                  toggle::Bool = true, log_prob_old_data::Float64 = 0.0,
                  add_zlb_duration::Tuple{Bool, Int} = (false, 1))

    if !(get_setting(m, :sampling_method) in [:SMC, :MH])
        error("method must be :SMC or :MH")
    else
        method = get_setting(m, :sampling_method)
    end

    regime_switching = haskey(get_settings(m), :regime_switching) &&
        get_setting(m, :regime_switching)

    ########################################################################################
    ### Step 1: Find posterior/likelihood mode (if reoptimizing, run optimization routine)
    ########################################################################################

    # Specify starting mode

    vint = get_setting(m, :data_vintage)
    if reoptimize(m) && method == :MH
        println("Reoptimizing...")

        # Inputs to optimization algorithm
        n_iterations       = get_setting(m, :optimization_iterations)
        ftol               = get_setting(m, :optimization_ftol)
        xtol               = get_setting(m, :optimization_xtol)
        gtol               = get_setting(m, :optimization_gtol)
        step_size          = get_setting(m, :optimization_step_size)
        converged          = false

        # If the algorithm stops only because we have exceeded the maximum number of
        # iterations, continue improving guess of modal parameters
        total_iterations = 0
        optimization_time = 0
        max_attempts = get_setting(m, :optimization_attempts)
        attempts = 1

        while !converged
            begin_time = time_ns()
            out, H = optimize!(m, data;
                               method = get_setting(m, :optimization_method),
                               ftol = ftol, grtol = gtol, xtol = xtol,
                               iterations = n_iterations, show_trace = true, step_size = step_size,
                               mle = mle, toggle = toggle, verbose = verbose)


            attempts += 1
            total_iterations += out.iterations
            converged = out.converged || attempts > max_attempts

            end_time = (time_ns() - begin_time)/1e9
            println(verbose, :low, @sprintf "Total iterations completed: %d\n" total_iterations)
            println(verbose, :low, @sprintf "Optimization time elapsed: %5.2f\n" optimization_time += end_time)

            # Write params to file after every `n_iterations` iterations
            params = ModelConstructors.get_values(get_parameters(m); regime_switching = regime_switching)
            h5open(rawpath(m, "estimate", "paramsmode.h5"),"w") do file
                file["params"] = params
            end
        end

        # write parameters to file one last time so we have the final mode
        h5open(rawpath(m, "estimate", "paramsmode.h5"),"w") do file
            file["params"] = params
        end
    end

    params = ModelConstructors.get_values(get_parameters(m); regime_switching = regime_switching)

    # Sampling does not make sense if mle=true
    if mle || !sampling
        return nothing
    end

    if get_setting(m,:sampling_method) == :MH
        ########################################################################################
        ### Step 2: Compute proposal distribution for Markov Chain Monte Carlo (MCMC)
        ###
        ### In Metropolis-Hastings, we draw sample parameter vectors from
        ### the proposal distribution, which is a degenerate multivariate
        ### normal centered at the mode. Its variance is the inverse of
        ### the hessian. We find the inverse via eigenvalue decomposition.
        ########################################################################################

        ## Calculate the Hessian at the posterior mode
        hessian = if calculate_hessian(m)
            println(verbose, :low, "Recalculating Hessian...")

            hessian, _ = hessian!(m, params, data; toggle = toggle, verbose = verbose)

            h5open(rawpath(m, "estimate","hessian.h5"),"w") do file
                file["hessian"] = hessian
            end

            hessian

        ## Read in a pre-calculated Hessian
        else
            fn = hessian_path(m)
            println(verbose, :low, "Using pre-calculated Hessian from $fn")

            hessian = h5open(fn,"r") do file
                read(file, "hessian")
            end

            hessian
	    end

        # Compute inverse hessian and create proposal distribution, or
        # just create it with the given cov matrix if we have it
        propdist = if isempty(proposal_covariance)
            # Make sure the mode and hessian have the same number of parameters
            n = length(params)
            @assert (n, n) == size(hessian)

            # Compute the inverse of the Hessian via eigenvalue decomposition
            #S_diag, U = eigen(hessian)
            F = svd(hessian)

            big_eig_vals = findall(x -> x > 1e-6, F.S)
            hessian_rank = length(big_eig_vals)

            S_inv = zeros(n, n)
            #for i = (n-hessian_rank+1):n
            for i = 1:hessian_rank
                S_inv[i, i] = 1/F.S[i]
            end

            #hessian_inv = U*sqrt.(S_inv) # this is the inverse of the hessian
            hessian_inv = F.V * S_inv * F.U'#sqrt.(S_inv) * F.U'

            DegenerateMvNormal(params, hessian_inv; stdev = false)
        else
#            DegenerateMvNormal(params, proposal_covariance, pinv(proposal_covariance),
#                              eigen(proposal_covariance).values)
            DegenerateMvNormal(params, proposal_covariance; stdev = false)
        end

        if rank(propdist) != n_parameters_free(m)
            println("problem –    shutting down dimensions")
        end

        ########################################################################################
        ### Step 3: Sample from posterior using Metropolis-Hastings algorithm
        ########################################################################################

        # Set the jump size for sampling
        cc0 = get_setting(m, :mh_cc0)
        cc  = get_setting(m, :mh_cc)

        metropolis_hastings(propdist, m, data, cc0, cc; regime_switching = regime_switching,
                            toggle = toggle, verbose = verbose, filestring_addl = filestring_addl);

    elseif get_setting(m, :sampling_method) == :SMC
        ########################################################################################
        ### Step 3: Run Sequential Monte Carlo (SMC)
        ###
        ### In Sequential Monte Carlo, a large number of Markov Chains
        ### are simulated iteratively to create a particle approximation
        ### of the posterior. Portions of this method are executed in
        ### parallel.
        ########################################################################################
        smc2(m, data; verbose = verbose, filestring_addl = filestring_addl,
             old_data = old_data, old_cloud = old_cloud,
             old_model = old_model,
             continue_intermediate = continue_intermediate,
             intermediate_stage_start = intermediate_stage_start,
             save_intermediate = save_intermediate,
             intermediate_stage_increment = intermediate_stage_increment,
             run_csminwel = run_csminwel,
             regime_switching = regime_switching, log_prob_old_data = log_prob_old_data,
             add_zlb_duration = add_zlb_duration)
    end

    ########################################################################################
    ### Step 4: Calculate and save parameter covariance matrix
    ########################################################################################

    compute_parameter_covariance(m, filestring_addl = filestring_addl)

    return nothing
end

"""
```
compute_parameter_covariance(m::Union{AbstractDSGEModel,AbstractVARModel})
```

Calculates the parameter covariance matrix from saved parameter draws, and writes it to the
parameter_covariance.h5 file in the `workpath(m, "estimate")` directory.

### Arguments
* `m::Union{AbstractDSGEModel,AbstractVARModel}`: the model object
- `filestring_addl::Vector{String} = []`: Additional strings to add to the file name
    of estimation output as a way to distinguish output from each other.
"""
function compute_parameter_covariance(m::Union{AbstractDSGEModel,AbstractVARModel};
                                      filestring_addl::Vector{String} = Vector{String}(undef, 0))

    sampling_method = get_setting(m, :sampling_method)
    if sampling_method ∉ [:MH, :SMC]
        throw("Invalid sampling method specified in setting :sampling_method")
    end

    prefix           = sampling_method == :MH ? "mh" : "smc"
    param_draws_path = rawpath(m, "estimate", prefix * "save.h5", filestring_addl)
    savepath         = workpath(m, "estimate", "parameter_covariance.h5", filestring_addl)

    return compute_parameter_covariance(param_draws_path, sampling_method; savepath = savepath)
end

"""
```
compute_parameter_covariance(param_draws_path::String, sampling_method::Symbol;
                             savepath = "parameter_covariance.h5")
```

Generic function calculates the parameter covariance matrix from saved parameter draws,
writes it to the specified savepath.

### Arguments
* `param_draws_path::String`: Path to file where parameter draws are stored.
* `sampling_method::Symbol`: Sampling method used for estimation.
```
   - `:MH`: Metropolis-Hastings
   - `:SMC`: Sequential Monte Carlo
```
### Optional Arguments
* `savepath::String`: Where parameter covariance matrix is to be saved. Will default
    to "parameter_covariance.h5" if unspecified.
"""
function compute_parameter_covariance(param_draws_path::String, sampling_method::Symbol;
                                      savepath::String = "parameter_covariance.h5")
    if sampling_method ∉ [:MH, :SMC]
        throw("Invalid sampling method specified in setting :sampling_method")
    end
    prefix = sampling_method == :MH ? "mh" : "smc"

    if !isfile(param_draws_path)
        @printf stderr "Saved parameter draws not found.\n"
        return
    end

    param_draws = h5open(param_draws_path, "r") do f
        read(f, prefix * "params")
    end

    # Calculate covariance matrix
    param_covariance = cov(param_draws)

    # Write to file
    h5open(savepath, "w") do f
        f[prefix * "cov"] = param_covariance
    end
end

"""
```
get_estimation_output_files(m)
```

Returns a `Dict{Symbol, String}` with all files created by `estimate(m)`.
"""
function get_estimation_output_files(m::Union{AbstractDSGEModel,AbstractVARModel})
    output_files = Dict{Symbol, String}()

    for file in [:paramsmode, :hessian, :mhsave]
        output_files[file] = rawpath(m, "estimate", "$file.h5")
    end

    for file in [:paramsmean, :parameter_covariance]
        output_files[file] = workpath(m, "estimate", "$file.h5")
    end

    for file in [:priors, :prior_posterior_means, :moments]
        output_files[file] = tablespath(m, "estimate", "$file.tex")
    end

    return output_files
end
