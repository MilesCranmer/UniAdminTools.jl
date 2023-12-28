using UniAdminTools
using Test
using Aqua
using Suppressor
using Random: seed!

@testset "Code quality (Aqua.jl)" begin
    Aqua.test_all(
        UniAdminTools;
        ambiguities = false,
        deps_compat = false,
        stale_deps = false,
    )
    Aqua.test_ambiguities(UniAdminTools; recursive = false)
end

function dedent(str::String)
    lines = split(str, '\n')
    filter!(line -> !isempty(strip(line)), lines)
    min_indent = minimum(
        length(match(r"^\s*", line).match) for line in lines if !isempty(strip(line))
    )
    dedented_lines = [replace(line, Regex("^" * " "^min_indent) => "") for line in lines]
    return join(dedented_lines, '\n')
end

@testset "Project allocations" begin
    @testset "Test 1 - easy optimization problem" begin
        tmpdir = mktempdir()
        choices_fname = joinpath(tmpdir, "example_project_choices.csv")
        listings_fname = joinpath(tmpdir, "example_project_listings.csv")
        open(choices_fname, "w") do io
            write(io, dedent("""
                "A",1,2,4
                "B",1,3,4
                "C",5,3,4
                "D",6,1,2
            """))
        end
        open(listings_fname, "w") do io
            write(io, dedent("""
                "Teacher A","A1"
                "Teacher A","A2"
                "Teacher B","B 3"
                "Teacher C","C4"
                "Teacher D","My project 1"
                "Teacher D","My project 2"
                "Teacher D","My project 3"
            """))
        end
        data = Ref{Any}()
        log = @capture_err begin
            data[] = projalloc(;
                choices = choices_fname,
                projects = listings_fname,
                max_students_per_project = 2,
                silent = false,
            )
        end
        out = data[]
        @test out[!, :student] == ["A", "B", "C", "D"]
        @test out[!, :project] == [1, 1, 5, 6]
        @test out[!, :project_name] == ["A1", "A1", "My project 1", "My project 2"]
        @test out[!, :ranking] == [1, 1, 1, 1]

        @test occursin(
            r"Assuming .*example_project_choices.csv is a csv file with no header",
            log,
        )
        @test occursin(r"Some statistics about the solution:", log)
    end
    @testset "Test 2 - bit more complex" begin
        tmpdir = mktempdir()
        choices_fname = joinpath(tmpdir, "complex_project_choices.csv")
        listings_fname = joinpath(tmpdir, "complex_project_listings.csv")

        open(choices_fname, "w") do io
            write(io, dedent("""
                " Student1",1,2,3
                "Student2 ",1,2,4
                "Student3  ",1,3,5
                "Student4",1,4,5
                "Student5",1,3,5
                "Student6",1,2,5
                """))
        end
        open(listings_fname, "w") do io
            write(io, dedent("""
                "Teacher1","P1"
                "Teacher1","P2"
                "Teacher2","P3"
                "Teacher3","   P4  "
                "Teacher4","P5"
                """))
        end

        data = Ref{Any}()
        log = @capture_err begin
            data[] = projalloc(;
                choices = choices_fname,
                projects = listings_fname,
                max_students_per_project = 3,
                max_students_per_teacher = 3,
                silent = true,
            )
        end
        out = data[]

        @test out[!, :student] ==
              ["Student1", "Student2", "Student3", "Student4", "Student5", "Student6"]
        @test out[!, :project] == [2, 1, 3, 4, 3, 1]
        @test out[!, :project_name] == ["P2", "P1", "P3", "P4", "P3", "P1"]

        @test !occursin(r"is a csv file with no header", log)
    end
end

@testset "Merging scores" begin
    tmpdir = mktempdir()
    input_fname = joinpath(tmpdir, "input.csv")
    open(input_fname, "w") do io
        write(io, dedent("""
                  candidates,AA,BB,DD,FF,HH,LL,MM
                  Candidate 1,,7.9,,8.5,8.2,8.4,
                  Candidate 2,4.2,7.4,3.7,,,,2.8
                  Candidate 3,,4.4,,5.2,5.7,,5.2
                  Candidate 4,9.6,,7.6,,8,,
                  Candidate 5,5.2,2.7,3,,,,1
                  Candidate 6,2.7,1.7,,,0.7,3.3,
                  Candidate FIRST NAME LAST NAME,,,,,7.4,7.2,
                  Candidate 8,3.4,,1.8,,,,1.9
                  Candidate 9,6.3,6.4,6.8,7.9,,6.6,7
                  Candidate 10,,,,,2,,2.1
                  Candidate 11,,,,,,,
                  """))
    end
    data = Ref{Any}()
    log = @capture_err begin
        seed!(0)
        data[] = mergescore(
            input;
            output = joinpath(tmpdir, "output.csv"),
            scorer_info = joinpath(tmpdir, "scorer_info.csv"),
            n_chains = 5,
            n_samples = 1000,
            n_adapts = 500,
            sampler = "NUTS(init_ϵ=0.12345)",
            silent = false,
        )
    end
    @test occursin("is a csv file with candidate names in the first column", log)
    @test occursin("Found 7 scorers", log)
    @test occursin("Found 11 candidates", log)
    @test occursin("NUTS", log)
    @test occursin("0.12345", log)
    @test occursin(r"missing\s*8.5", log)

    expected_averages = [8, 5, 5, 9, 3, 2, 7, 3, 7, 2, 5.5]
    for i in eachindex(expected_averages)
        @test isapprox(data[].score[i], expected_averages[i]; atol = 1.0)
    end
    @test data[].name[7] == "Candidate FIRST NAME LAST NAME"
    @test isapprox(data[].uncertainty[end], 2.5; atol = 0.5)
end
