### ANSYS Mechanical

- Application name = **mechanical**

#### Application binaries and data

- upload **STRUCTURES_192_LINX64.tar** to {appstorage.storage_account}/apps/ansys-mech-19-2
- upload **BENCH_V180_LINUX.tgz** to {appstorage.storage_account}/data/ansys-mechanical-benchmarks

#### Setup Steps

```
    ./build_image.sh -a mechanical
    ./create_cluster.sh -a mechanical
``` 

#### Running Tests

	./run_app.sh \
		-a mechanical \
		-s case \
		-x V18cg-1 \
		-n 2 -p 16

Available tests :
	
- V18cg-1
- V18cg-2
- V18cg-3
- V18sp-1
- V18sp-2
- V18sp-3
- V18sp-4

To run several cases use this :

	for case in V18cg-1; do 
		for n in 2 4 8; do 
			for ppn in 14 15 16; do 
				./run_app.sh \
					-a mechanical \
					-s case \
                    -n ${n} -p ${ppn} \
                    -t ${case}_${n}_${ppn} \
                    -x "$case"
			done
		done
	done


#### Benchmark case description

**V18cg-1**

- Description: Electronic components: JCG solver, symmetric matrix, 5300k DOFS, static, linear, thermal analysis
- Notes: Medium sized job for iterative solvers, good test of memory bandwidth 

**V18cg-2**

- Description: PCG solver, symmetric matrix, 12300k DOFs, static, linear, structural analysis
- Notes: Large sized job for iterative solvers, good test of memory bandwidth
- GPU Option: NVIDIA


**V18cg-3**

- Description: Engine Block: PCG solver, symmetric matrix, 14200k DOFs, static, linear, structural analysis
- Notes: Large sized job for iterative solvers, good test of processor flop speed and memory bandwidth
- GPU Option: none


**V18sp-1**

- Description: thermal structure: Sparse solver, non-symmetric matrix, 650k DOFs, static, nonlinear, thermal-electric coupled field analysis
- Notes:  Medium sized job for direct solvers, should run incore on machines with 32 GB or more of memory, good test of processor flop speed if running incore and I/O if running out-of-core
- GPU Option: NVIDIA


**V18sp-2**

- Description: oil rig: Sparse solver, symmetric matrix, 4700k DOFs, transient, nonlinear, structural analysis
- Notes: Medium sized job for direct solvers, should run incore on machines with 48 GB or more of memory, good test of processor flop speed if running incore and I/O if running out-of-core
- GPU Option: NVIDIA, Intel


**V18sp-3**

- Description: Sparse solver, symmetric matrix, 1700k DOFs, harmonic, linear, structural analysis requesting 1 frequency.
- Notes: Medium sized job for direct solvers, should run incore on machines with 64 GB or more of memory, good test of processor flop speed if running incore and I/O if running out-of-cor
- GPU Option: NVIDIA, Intel


**V18sp-4**

- Description: Sparse solver, symmetric matrix, 3200k DOFs, static, nonlinear, structural analysis with 1 iteration
- Notes: Large sized job for direct solvers), should run incore on machines with 96 GB or more of memory, good test of processor flop speed if running incore and I/O if running out-of-core
- GPU option: NVIDIA, Intel


#### Results

To retrieve the solver rating from Log Analytics, run this query from your Log Analytics query portal

	mechanical_CL 
	| where model_s == "V18cg-1" 
	| summarize percentile(compute_time_d, 99) by Nodes_s, ppn_s
	| order by toint(Nodes_s) asc
	| render timechart 



For each run, the following metrics are extracted from the result file and pushed into Log analytics :

 - Elapsed time spent computing solution
 - Total CPU time summed for all threads
