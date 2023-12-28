using UniAdminTools
using Test
using Aqua
using Suppressor

@testset "Code quality (Aqua.jl)" begin
    Aqua.test_all(UniAdminTools; ambiguities = false)
    Aqua.test_ambiguities(UniAdminTools; recursive = false)
end

@testset "Project allocations" begin
    @eval function dedent(str::String)
        lines = split(str, '\n')
        filter!(line -> !isempty(strip(line)), lines)
        min_indent = minimum(
            length(match(r"^\s*", line).match) for line in lines if !isempty(strip(line))
        )
        dedented_lines =
            [replace(line, Regex("^" * " "^min_indent) => "") for line in lines]
        return join(dedented_lines, '\n')
    end
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
            data[] = optimize_project_allocations(
                choices_fname,
                listings_fname;
                max_students_per_project = 2,
                verbose = true,
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
            data[] = optimize_project_allocations(
                choices_fname,
                listings_fname;
                max_students_per_project = 3,
                max_students_per_teacher = 3,
                verbose = false,
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
