#!/bin/bash
set -o errexit
set -o pipefail

# variables set in run_app.sh
if [[ -z "#TASK_ID#" ]]; then
    echo "ERROR: TASK_ID is empty"
    exit 1
fi
if [[ -z "#JOB_ID#" ]]; then
    echo "ERROR: JOB_ID is empty"
    exit 1
fi
if [[ -z "#APP#" ]]; then
    echo "ERROR: APP is empty"
    exit 1
fi
if [[ -z "#APP_SCRIPT#" ]]; then
    echo "ERROR: APP_SCRIPT is empty"
    exit 1
fi
if [[ -z "#RESULTS_ENDPOINT#" ]]; then
    echo "ERROR: RESULTS_ENDPOINT is empty"
    exit 1
fi
if [[ -z "#RESULTS_CONTAINER#" ]]; then
    echo "ERROR: RESULTS_CONTAINER is empty"
    exit 1
fi
if [[ -z "#RESULTS_SASKEY#" ]]; then
    echo "ERROR: RESULTS_SASKEY is empty"
    exit 1
fi
if [[ -z "#NUM_NODES#" ]]; then
    echo "ERROR: NUM_NODES is empty"
    exit 1
fi
if [[ -z "#PPN#" ]]; then
    echo "ERROR: PPN is empty"
    exit 1
fi
if [[ -z "#LICSERVER#" ]]; then
    echo "ERROR: LICSERVER is empty"
    exit 1
fi
if [[ -z "#HPC_DATA_SASKEY#" ]]; then
    echo "ERROR: HPC_DATA_SASKEY is empty"
    exit 1
fi
if [[ -z "#HPC_DATA_STORAGE_ENDPOINT#" ]]; then
    echo "ERROR: HPC_DATA_STORAGE_ENDPOINT is empty"
    exit 1
fi
if [[ -z "#SCRIPT_FLAGS#" ]]; then
    echo "ERROR: SCRIPT_FLAGS is empty"
    exit 1
fi
if [[ -z "#ANALYTICS_WORKSPACE#" ]]; then
    echo "ERROR: ANALYTICS_WORKSPACE is empty"
    exit 1
fi
if [[ -z "#ANALYTICS_KEY#" ]]; then
    echo "ERROR: ANALYTICS_KEY is empty"
    exit 1
fi

# variables set in batch_wrapper.sh
if [[ -z "#MPI_HOSTLIST#" ]]; then
    echo "ERROR: MPI_HOSTLIST is empty"
    exit 1
fi
if [[ -z "#MPI_HOSTFILE#" ]]; then
    echo "ERROR: MPI_HOSTFILE is empty"
    exit 1
fi
if [[ -z "#MPI_MACHINEFILE#" ]]; then
    echo "ERROR: MPI_MACHINEFILE is empty"
    exit 1
fi
if [[ -z "#CORES#" ]]; then
    echo "ERROR: CORES is empty"
    exit 1
fi
if [[ -z "#OUTPUT_DIR#" ]]; then
    echo "ERROR: OUTPUT_DIR is empty"
    exit 1
fi
if [[ -z "#SHARED_DIR#" ]]; then
    echo "ERROR: SHARED_DIR is empty"
    exit 1
fi
if [[ -z "#INTERCONNECT#" ]]; then
    echo "ERROR: INTERCONNECT is empty"
    exit 1
fi

# variables set in the task-template.json
if [[ -z "#APPLICATION#" ]]; then
    echo "ERROR: APPLICATION is empty"
    exit 1
fi

# setup Intel MPI environment for Infiniband
source /opt/intel/impi/*/bin64/mpivars.sh
export MPI_ROOT=$I_MPI_ROOT
export I_MPI_STATS=ipm

if [ "$INTERCONNECT" == "ib" ]; then
    export I_MPI_FABRICS=shm:dapl
    export I_MPI_DAPL_PROVIDER=ofa-v2-ib0
    export I_MPI_DYNAMIC_CONNECTION=0
    export I_MPI_FALLBACK_DEVICE=0
else
    export I_MPI_FABRICS=shm:tcp
fi


mpirun -np 2 -ppn 1 -hosts $MPI_HOSTLIST IMB-MPI1 PingPong 
