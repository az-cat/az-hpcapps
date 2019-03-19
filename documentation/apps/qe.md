### Quantum Espresso

- Application name = **qe**

#### Application binaries and data
http://www.quantum-espresso.org/
Benchmark located here https://github.com/QEF/benchmarks are already in the image built.


#### Setup Steps
```
    ./build_image.sh -a qe
    ./create_cluster.sh -a qe
```

#### Running Benchmarks
Script parameters are :
- Folder Name
- Input file
- Number of OMP threads

./run_app.sh -a qe -c config.json \
    -s benchmark \
    -n 2 -p 44 \
    -x "AUSURF112 ausurf.in 1"



#### Tuning and workarounds

#### Results
