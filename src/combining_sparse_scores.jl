using XLSX: XLSX
using DataFrames: AbstractDataFrame, DataFrame
using Measurements: ±
using CSV: CSV
using Turing: @model, Uniform, Normal, Truncated, arraydist, sample, NUTS, SMC, group

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

function _estimate_merged_scores(
    raw_data::AbstractDataFrame;
    n_iterations=1000,
    n_chains=6,
    n_samples=2000,
    n_adapts=500,
    sampler=NUTS(),
    verbose=true,
)

    scorers = names(raw_data)[begin+1:end]
    candidates = raw_data[!, 1]
    obs_ij = Matrix{Union{Float64,Missing}}(raw_data[!, begin+1:end])

    model = forward_model(obs_ij)

    samples = sample(
        model,
        sampler,
        n_samples;
        n_adapts,
        nchains=n_chains,
        drop_warmup = true,
        verbose,
        progress=true,
        init_params=Dict(
            :sigma => 1.0,
            :true_s => [5.0 for _ = 1:size(obs_ij, 1)],
            :b => [1.0 for _ = 1:size(obs_ij, 2)],
            :mu => [0.0 for _ = 1:size(obs_ij, 2)],
        ),
    )

    sample_biases = group(samples, :mu)
    sample_scales = group(samples, :b)
    sample_scores = group(samples, :true_s)

    summary_bias = DataFrame(describe(sample_biases)[1])
    summary_scale = DataFrame(describe(sample_scales)[1])
    summary_scores = DataFrame(describe(sample_scores)[1])
    summary_scores_q = DataFrame(describe(sample_scores)[2])

    scorer_info = DataFrame((
        Name = string.(scorers),
        Bias = summary_bias.mean .± summary_bias.std,
        Scale = summary_scale.mean .± summary_scale.std,
    ))

    candidate_info = DataFrame((
        Name = string.(candidates),
        Score = (x -> round(x, digits = 3)).(summary_scores.mean),
        Uncertainty = (x -> round(x, digits = 2)).(summary_scores.std),
        Q_25 = (x -> round(x, digits = 3)).(summary_scores_q[!, "25.0%"]),
        Q_75 = (x -> round(x, digits = 3)).(summary_scores_q[!, "75.0%"]),
    ))

    CSV.write("scorer_info.csv", scorer_info, writeheader = false)
    CSV.write("candidate_info.csv", candidate_info, writeheader = false)
    return candidate_info
end
