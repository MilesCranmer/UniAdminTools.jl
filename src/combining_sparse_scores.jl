module MergeScore

using XLSX: XLSX
using DataFrames: AbstractDataFrame, DataFrame
using Measurements: ±
using CSV: CSV
using Comonicon: @main
using Turing: @model, sample, group, describe
using Turing: Uniform, Normal, Truncated, arraydist
using Turing: NUTS, SMC

"""
    mergescore --input INPUT
               [--sheet-name SHEET_NAME]
               [--scorer-range SCORER_RANGE]
               [--candidate-range CANDIDATE_RANGE]
               [--data-range DATA_RANGE]
               [--output "candidate_info.csv"]
               [--scorer-info "scorer_info.csv"]
               [--n-chains 6]
               [--n-samples 2000]
               [--n-adapts 500]
               [--sampler "NUTS()"]
               [--silent]

# Intro

Estimate true scores of candidates from sparse observations by committee members.

# Options

- `--input`: A csv or xlsx file with candidates and committee scores between 1 and 10, with
    unranked candidate-scorer pairs left blank.
- `--sheet-name`: If an `xlsx` file is passed, the name of the sheet to read from (such as `"Sheet 1"`).
- `--scorer-range`: If an `xlsx` file is passed, the range of cells containing the names of the scorers
    (such as `"A2:A10"`).
- `--candidate-range`: If an `xlsx` file is passed, the range of cells containing the names of the candidates
    (such as `"B1:J1"`).
- `--data-range`: If an `xlsx` file is passed, the range of cells containing the scores of the candidates
    (such as `"B2:J10"`).
- `--output`: The name of the (csv) file to write the estimated scores to.
- `--scorer-info`: The name of the file to write the estimated biases and scales of the scorers to.
- `--n-chains`: The number of chains to run.
- `--n-samples`: The number of samples to draw from each chain.
- `--n-adapts`: The number of samples to use for warming up.
- `--sampler`: The sampler to use. Can be `"NUTS()"` or `"SMC()"`.

# Flags

- `--silent`: Whether to suppress output.
"""
@main function mergescore(;
    input::String,
    sheet_name::Union{Nothing,String} = nothing,
    scorer_range::Union{Nothing,String} = nothing,
    candidate_range::Union{Nothing,String} = nothing,
    data_range::Union{Nothing,String} = nothing,
    output::String = "candidate_info.csv",
    scorer_info::String = "scorer_info.csv",
    n_chains::Int = 6,
    n_samples::Int = 2000,
    n_adapts::Int = 500,
    sampler::String = "NUTS()",
    silent::Bool = false,
)
    sampler = eval(Meta.parse(sampler))
    return estimated_merged_scores(
        input;
        sheet_name,
        scorer_range,
        candidate_range,
        data_range,
        output,
        scorer_info,
        n_chains,
        n_samples,
        n_adapts,
        sampler,
        verbose = !silent,
    )
end

function estimated_merged_scores(
    input::String;
    sheet_name::Union{Nothing,String} = nothing,
    scorer_range::Union{Nothing,String} = nothing,
    candidate_range::Union{Nothing,String} = nothing,
    data_range::Union{Nothing,String} = nothing,
    output::String = "candidate_info.csv",
    scorer_info::String = "scorer_info.csv",
    n_chains = 6,
    n_samples = 2000,
    n_adapts = 500,
    sampler = NUTS(),
    verbose = true,
)
    data = load_and_validate_data(
        input,
        sheet_name,
        scorer_range,
        candidate_range,
        data_range;
        verbose,
    )
    return _estimate_merged_scores(
        data;
        output,
        scorer_info,
        n_chains,
        n_samples,
        n_adapts,
        sampler,
        verbose,
    )
end

