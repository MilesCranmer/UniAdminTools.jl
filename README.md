# UniAdminTools

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://MilesCranmer.github.io/UniAdminTools.jl/dev/)
[![Build Status](https://github.com/MilesCranmer/UniAdminTools.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/MilesCranmer/UniAdminTools.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://coveralls.io/repos/github/MilesCranmer/UniAdminTools.jl/badge.svg?branch=main)](https://coveralls.io/github/MilesCranmer/UniAdminTools.jl?branch=main)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

Robust optimisation for various academic administrative duties

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
