#!/bin/bash
set -e

qe_case=$1
qe_input=$2

output_file=${OUTPUT_DIR}/qe.log

export I_MPI_DYNAMIC_CONNECTION=0
export I_MPI_FALLBACK_DEVICE=0
if [ "$INTERCONNECT" == "ib" ]; then
    export I_MPI_FABRICS=shm:dapl
    export I_MPI_DAPL_PROVIDER=ofa-v2-ib0
elif [ "$INTERCONNECT" == "sriov" ]; then
    export I_MPI_FABRICS=shm:ofa
else
    export I_MPI_FABRICS=shm:tcp
fi

source /opt/intel/mkl/bin/mklvars.sh intel64
source /opt/intel/impi/*/bin64/mpivars.sh

# downloading case on all nodes
#mpirun -np $NODES -ppn 1 -hosts $MPI_HOSTLIST bash -c "wget -q https://raw.githubusercontent.com/QEF/benchmarks/master/AUSURF112/Au.pbe-nd-van.UPF; wget -q https://raw.githubusercontent.com/QEF/benchmarks/master/AUSURF112/ausurf.in"
mpirun -np $NODES -ppn 1 -hosts $MPI_HOSTLIST bash -c "cp -r /opt/benchmarks/$qe_case/* ."


# -npool P 
# 	(tells Quantum ESPRESSO to use P pools to distribute data. P should
# 	be less or equal the number of k-points, and maximum scalability is
# 	usually reached with P exactly equal to the number of k-points. You can
# 	read the output to find out the number of k-points of your system)
# -ntg T 
# 	(tells Quantum ESPRESSO to use T task groups to distribute FFT. Usually
# 	optimal performance can be reached with T ranging from 2 to 8)
# -ndiag D 
# 	(tells Quantum ESPRESSO to use D processors to perform parallel linear
# 	algebra computation, ScalaPACK. D can range from 1 to the maximum
# 	number of MPI tasks, the optima value for D depend on the bandwidth and 
# 	latency of your network).

# -npools 2 -ntg 4 -ndiag 1024 (for 1024 cores)
#  –bgrp 4
#  npools must be a divisor of the total number of k-points


export I_MPI_STATS=ipm
export OMP_NUM_THREADS=$3
# export OMP_PROC_BIND=SPREAD
# export OMP_PLACES=cores
# export OMP_PROC_BIND=TRUE

if [ $NODES -gt 1 ]; then
    npools=2
    ntg=4
    ndiag=$CORES
    pw_options="-npools $npools -ntg $ntg -ndiag $ndiag"
    options_json="\"npools\": $npools,\"ntg\": $ntg,\"ndiag\": $ndiag,"
else
    pw_options=""
    options_json=""
fi


start_time=$SECONDS
mpirun -np $CORES -ppn $PPN -hosts $MPI_HOSTLIST /opt/qe-omp/bin/pw.x $pw_options -input $qe_input | tee ${output_file}
end_time=$SECONDS
task_time=$(($end_time - $start_time))
total_energy=$(grep "total energy              =" ${output_file} | tail -1)

if [ -n "$total_energy" ]; then
    VERSION=$(grep PWSCF ${output_file} | head -n 1 | xargs | cut -d' ' -f2,3)
    total_energy=$(grep "total energy              =" ${output_file} | tail -1 | cut -d'=' -f2| xargs)
    cpu_time=$(grep PWSCF ${output_file} | tail -n 1 | xargs | cut -d' ' -f3)
    wall_time=$(grep PWSCF ${output_file} | tail -n 1 | xargs | cut -d' ' -f5)
    cat <<EOF >$APPLICATION.json
    {
    "version": "$VERSION",
    "case": "$qe_case",
    "total_energy": "$total_energy",
    $options_json
    "omp_num_threads": $OMP_NUM_THREADS,
    "cpu_time": "$cpu_time",
    "wall_time": "$wall_time",
    "task_time": $task_time
    }
EOF
fi