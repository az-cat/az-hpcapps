#!/usr/bin/env bash
fluent_case=$1
start_time=$SECONDS
iter=$2

echo "downloading case ${fluent_case}..."
wget -q "${STORAGE_ENDPOINT}/ansys-fluent-benchmarks/${fluent_case}.tar?${SAS_KEY}" -O - | tar x
end_time=$SECONDS
download_time=$(($end_time - $start_time))
echo "Download time is ${download_time}"
source /opt/intel/impi/*/bin64/mpivars.sh

if [ "$INTERCONNECT" == "ib" ]; then
    export I_MPI_FABRICS=shm:dapl
    export I_MPI_DAPL_PROVIDER=ofa-v2-ib0
    export I_MPI_DYNAMIC_CONNECTION=0
    export I_MPI_FALLBACK_DEVICE=0
    export FLUENT_BENCH_OPTIONS="-pib.dapl"
elif [ "$INTERCONNECT" == "sriov" ]; then
    export I_MPI_FABRICS=shm:ofa
    export I_MPI_FALLBACK_DEVICE=0
    export FLUENT_BENCH_OPTIONS="-pib.ofa"
else
    export I_MPI_FABRICS=shm:tcp
fi

export MPI_ROOT=$I_MPI_ROOT
export VERSION=192
export PATH=/opt/ansys_inc/v${VERSION}/fluent/bin:$PATH
export ANSYSLMD_LICENSE_FILE=1055@${LICENSE_SERVER}

echo "Cleaning up old processes"
mpirun -ppn 1 -np $NODES --hostfile $MPI_HOSTFILE bash -c 'for proc in $(pgrep fluent_mpi); do kill -9 $proc; done'

echo "Running Ansys Benchmark case : [${fluent_case}] on ${CORES} cores"
iter_options=""
if [ -n $iter ]; then
    iter_options="-iter=$iter"
fi

export FLUENT_BENCH_CAS="./bench/fluent/v6/${fluent_case}/cas_dat/"
fluentbench.pl ${fluent_case} -t${CORES} ${FLUENT_BENCH_OPTIONS} -mpi=intel -ssh -cnf=$MPI_MACHINEFILE $iter_options

cp ${fluent_case}*.* ${OUTPUT_DIR}
end_time=$SECONDS
task_time=$(($end_time - $start_time))

# extract telemetry
case_output=${fluent_case}-${CORES}.out
if [ -f "${case_output}" ]; then
    rating=$(grep "Solver rating" ${case_output} | cut -d'=' -f2)
    total_wall_time=$(grep "Total wall time" ${case_output} | cut -d'=' -f2 | cut -d' ' -f2)
    total_cpu_time=$(grep "Total CPU time" ${case_output} | cut -d'=' -f2 | cut -d' ' -f2)
    wall_time_iter=$(grep "Wall time per iteration" ${case_output} | cut -d'=' -f2 | cut -d' ' -f2)
    cpu_time_iter=$(grep "CPU time per iteration" ${case_output} | cut -d'=' -f2 | cut -d' ' -f2)
    nb_iter=$(grep "Number of iterations" ${case_output} | cut -d'=' -f2 | cut -d' ' -f2)
    read_case_time=$(grep "Read case time" ${case_output} | cut -d'=' -f2 | cut -d' ' -f2)
    read_data_time=$(grep "Read data time" ${case_output} | cut -d'=' -f2 | cut -d' ' -f2)
    
    cat <<EOF >$APPLICATION.json
    {
    "version": "$VERSION",
    "model": "$fluent_case",
    "rating": $rating,
    "total_wall_time": $total_wall_time,
    "total_cpu_time": $total_cpu_time,
    "wall_time_iter": $wall_time_iter,
    "cpu_time_iter": $cpu_time_iter,
    "nb_iter": $nb_iter,
    "read_case_time": $read_case_time,
    "read_data_time": $read_data_time,
    "task_time": $task_time,
    "download_time": $download_time
    }
EOF
fi

