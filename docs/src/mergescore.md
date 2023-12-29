# Noise model for combined candidate scoring

Let's say we want to estimate a "true score" for a
candidate in a competition, given noisy measurements from a random
sample of reviewers who are not necessarily calibrated with each other.
This is especially important in the low-data regime, so probably
requires a Bayesian approach.

Let us make the assumption that candidates, indexed by $i$, have a true
score of $s_{i} \in \lbrack 1,10\rbrack$.

Each reviewer, indexed by $j$, makes a noisy measurement
${\hat{s}}_{i,j}$ for candidates according to some the assignment matrix
$a_{i,j} = 1$ (and no measurement for $a_{i,j} = 0$)

Let us assume that this observation is described by a model with
Gaussian noise:

$$\begin{array}{r}
\varepsilon \sim \mathcal{N}(0,\sigma^{2}) \\
{\hat{s}}_{i,j} = b_{j}\left( s_{i} + \mu_{j} \right) + \varepsilon
\end{array}$$

for a global value of $\sigma$, and a per-reviewer
$\mu_{j},b_{j}$ parameter (a bias and scale term, respectively).

We are interested in the task of estimating $s_{i}$ for all candidates,
simultaneously, via the likelihood
$$\Pr(\left\{ s_{i} \right\}_{i}~|~\left\{ {\hat{s}}_{i,j} \right\}_{i,j~|~a_{i,j} = 1})$$
to do so, we wish to marginalize over the nuisance parameters
$\mu_{j},b_{j}$ and $\sigma$.

$$\begin{aligned}
 & \Pr(\left\{ s_{i} \right\}_{i}~|~\left\{ {\hat{s}}_{i,j} \right\}_{i,j|a_{i,j} = 1}) \\
 & = \prod_{i}\Pr(s_{i}~|~\left\{ {\hat{s}}_{i,j} \right\}_{a_{i,j} = 1}) \\
 & = \int_{\sigma}\Pr(\sigma)\prod_{i}\Pr(s_{i}~|~\left\{ {\hat{s}}_{i,j} \right\}_{a_{i,j} = 1},\sigma) \\
 & \propto \int_{\sigma}\Pr(\sigma)\prod_{i}\Pr(\left\{ {\hat{s}}_{i,j} \right\}_{a_{i,j} = 1}~|~s_{i},\sigma)\Pr(s_{i}) \\
 & = \int_{\sigma}\Pr(\sigma)\prod_{i}\Pr(s_{i})\left( \prod_{\begin{array}{r}
j \\
a_{i,j} = 1
\end{array}}\Pr({\hat{s}}_{i,j}~|~s_{i},\sigma) \right)
\end{aligned}$$

However, I tried computing this analytically and doing a simple
approximation, but it doesn't seem like there's any good closed-form
representation in the end suitable for an excel formula. So we need to
turn to numerical methods (see next page):

## MCMC Description

We will instead run MCMC on this. We will set up this model in the
probabilistic programming language Turing.jl. In summary, our priors
are:

$$\sigma \sim \mathcal{U}(0,2) \\
b_{j} \sim \mathcal{N}(1.0,0.3) \\
\mu_{j} \sim \mathcal{N}(0,1) \\
s_{i} \sim \mathcal{U}(1,10)$$

for each $j$ and $i$. And our forward model is:

$${\hat{s}}_{i,j} \sim \mathcal{N}(b_{j}\left( s_{i} + \mu_{j} \right),\sigma),\text{ for all }i,j\text{ where }a_{i,j} = 1$$

In code form, this looks like:

``` julia
using Turing: @model, Normal, Uniform, arraydist

@model function predict_scorings(s_ij)
    # Priors
    n_candidates = size(s_ij, 1)
    n_scorers = size(s_ij, 2)
    σ ~ Uniform(0, 2)
    b ~ arraydist([Normal(1.0, 0.3) for _ in 1:n_scorers])
    mu ~ arraydist([Normal(0, 1) for _ in 1:n_scorers])
    s ~ arraydist([Uniform(1, 10) for i in 1:n_candidates])
  
    # Model
    for i in 1:n_candidates, j in 1:n_scorers
        ismissing(s_ij[i, j]) && continue
        s_ij[i, j] ~ Normal(b[j] * (s[i] + mu[j]), σ)
    end
end
```

This is the exact same forward model we have described above.
