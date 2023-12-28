var documenterSearchIndex = {"docs":
[{"location":"","page":"Home","title":"Home","text":"CurrentModule = UniAdminTools","category":"page"},{"location":"#UniAdminTools","page":"Home","title":"UniAdminTools","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for UniAdminTools.","category":"page"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"#CLI","page":"Home","title":"CLI","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"projalloc\nmergescore","category":"page"},{"location":"#UniAdminTools.ProjAlloc.projalloc","page":"Home","title":"UniAdminTools.ProjAlloc.projalloc","text":"projalloc --choices CHOICES\n          --projects PROJECTS\n          [--output \"project_allocations.csv\"]\n          [--overall_objective \"happiness - 0.5 * load\"]\n          [--rank_to_happiness \"10 - 2^(ranking - 1) + 1\"]\n          [--assignments_to_load \"num_assigned^2\"]\n          [--optimizer_time_limit 5]\n          [--max_students_per_project 4]\n          [--max_students_per_teacher 12]\n          [--silent]\n\nIntro\n\nCompute optimal project allocations for student projects, using two csv files.\n\nOptions\n\n--choices: A csv file with no header (data starting at the first row). The first column  should be the student name, and the rest should be project choices (integer).\n--projects: A csv file with no header (data starting at the first row). The first column  should be the teacher name, and the second column should be the project name.\n--output <\"project_allocations.csv\"::String>: The filename to save the output to.\n--overall_objective <\"happiness - 0.5 * load\"::String>: A function that takes the total happiness and the total   load and returns a single number. This will be maximized.\n--rank_to_happiness <\"10 - 2^(ranking - 1) + 1\"::String>: Convert a student-assigned ranking into a happiness,   which will be summed over students.\n--assignments_to_load <\"num_assigned^2\"::String>: A function that takes the number of students assigned   to each project and returns a number. This will be summed over projects.\n--optimizer_time_limit <5::Int>: How long to spend optimizing the project allocations.   Should usually find it pretty quickly (within 5 seconds), but you might try increasing   this to see if it changes the results.\n--max_students_per_project <4::Int>: The maximum number of students that can be assigned to a project.\n--max_students_per_teacher <12::Int>: The maximum number of students that can be assigned to a teacher.\n\nFlags\n\n--silent: Don't print out information about the optimization process.\n\n\n\n\n\n","category":"function"},{"location":"#UniAdminTools.MergeScore.mergescore","page":"Home","title":"UniAdminTools.MergeScore.mergescore","text":"mergescore input\n           [--sheet-name SHEET_NAME]\n           [--scorer-range SCORER_RANGE]\n           [--candidate-range CANDIDATE_RANGE]\n           [--data-range DATA_RANGE]\n           [--output \"candidate_info.csv\"]\n           [--scorer-info \"scorer_info.csv\"]\n           [--n-chains 6]\n           [--n-samples 2000]\n           [--n-adapts 500]\n           [--sampler \"NUTS()\"]\n           [--silent]\n\nIntro\n\nEstimate true scores of candidates from sparse observations by committee members.\n\nArgs\n\ninput: A csv or xlsx file with candidates and committee scores between 1 and 10, with   unranked candidate-scorer pairs left blank.\n\nOptions\n\n--sheet-name: If an xlsx file is passed, the name of the sheet to read from (such as \"Sheet 1\").\n--scorer-range: If an xlsx file is passed, the range of cells containing the names of the scorers   (such as \"A2:A10\").\n--candidate-range: If an xlsx file is passed, the range of cells containing the names of the candidates   (such as \"B1:J1\").\n--data-range: If an xlsx file is passed, the range of cells containing the scores of the candidates   (such as \"B2:J10\").\n--output: The name of the (csv) file to write the estimated scores to.\n--scorer-info: The name of the file to write the estimated biases and scales of the scorers to.\n--n-chains: The number of chains to run.\n--n-samples: The number of samples to draw from each chain.\n--n-adapts: The number of samples to use for warming up.\n--sampler: The sampler to use. Can be, for example, \"NUTS()\" or \"SMC()\".\n--lower-true-score: The lower bound of the uniform prior on the true scores.\n--upper-true-score: The upper bound of the uniform prior on the true scores.\n--mean-bias: The mean of the normal prior on the bias of the scorers.\n--stdev-bias: The standard deviation of the normal prior on the bias of the scorers.\n--mean-scale: The mean of the normal prior on the scale of the scorers.\n--stdev-scale: The standard deviation of the normal prior on the scale of the scorers.\n\nFlags\n\n--silent: Whether to suppress output.\n\nExample\n\nSay we put all the data into a file data.csv:\n\ncandidates,Scorer AA,BB,DD,FF,HH,LL,MM,avg,spread\nCandidate 1,,7.9,,8.5,8.2,8.4,,8,0.26\nCandidate 2,4.2,7.4,3.7,,,,2.8,5,1.63\nCandidate 3,,4.4,,5.2,5.7,,5.2,5,0.48\nCandidate First name Last name,9.6,,7.6,,8,,,9,1.03\nCandidate 5,,,,,,,,,\n\nWe can then create estimates for true scores with:\n\nmergescore data.csv --n-chains 5 --n-samples 3000 --output my_output.csv\n\nwhich will create a file my_output.csv with estimates for true scores of each candidate.\n\n\n\n\n\n","category":"function"},{"location":"#Internal","page":"Home","title":"Internal","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"optimize_project_allocations","category":"page"},{"location":"#UniAdminTools.ProjAlloc.optimize_project_allocations","page":"Home","title":"UniAdminTools.ProjAlloc.optimize_project_allocations","text":"optimize_project_allocations(data; kws...)\n\nFind optimal project allocations using HiGHS, Ipopt, and Juniper.\n\nchoices: A filename (or data itself) where each row is one student's project choices,  with the first column being the student name, and the next columns being their choices  (second column being their first choice).\nprojects: A filename (or data itself) where each row is a project. The first  column should be the project name, and the second column the teacher name. The row index  of the project is its identifier in the choices table.\noutput_fname: The filename to save the output to. The default is project_allocations.csv.\noverall_objective: A function that takes the total happiness and the total   load and returns a single number. The default is to maximize happiness minus   0.5 times the load.\nrank_to_happiness: Convert a student-assigned ranking into a happiness.\nassignments_to_load: A function that takes the number of students assigned   to each project and returns a number. The default is to return the square of   the number of students.\noptimizer_time_limit: How long to spend optimizing the project allocations.   Should usually find it pretty quickly (within 5 seconds), but you might try increasing   this to see if it changes the results.\nmax_students_per_project: The maximum number of students that can be assigned to a project.\nmax_students_per_teacher: The maximum number of students that can be assigned to a teacher.\nverbose: Whether to print out information about the optimization process.\n\n\n\n\n\n","category":"function"}]
}
