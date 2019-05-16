### Pamcrash
- Application name = **pamcrash**

#### Submit all tests

The available case is : 
    
 - neon_front
 

To run several cases use this :

    for case in neon_front.pc.gz; do 
        for n in 4 8 16; do 
            for ppn in 14 15 16; do 
                ./run_app.sh \
                    -a pamcrash \
                    -s case \
                    -n ${n} -p ${ppn} \
                    -t ${case}_${n}_${ppn} \
                    -x "$case"
            done
        done
    done

#### Tuning and workarounds

For run on H16r above 8 nodes, using 14 or 15 cores may provide better performances.


#### Results

To retrieve the solver rating from Log Analytics, run this query from your Log Analytics query portal

    pamcrash_CL 
    | where model_s == "neon_front" 
    | summarize percentile(elapsed_time_d, 99) by Nodes_s, ppn_s
    | order by toint(Nodes_s) asc
    | render timechart 

For each run, the following metrics are extracted from the result file and pushed into Log analytics :

- Elapsed time
- CPU time
- Version
- Model