function load_and_validate_data(
    input,
    sheet_name,
    scorer_range,
    candidate_range,
    data_range;
    verbose = true,
)
    if endswith(input, ".xlsx")
        @assert !any(isnothing, (sheet_name, scorer_range, candidate_range, data_range)) "Must specify sheet_name, scorer_range, candidate_range, and data_range when reading from an xlsx file."
        verbose && @info "Assuming $input is an xlsx file, and using passed ranges."
        spreadsheet = XLSX.readxlsx(input)
        sheet = spreadsheet[sheet_name]
        scorers = reshape(string.(sheet[scorer_range]), :)
        candidates = reshape(string.(sheet[candidate_range]), :)
        data = float.(sheet[data_range])
        @assert size(data) == (length(candidates), length(scorers)) "Data range must be of size (length(candidates), length(scorers))."
        return DataFrame(
            "candidates" => candidates,
            [scorers[i] => data[:, i] for i in eachindex(scorers, data[1, :])]...,
        )
    else
        verbose &&
            @info "Assuming $input is a csv file with candidate names in the first column, and scorer names in the first row."
        for (s, value) in (
            (:sheet_name, sheet_name),
            (:scorer_range, scorer_range),
            (:candidate_range, candidate_range),
            (:data_range, data_range),
        )
            value === nothing && continue
            @warn "Ignoring passed argument for $(s) because $input is not an xlsx file."
        end
        return CSV.read(
            input,
            DataFrame;
            types = (i, _) -> i == 1 ? String : Union{Float64,Missing},
            strict = true,
        )
    end
end

function _estimate_merged_scores(
    raw_data::AbstractDataFrame;
    output,
    scorer_info,
    n_chains,
    n_samples,
    n_adapts,
    sampler,
    verbose,
)
    scorers = names(raw_data)[begin+1:end]
    n_scorers = length(scorers)
    verbose && @info "Found $(n_scorers) scorers:" scorers
    candidates = raw_data[!, 1]
    n_candidates = length(candidates)
    verbose && @info "Found $(n_candidates) candidates:" candidates
    obs_ij = Matrix{Union{Float64,Missing}}(raw_data[!, begin+1:end])
    verbose && @info "Loaded observations:" obs_ij

    model = forward_model(obs_ij)

    verbose && @info "Created forward model."
    verbose && @info "Loaded sampler:" sampler
    verbose && @info "Starting sampling."

    samples = sample(
        model,
        sampler,
        n_samples;
        n_adapts,
        nchains = n_chains,
        drop_warmup = true,
        verbose,
        progress = true,
        init_params = Dict(
            :sigma => 1.0,
            :true_s => [5.0 for _ = 1:size(obs_ij, 1)],
            :b => [1.0 for _ = 1:size(obs_ij, 2)],
            :mu => [0.0 for _ = 1:size(obs_ij, 2)],
        ),
    )

    verbose && @info "Finished sampling. Computing summaries..."

    sample_biases = group(samples, :mu)
    sample_scales = group(samples, :b)
    sample_scores = group(samples, :true_s)

    summary_bias = DataFrame(describe(sample_biases)[1])
    summary_scale = DataFrame(describe(sample_scales)[1])
    summary_scores = DataFrame(describe(sample_scores)[1])
    summary_scores_q = DataFrame(describe(sample_scores)[2])

    scorer_info_data = DataFrame((
        Name = string.(scorers),
        Bias = summary_bias.mean .± summary_bias.std,
        Scale = summary_scale.mean .± summary_scale.std,
    ))

    candidate_info_data = DataFrame((
        name = string.(candidates),
        score = (x -> round(x, digits = 3)).(summary_scores.mean),
        uncertainty = (x -> round(x, digits = 2)).(summary_scores.std),
        q25 = (x -> round(x, digits = 3)).(summary_scores_q[!, "25.0%"]),
        q75 = (x -> round(x, digits = 3)).(summary_scores_q[!, "75.0%"]),
    ))

    verbose && @info "Done!" candidate_info_data

    verbose && @info "Writing to $output with statistics about scorers to $scorer_info."

    CSV.write(output, candidate_info_data, writeheader = false)
    CSV.write(scorer_info, scorer_info_data, writeheader = false)

    return candidate_info_data
end

@model function forward_model(obs_ij)
    n_candidates, n_scorers = size(obs_ij)

    ### Priors ###
    # Measurement noise magnitude
    sigma ~ Uniform(0, 2)

    # Scales and biases
    b ~ arraydist([Normal(1.0, 0.3) for _ = 1:n_scorers])
    mu ~ arraydist([Normal(0, 1) for _ = 1:n_scorers])

    # True scores to infer
    true_s ~ arraydist([Uniform(1, 10) for i = 1:n_candidates])

    ### Noise model ###
    # (to generate the observations)
    for i = 1:n_candidates, j = 1:n_scorers
        if ismissing(obs_ij[i, j])
            continue # (sparse observations)
        end
        obs_ij[i, j] ~ Normal(b[j] * (true_s[i] + mu[j]), sigma)
    end
end


end
