# UniAdminTools

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://MilesCranmer.github.io/UniAdminTools.jl/dev/)
[![Build Status](https://github.com/MilesCranmer/UniAdminTools.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/MilesCranmer/UniAdminTools.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![Coverage](https://coveralls.io/repos/github/MilesCranmer/UniAdminTools.jl/badge.svg?branch=master)](https://coveralls.io/github/MilesCranmer/UniAdminTools.jl?branch=master)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

Robust optimisation tool for academic administrative duties:

- Allocating projects among students (`projalloc`)
  - Incorporates ranked preferences and per-project saturation constraints
  - Based on mixed-integer programming, using JuMP with Ipopt + HiGHS + Juniper
- Robust aggregation of committee scores for job candidates (`mergescore`)
  - Accounts for sparsity, noise, uncertainty, and different scoring scales among committee members
  - Bayesian inference scheme using TuringLang and NUTS


## Installation

First, you need to install Julia:

```bash
curl -fsSL https://install.julialang.org | sh
```

Which will install it interactively. For Windows machines, you can use `winget install julia -s msstore`.

Then, install this package and all dependencies with:

```bash
julia -e 'using Pkg; pkg"add https://github.com/MilesCranmer/UniAdminTools.jl"'
```

which should create some binaries in your `~/.julia/bin` folder that can be executed:

```bash
projalloc --help
```

See the docs for more details, including other
functions: [astroautomata.com/UniAdminTools.jl/dev](https://astroautomata.com/UniAdminTools.jl/dev/)
