#!/usr/bin/env bash
fluent_case=$1
mpi=$2
iter=$3

CLEANUP_OPTION=

setup_impi()
{
    source /opt/intel/impi/*/bin64/mpivars.sh
    export MPI_ROOT=$I_MPI_ROOT
    case "$INTERCONNECT" in
        ib)
            export I_MPI_FABRICS=shm:dapl
            export I_MPI_DAPL_PROVIDER=ofa-v2-ib0
            export I_MPI_DYNAMIC_CONNECTION=0
            export I_MPI_FALLBACK_DEVICE=0
            export FLUENT_BENCH_OPTIONS="-pib.dapl -mpi=intel"
            ;;
        sriov)
            export I_MPI_FABRICS=shm:ofa
            export I_MPI_FALLBACK_DEVICE=0
            export FLUENT_BENCH_OPTIONS="-pib.ofa -mpi=intel"
            ;;
        tcp)
            export I_MPI_FABRICS=shm:tcp
            ;;
    esac
    CLEANUP_OPTION="-ppn 1 -np $NODES --hostfile $MPI_HOSTFILE"
}

setup_pmpi()
{
    export MPI_ROOT=/opt/ibm/platform_mpi
    export PATH=$MPI_ROOT/bin:$PATH
    export FLUENT_BENCH_OPTIONS="-pinfiniband -mpi=ibmmpi"
    export IBMMPI_MPIRUN_FLAGS="-aff -e MPI_IB_PKEY=$IB_PKEY"
    CLEANUP_OPTION="-np $NODES -hostfile $MPI_HOSTFILE"
}


case "$mpi" in
    impi)
        setup_impi
        ;;
    pmpi)
        setup_pmpi
        ;;
    *)
        setup_impi
        ;;
esac

start_time=$SECONDS

echo "downloading case ${fluent_case}..."
wget -q "${STORAGE_ENDPOINT}/ansys-fluent-benchmarks/${fluent_case}.tar?${SAS_KEY}" -O - | tar x
end_time=$SECONDS
download_time=$(($end_time - $start_time))
echo "Download time is ${download_time}"


export VERSION=192
export PATH=/opt/ansys_inc/v${VERSION}/fluent/bin:$PATH
export ANSYSLMD_LICENSE_FILE=1055@${LICENSE_SERVER}

echo "Cleaning up old processes"
mpirun $CLEANUP_OPTION bash -c 'for proc in $(pgrep fluent_mpi); do kill -9 $proc; done'

echo "Running Ansys Benchmark case : [${fluent_case}] on ${CORES} cores"
iter_options=""
if [ -n $iter ]; then
    iter_options="-iter=$iter"
fi

export FLUENT_BENCH_CAS="./bench/fluent/v6/${fluent_case}/cas_dat/"
fluentbench.pl ${fluent_case} -t${CORES} ${FLUENT_BENCH_OPTIONS} -ssh -cnf=$MPI_MACHINEFILE $iter_options

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
    
    mpi_version=$(mpirun -version | head -n 1)

    cat <<EOF >$APPLICATION.json
    {
    "mpi_version": "$mpi_version",
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

