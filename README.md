# UniAdminTools

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://MilesCranmer.github.io/UniAdminTools.jl/dev/)
[![Build Status](https://github.com/MilesCranmer/UniAdminTools.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/MilesCranmer/UniAdminTools.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![Coverage](https://coveralls.io/repos/github/MilesCranmer/UniAdminTools.jl/badge.svg?branch=master)](https://coveralls.io/github/MilesCranmer/UniAdminTools.jl?branch=master)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

Optimisation tools for academic administrative duties:

- Aggregation of sparse committee scores for job candidates with [`mergescore`](#mergescore)
  - Accounts for sparsity, noise, uncertainty, and different scoring scales among committee members
  - Bayesian inference scheme using TuringLang and NUTS
- Allocating projects among students with [`projalloc`](#projalloc)
  - Incorporates ranked preferences and per-project saturation constraints
  - Based on mixed-integer programming, using JuMP with Ipopt + HiGHS + Juniper


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

This should create some binaries in your `~/.julia/bin` folder that can be executed.

## Usage

Usage for the CLI interface is provided below. You can also find this 
on [astroautomata.com/UniAdminTools.jl/dev](https://astroautomata.com/UniAdminTools.jl/dev/).

### `mergescore`

```
    mergescore input
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
```

Estimate true scores of candidates from sparse observations by committee members.

#### Args

- `input`: A csv or xlsx file with candidates and committee scores between 1 and 10, with
    unranked candidate-scorer pairs left blank.

#### Options

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
- `--sampler`: The sampler to use. Can be, for example, `"NUTS()"` or `"SMC()"`.
- `--lower-true-score`: The lower bound of the uniform prior on the true scores.
- `--upper-true-score`: The upper bound of the uniform prior on the true scores.
- `--mean-bias`: The mean of the normal prior on the bias of the scorers.
- `--stdev-bias`: The standard deviation of the normal prior on the bias of the scorers.
- `--mean-scale`: The mean of the normal prior on the scale of the scorers.
- `--stdev-scale`: The standard deviation of the normal prior on the scale of the scorers.

#### Flags

- `--silent`: Whether to suppress output.

#### Example

Say we put all the data into a file `data.csv`:

```csv
candidates,Scorer AA,BB,DD,FF,HH,LL,MM,avg,spread
Candidate 1,,7.9,,8.5,8.2,8.4,,8,0.26
Candidate 2,4.2,7.4,3.7,,,,2.8,5,1.63
Candidate 3,,4.4,,5.2,5.7,,5.2,5,0.48
Candidate First name Last name,9.6,,7.6,,8,,,9,1.03
Candidate 5,,,,,,,,,
```

We can then create estimates for true scores with:

```bash
mergescore data.csv --n-chains 5 --n-samples 3000 --output my_output.csv
```

This will create a file `my_output.csv` with estimates for true
scores of each candidate.

### `projalloc`

    projalloc --choices CHOICES
              --projects PROJECTS
              [--output "project_allocations.csv"]
              [--overall_objective "happiness - 0.5 * load"]
              [--rank_to_happiness "10 - 2^(ranking - 1) + 1"]
              [--assignments_to_load "num_assigned^2"]
              [--optimizer_time_limit 5]
              [--max_students_per_project 4]
              [--max_students_per_teacher 12]
              [--silent]

Compute optimal project allocations for student projects, using two csv files.

#### Options

- `--choices`: A csv file with no header (data starting at the first row). The first column
   should be the student name, and the rest should be project choices (integer).
- `--projects`: A csv file with no header (data starting at the first row). The first column
   should be the teacher name, and the second column should be the project name.
- `--output <"project_allocations.csv"::String>`: The filename to save the output to.
- `--overall_objective <"happiness - 0.5 * load"::String>`: A function that takes the total happiness and the total
    load and returns a single number. This will be maximized.
- `--rank_to_happiness <"10 - 2^(ranking - 1) + 1"::String>`: Convert a student-assigned ranking into a `happiness`,
    which will be summed over students.
- `--assignments_to_load <"num_assigned^2"::String>`: A function that takes the number of students assigned
    to each project and returns a number. This will be summed over projects.
- `--optimizer_time_limit <5::Int>`: How long to spend optimizing the project allocations.
    Should usually find it pretty quickly (within 5 seconds), but you might try increasing
    this to see if it changes the results.
- `--max_students_per_project <4::Int>`: The maximum number of students that can be assigned to a project.
- `--max_students_per_teacher <12::Int>`: The maximum number of students that can be assigned to a teacher.

#### Flags

- `--silent`: Don't print out information about the optimization process.

#### Examples

Say that we create a file `choices.csv` with student preferences (first column is student name,
second column is first choice, third column is second choice, etc.):

```csv
"Student A",1,2,4
"Student B",1,3,4
"Student C",5,3,4
"Student D",6,1,2
```

and then another file `projects.csv` with project listings (first column is teacher name,
second column is project name):

```csv
"Teacher A","Project A1"
"Teacher A","Project A2"
"Teacher B","B 3"
"Teacher C","C4"
"Teacher D","D project 1"
"Teacher D","D project 2"
"Teacher D","D project 3"
```

**Note that the order of the projects here is used to set the index
of each project**. This is used for matching integers with the student preferences file.

Then we can run the following command:

```bash
projalloc --choices choices.csv --projects projects.csv \
          --output allocations.csv \
          --overall-objective "happiness - 0.5 * load"
```

which will create a csv file `allocations.csv` with
an optimal allocation of student projects.
