### Gromacs

- Application name = **gromacs**

#### Setup Steps
Gromacs source code is downloaded and compiled when building the image. Compiling on the same architecture than where the code is going to run will allow the build process to optimize for that architecture. For example choosing the right AVX set.
Intel MPI tools and compiler are also downloaded, if the link expires, create a new trial account and update the link accordingly in the install_gromacs.sh file.

#### Running Benchmarks

The available benchmark packages and cases are : 
    
 - GROMACS_TestCaseB / lignocellulose-rf.tpr
 - GROMACS_TestCaseA / TBD

To run several cases use this :

    for n in 2 4 8 16; do 
        for ppn in 14 15 16; do 
            ./run_app.sh \
                -a gromacs \
                -s case \
                -n ${n} -p ${ppn} \
                -x "GROMACS_TestCaseB lignocellulose-rf.tpr"
        done
    done


#### Tuning and workarounds

For large models running on H16r above 32 nodes, using 14 or 15 cores may provide better performances.


#### Results

To retrieve the solver rating from Log Analytics, run this query from your Log Analytics query portal

    gromacs_CL 
    | where model_s == "lignocellulose-rf.tpr" 
    | summarize percentile(total_wall_time_d, 99) by Nodes_s, ppn_s
    | order by toint(Nodes_s) asc
    | render timechart 

For each run, the following metrics are extracted from the result file and pushed into Log analytics :

- Total wall time
- Total CPU time
- Number of steps
- Number of OMP Threads
- Version
- Model
