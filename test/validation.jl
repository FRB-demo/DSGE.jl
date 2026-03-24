using DSGE, ModelConstructors, Test, DataFrames, Dates

@testset "Validation" begin

    @testset "Custom exception types" begin
        @test DSGEParameterError <: Exception
        @test DSGEDataError <: Exception
        @test DSGEEstimationError <: Exception

        ex = DSGEParameterError("test message")
        @test ex.msg == "test message"
        buf = IOBuffer()
        Base.showerror(buf, ex)
        @test occursin("DSGEParameterError", String(take!(buf)))

        ex = DSGEDataError("data issue")
        @test ex.msg == "data issue"
        buf = IOBuffer()
        Base.showerror(buf, ex)
        @test occursin("DSGEDataError", String(take!(buf)))

        ex = DSGEEstimationError("estimation issue")
        @test ex.msg == "estimation issue"
        buf = IOBuffer()
        Base.showerror(buf, ex)
        @test occursin("DSGEEstimationError", String(take!(buf)))
    end

    @testset "validate_parameters" begin
        m = AnSchorfheide(testing = true)

        # A valid model should pass validation silently
        @test validate_parameters(m) === nothing

        # Test that out-of-bounds parameter produces correct error
        # Save original value, set an invalid one, then restore
        orig_val = m[:τ].value
        orig_bounds = m[:τ].valuebounds
        # τ has bounds (1e-20, 1e5); set it to a negative value
        m[:τ].value = -1.0
        @test_throws DSGEParameterError validate_parameters(m)
        try
            validate_parameters(m)
        catch ex
            @test isa(ex, DSGEParameterError)
            @test occursin("τ", ex.msg)
            @test occursin("-1.0", ex.msg)
            @test occursin("out of valid range", ex.msg)
        end
        # Restore original value
        m[:τ].value = orig_val

        # Test parameter exactly at lower bound (should pass)
        m[:τ].value = orig_bounds[1]
        @test validate_parameters(m) === nothing
        m[:τ].value = orig_val

        # Test parameter exactly at upper bound (should pass)
        m[:τ].value = orig_bounds[2]
        @test validate_parameters(m) === nothing
        m[:τ].value = orig_val

        # Test multiple parameters out of bounds
        m[:τ].value = -1.0
        m[:ψ_1].value = -1.0
        @test_throws DSGEParameterError validate_parameters(m)
        try
            validate_parameters(m)
        catch ex
            @test occursin("2 error(s)", ex.msg)
            @test occursin("τ", ex.msg)
            @test occursin("ψ_1", ex.msg)
        end
        m[:τ].value = orig_val
        m[:ψ_1].value = 1.1434  # restore original
    end

    @testset "validate_data" begin
        m = AnSchorfheide(testing = true)
        n_obs = n_observables(m)

        # Create a valid DataFrame with date column and enough observable columns
        n_periods = 20
        dates = [Dates.lastdayofquarter(Date(2000, 3, 31) + Dates.Month(3 * i)) for i in 0:(n_periods-1)]
        df = DataFrame(:date => dates)
        obs_keys = collect(keys(m.observables))
        for k in obs_keys
            df[!, k] = randn(n_periods)
        end

        # Valid data should pass
        @test validate_data(m, df) === nothing

        # Test mismatched data dimensions (too few columns)
        df_few = DataFrame(:date => dates)
        df_few[!, :obs_only_one] = randn(n_periods)
        if n_obs > 1
            @test_throws DSGEDataError validate_data(m, df_few)
            try
                validate_data(m, df_few)
            catch ex
                @test isa(ex, DSGEDataError)
                @test occursin("observable column(s)", ex.msg)
                @test occursin("model expects", ex.msg)
            end
        end

        # Test entirely NaN column
        df_nan = copy(df)
        df_nan[!, obs_keys[1]] .= NaN
        @test_throws DSGEDataError validate_data(m, df_nan)
        try
            validate_data(m, df_nan)
        catch ex
            @test isa(ex, DSGEDataError)
            @test occursin("entirely NaN or missing", ex.msg)
        end

        # Test entirely missing column
        df_missing = copy(df)
        df_missing[!, obs_keys[1]] = Vector{Union{Missing, Float64}}(missing, n_periods)
        @test_throws DSGEDataError validate_data(m, df_missing)

        # Test partial NaN values (should warn but not error)
        df_partial = copy(df)
        df_partial[1, obs_keys[1]] = NaN
        @test_logs (:warn, r"some NaN or missing") validate_data(m, df_partial)
    end

    @testset "validate_estimation_settings" begin
        m = AnSchorfheide(testing = true)

        # Valid model should pass
        @test validate_estimation_settings(m) === nothing

        # Test invalid n_mh_simulations
        orig_n_sim = get_setting(m, :n_mh_simulations)
        m <= Setting(:n_mh_simulations, 0)
        @test_throws DSGEEstimationError validate_estimation_settings(m)
        try
            validate_estimation_settings(m)
        catch ex
            @test isa(ex, DSGEEstimationError)
            @test occursin("n_mh_simulations", ex.msg)
        end
        m <= Setting(:n_mh_simulations, orig_n_sim)

        # Test n_mh_burn >= n_mh_simulations
        orig_n_burn = get_setting(m, :n_mh_burn)
        m <= Setting(:n_mh_burn, get_setting(m, :n_mh_simulations) + 1)
        @test_throws DSGEEstimationError validate_estimation_settings(m)
        try
            validate_estimation_settings(m)
        catch ex
            @test isa(ex, DSGEEstimationError)
            @test occursin("n_mh_burn", ex.msg)
        end
        m <= Setting(:n_mh_burn, orig_n_burn)

        # Test invalid sampling method
        m <= Setting(:sampling_method, :InvalidMethod)
        @test_throws DSGEEstimationError validate_estimation_settings(m)
        try
            validate_estimation_settings(m)
        catch ex
            @test isa(ex, DSGEEstimationError)
            @test occursin("sampling_method", ex.msg)
        end
        m <= Setting(:sampling_method, :MH)
    end

end
