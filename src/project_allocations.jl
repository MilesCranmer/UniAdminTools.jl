module ProjectAllocations

using JuMP  # Optimization language
using StatsBase: countmap  # For counting output
using CSV: CSV
using DataFrames: AbstractDataFrame, DataFrame
using Ipopt: Ipopt
using HiGHS: HiGHS
using Juniper: Juniper
using OrderedCollections: OrderedDict


"""
    optimize_project_allocations(data; kws...)

Find optimal project allocations using HiGHS, Ipopt, and Juniper.

- `choices`: A table or dataframe (or a filename) where each row is one student's project choices,
   with the first column being the student name, and the next columns being their choices
   (second column being their first choice).
- `projects`: A table or dataframe (or a filename) where each row is a project. The first
   column should be the project name, and the second column the teacher name. The row index
   of the project is its identifier in the `choices` table.
- `teachers`: A vector of teacher names, e.g. `["A", "B", "C", "D"]`.
- `overall_objective`: A function that takes the total happiness and the total
    load and returns a single number. The default is to maximize happiness minus
    0.5 times the load.
- `rank_to_happiness`: Convert a student-assigned ranking into a `happiness`.
- `assignments_to_load`: A function that takes the number of students assigned
    to each project and returns a number. The default is to return the square of
    the number of students.
- `optimizer_time_limit`: How long to spend optimizing the project allocations.
  Should usually find it pretty quickly (within 5 seconds), but you might try increasing
  this to see if it changes the results.
"""
function optimize_project_allocations(
    choices,
    projects;
    overall_objective = (happiness, load) -> happiness - 0.5 * load,
    rank_to_happiness = ranking -> 10 - 2^(ranking - 1) + 1,
    assignments_to_load = num_assigned -> num_assigned^2,
    optimizer_time_limit = 5,
    max_students_per_project = 4,
    max_students_per_teacher = 12,
)
    return _optimize_project_allocations(
        load_and_validate_data(choices, :choices),
        load_and_validate_data(projects, :projects);
        overall_objective,
        rank_to_happiness,
        assignments_to_load,
        optimizer_time_limit,
        max_students_per_project,
        max_students_per_teacher,
    )
end


