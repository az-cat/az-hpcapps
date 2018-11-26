### Fluent

- Application name = **fluent**

#### Application binaries and data

- upload **FLUIDS_182_LINX64.tar** file to {appstorage.storage_account}/apps/ansys-fluent-18
- upload **\*.tar** benchmark files (like aircraft_wing_14m.tar) to {appstorage.storage_account}/data/ansys-fluent-benchmarks

#### Setup Steps
```
    ./build_image.sh -a fluent
    ./create_cluster.sh -a fluent
```

#### Running Benchmarks

The available benchmark cases are : 
    
 - aircraft_wing_2m
 - aircraft_wing_14m
 - combustor_12m
 - combustor_71m
 - exhaust_system_33m
 - f1_racecar_140m
 - landing_gear_15m
 - oil_rig_7m
 - open_racecar_280m
 - sedan_4m


To run several cases use this :

    for case in aircraft_wing_14m combustor_12m landing_gear_15m; do 
        for n in 4 8 16; do 
            for ppn in 14 15 16; do 
                ./run_app.sh \
                    -a fluent \
                    -s benchmark \
                    -n ${n} -p ${ppn} \
                    -t ${case}_${n}_${ppn} \
                    -x "$case"
            done
        done
    done


#### Tuning and workarounds

For large models running on H16r above 32 nodes, using 14 or 15 cores may provide better performances.


#### Results

To retrieve the solver rating from Log Analytics, run this query from your Log Analytics query portal

    fluent_CL
    | summarize percentile(rating_d, 99) by Nodes_s, model_s
    | order by toint(Nodes_s) asc
    | render timechart 

For each run, the following metrics are extracted from the result file and pushed into Log analytics :

- Solver rating
- Total wall time
- Total CPU time
- Wall time per iteration
- CPU time per iteration
- Number of iterations
- Read case time
- Read data time
- Version
- Model
