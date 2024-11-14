#import "@preview/physica:0.8.0": erf
#import "@preview/tablex:0.0.6": tablex, hlinex

#set par(justify: true)

// Number equations:
#set math.equation(numbering: "(1)")

#let prod = $product$

= Noise model for combined candidate scoring

Say that we wish to estimate a true score of a candidate in a competition, given noisy measurements from a random sample of reviewers who are not necessarily calibrated with each other.

Simply normalizing the the empirical variance and mean of reviewers is subject to significant biases, as some reviewers may by chance have stronger candidates in their pool.
This is especially important in the low-data regime.
The model presented below jointly estimates the true scores and the reviewer biases, which helps mitigate this issue.

== Model

Let us make the assumption that candidates, indexed by $i$, have a true score of $s_i in [1, 10]$.

Each reviewer, indexed by $j$, makes a noisy measurement $hat(s)_(i, j)$ for candidates according to some the assignment matrix $a_(i,j) = 1$ (and no measurement for $a_(i,j)=0$).
Assume that this observation is described by a model with Gaussian noise:
$ 
epsilon tilde cal(N)(0, sigma^2) \
hat(s)_(i, j) = b_j (s_i + mu_j) + epsilon 
$
for a global value of $sigma$, and a per-reviewer $mu_j, b_j$ parameter (a bias and scale term, respectively).

We are interested in the task of estimating $s_i$ for all candidates, *simultaneously* (important as this mitigates the problems discussed above!), via the likelihood
$ Pr({s_i}_(i) | {hat(s)_(i, j)}_(i,j | a_(i,j) = 1)) $
to do so, we wish to marginalize over the nuisance parameters $mu_j, b_j$ and $sigma$.
$
& Pr({s_i}_(i) | {hat(s)_(i, j)}_(i,j| a_(i,j) = 1))
\
&= 
product_(i)
Pr(s_i | {hat(s)_(i, j)}_(a_(i,j) = 1))
&& arrow.l "(independent candidates)"
\
&= 
integral_sigma Pr(sigma)
product_(i)
Pr(s_i | {hat(s)_(i, j)}_(a_(i,j) = 1), sigma)
&& arrow.l "(introduce global " sigma ")"
\
&prop
integral_sigma Pr(sigma)
product_(i)
Pr({hat(s)_(i, j)}_(a_(i,j) = 1) | s_i, sigma) Pr(s_i)
&& arrow.l "(Bayes)"
\
&=
integral_sigma Pr(sigma)
product_(i)
Pr(s_i)
(product_(j\ a_(i, j)=1) Pr(hat(s)_(i, j) | s_i, sigma))
$
we can expand this assuming our Gaussian noise model:
$ 
&=
integral_sigma Pr(sigma)
product_(i)
Pr(s_i)
(
  product_(j\ a_(i, j)=1)
  integral.double_(mu_j,b_j) Pr(mu_j) Pr(b_j)
    Pr(hat(s)_(i, j) | s_i, sigma, mu_j, b_j)
)
$

== MCMC

We will now run MCMC on this.
We will set up this model in the probabilistic programming language Turing.jl.
Our default priors are:

$
"global scatter:" & sigma tilde cal(U)(0, 2) \
"reviewer scale:" & b_j tilde cal(N)(1.0, 0.3) \
"reviewer bias:" & mu_j tilde cal(N)(0, 1) \
"true candidate score:" & s_i tilde cal(U)(1, 10) \
$
for each $j$ and $i$.
And our forward model is:

$
hat(s)_(i, j) tilde cal(N)(b_j (s_i + mu_j), sigma), "for all" i, j
"where" a_(i, j) = 1
$

In code form (with Julia and Turing.jl), this looks like:

```julia
using Turing: @model, Normal, Uniform, arraydist

@model function forward_model(obs_ij)
    (n_candidates, n_scorers) = size(obs_ij)

    ### Priors ###
    # Measurement noise magnitude
    sigma ~ Uniform(0, 2)

    # Scales and biases
    b  ~ arraydist([Normal(1.0, 0.3) for j in 1:n_scorers])
    mu ~ arraydist([Normal(0.0, 1.0) for j in 1:n_scorers])

    # True scores to infer
    true_s ~ arraydist([Uniform(1.0, 10.0) for i in 1:n_candidates])

    ### Noise model ###
    # (to generate the observations)
    for i in 1:n_candidates
        for j in 1:n_scorers
            if ismissing(obs_ij[i, j])
                continue # (sparse observations)
            end
            obs_ij[i, j] ~ Normal(b[j] * (true_s[i] + mu[j]), sigma)
        end
    end
end
```
where `obs_ij` is a matrix of scores, with `ismissing(obs_ij[i, j])` indicating that the reviewer did not score the candidate (which gets automatically folded into the likelihood by Turing.jl).

By default, we sample this with the NUTS sampler, with 6 chains, 500 warm-up steps, and 2,000 samples per chain.
Convergence diagnostics are performed automatically.

This model is implemented in #link("https://github.com/MilesCranmer/UniAdminTools.jl/blob/master/src/mergescore.jl")[`src/mergescore.jl`].