function _optimize_project_allocations(
    choices_data::AbstractDataFrame,
    projects_data::AbstractDataFrame;
    overall_objective,
    rank_to_happiness,
    assignments_to_load,
    optimizer_time_limit,
    max_students_per_project,
    max_students_per_teacher,
)

    projects = projects_data[!, 2]
    project_with_index = OrderedDict(project => k for (k, project) in enumerate(projects))
    n_projects = length(projects)

    @info "Found $n_projects projects:" project_with_index

    teachers = unique(projects_data[!, 1])
    n_teachers = length(teachers)
    teacher_assignments = OrderedDict(
        teacher => [k for k = 1:n_projects if projects_data[k, 1] == teacher] for
        teacher in teachers
    )

    @info "Found $n_teachers teachers with assignments:" teacher_assignments

    student_names = choices_data[!, 1]
    concat_student_names = join(student_names, "; ")
    n_students = length(student_names)

    @info "Found $n_students students:" concat_student_names

    choices = choices_data[!, 2:end]
    n_choices = size(choices, 2)

    @info "Found $n_choices choices per student."

    # Let's say that happiness is linearly decreasing with the ranking of the
    # project. If the student did not choose the project, we assign -100,000 to make sure
    # that this never happens.
    student_happiness = [
        let raw_out = findfirst(==(p), Vector(choices[s, :]))
            (raw_out === nothing ? -100_000.0 : float(rank_to_happiness(raw_out)))
        end for s = 1:n_students, p = 1:n_projects
    ]
    @info "Computed student happiness matrix."

    ipopt = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
    highs = optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false)
    juniper = optimizer_with_attributes(
        Juniper.Optimizer,
        "nl_solver" => ipopt,
        "mip_solver" => highs,
        "time_limit" => optimizer_time_limit,
    )
    optimizer = juniper
    model = Model(optimizer)
    @info "Loaded optimizer with `juniper` for local optimization, `highs` for MIP, and `ipopt` for NLP."

    # Student assignment matrix
    @variable(model, assign[1:n_students, 1:n_projects], Bin)

    @info "Initialising to first choice for all students."
    for s = 1:n_students, p = 1:n_projects
        if p == choices[s, 1]
            set_start_value(assign[s, p], 1)
        else
            set_start_value(assign[s, p], 0)
        end
    end

    @info "Creating constraints:"

    @constraint(model, sum(assign, dims = 2) .== 1)
    @info "    - Students need 1 project."

    @constraint(model, sum(assign, dims = 1) .<= max_students_per_project)
    @info "    - Each project can have at most $max_students_per_project students."

    for k = 1:n_teachers
        project_idx = findall(==(k), teacher_assignments)
        @constraint(model, sum(assign[:, project_idx]) .<= max_students_per_teacher)
    end
    @info "    - Each supervisor can have at most $max_students_per_teacher students."

    @info "Creating objective as combination of happiness and load."
    @expression(model, total_happiness, sum(assign .* student_happiness))
    @expression(model, project_load, sum(assignments_to_load.(sum(assign, dims = 1))))
    @objective(model, Max, overall_objective(total_happiness, project_load))

    @info "Model definition complete:" model

    @info "Optimising for up to $optimizer_time_limit seconds of solve time..."
    results = optimize!(model)
    found_project_assignments = OrderedDict(
        student_names[s] => findfirst(==(1.0), value.(assign[s, :])) for s = 1:n_students
    )
    @info "Done!" found_project_assignments
    if any(isnothing, values(found_project_assignments))
        error("Some students were not assigned to a project! Quitting.")
    end
    ranking_of_assigned = [
        "Rank " * string(
            findfirst(==(found_project_assignments[student]), Vector(choices[i, :])),
        ) for (i, student) in enumerate(student_names)
    ]
    ranking_distribution = countmap(ranking_of_assigned)
    students_per_project = OrderedDict(
        project => round(Int, value(sum(assign[:, project_with_index[project]]))) for
        project in keys(project_with_index)
    )
    students_per_teacher = OrderedDict(
        teacher => round(
            Int,
            value(sum([sum(assign[:, k]) for k in teacher_assignments[teacher]])),
        ) for teacher in teachers
    )

    @info "Some statistics about the solution:" students_per_project students_per_teacher ranking_distribution

    #=
    # which we can see is <= 4
    for (project, n_students) in zip(projects, students_per_project)
        println("$project: $n_students")
    end
    # Plotted version of this (bar plot, with xlabel = project name)
    using Plots
    bar(1:n_projects, students_per_project', xlabel="Project", ylabel="Number of students")
    # Label the projects (rotated text):
    xticks!(1:n_projects, projects, rotation=90)
    # Save the figure to a file:
    savefig("students_per_project_with_load.png")
    # -

    # Then the number of students per teacher:
    students_per_teacher = [value.(sum(assign[:, findall(==(k), teacher_assignments)])) for k in 1:n_teachers]
    # which we can see is at most 8
    for (teacher, n_students) in zip(teachers, students_per_teacher)
        println("$teacher: $n_students")
    end

    # Next, let's see the distribution of happiness:
    final_happiness = value.(sum(assign .* student_happiness, dims=2)[:])
    countmap(final_happiness)
    # Which we can see has 96 students with their 1st choice
    # and 4 students with their 2nd choice.

    for student in 1:n_students
        project_choice = findall(==(1.0), value.(assign[student, :]))[1]
        println("$project_choice")
    end
    =#
end

function load_and_validate_data(raw_input, type)
    data = load_data(raw_input, type)
    if type == :choices
        @info "Lower-casing names and removing grammar"
        clean_indices = [1]
    elseif type == :projects
        @info "Lower-casing teacher and project names and removing grammar"
        clean_indices = [1, 2]
    end
    for i in clean_indices
        data[!, i] .= replace.(lowercase.(data[!, i]), r"[\.,]" => "")
        data[!, i] .= replace.(data[!, i], r"\s+$" => "")
        data[!, i] .= replace.(data[!, i], r"^\s+" => "")
    end
    return data
end

function load_data(raw_input::String, type)
    @info "Assuming $raw_input is a csv file with no header (data starting at the first row)"
    if type == :choices
        @info "   - Assuming first column is student name, and the rest are project choices (integer)"
        types = (i, _) -> i == 1 ? String : Int
    else
        @info "   - Assuming first column is teacher name, and the second column is project name"
        types = (_, _) -> String
    end
    return CSV.read(raw_input, DataFrame; header = 0, types)
end


end
