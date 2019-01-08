#!/bin/bash
set -o errexit
set -o pipefail

# setup Intel MPI environment for Infiniband
source /opt/intel/impi/*/bin64/mpivars.sh
export MPI_ROOT=$I_MPI_ROOT
export I_MPI_STATS=ipm
echo "INTERCONNECT=$INTERCONNECT"

if [ "$INTERCONNECT" == "ib" ]; then
    export I_MPI_FABRICS=shm:dapl
    export I_MPI_DAPL_PROVIDER=ofa-v2-ib0
    export I_MPI_DYNAMIC_CONNECTION=0
    export I_MPI_FALLBACK_DEVICE=0
elif [ "$INTERCONNECT" == "sriov" ]; then
    export I_MPI_FABRICS=shm:ofa
    export I_MPI_FALLBACK_DEVICE=0
else
    export I_MPI_FABRICS=shm:tcp
fi

mpirun -np ${CORES} -ppn ${PPN} -hostfile $MPI_HOSTFILE \
    IMB-MPI1 Allreduce -iter 10000 -npmin ${CORES} -msglog 3:4 -time 1000000 \
    | tee $OUTPUT_DIR/allreduce.log

