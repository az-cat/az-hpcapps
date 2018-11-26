### Abaqus

- Application name = **abaqus**

#### Application binaries and data

- upload **2017.AM_SIM_Abaqus_Extend.AllOS.\*-6.tar** files to {appstorage.storage_account}/apps/abaqus-2017
- upload **\*.inp** files to {appstorage.storage_account}/data/abaqus-benchmarks

#### Setup Steps

```
    ./build_image.sh -a abaqus
    ./create_cluster.sh -a abaqus
```

#### Running Benchmarks

The available benchmark cases are : 
    
 - e1
 - s4b
 

To run several cases use this :

    for case in e1 s4b; do 
        for n in 4 8 16; do 
            for ppn in 14 15 16; do 
                ./run_app.sh \
                    -a abaqus \
                    -s case \
                    -n ${n} -p ${ppn} \
                    -t ${case}_${n}_${ppn} \
                    -x "$case"
            done
        done
    done


#### Tuning and workarounds

For large models running on h16r above 32 nodes, using 14 or 15 cores may provide better performances.